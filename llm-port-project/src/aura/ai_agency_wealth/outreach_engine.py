import os
import json
import resend
import sqlite3
import time
from datetime import datetime
from dotenv import load_dotenv
from litellm import completion

load_dotenv()

resend.api_key = os.getenv("RESEND_API_KEY")
DB_PATH = "agency.db"

def _clean_model(v):
    if v is None:
        return None
    if not isinstance(v, str):
        return None
    s = v.strip()
    if not s:
        return None
    if s.lower() in {"none", "null", "undefined"}:
        return None
    return s


def generate_personalized_email(lead):
    """Uses Groq (fast) with Ollama (sovereign) fallback."""
    company_name = lead.get("Company Name") or lead.get("company_name")
    if not company_name:
        print("⚠️  Skipping lead with missing Company Name.")
        return None

    print(
        f"✍️  Crafting {lead.get('Language', 'EN')} systems proposal for {company_name}..."
    )

    lang_map = {
        "AR": "Arabic",
        "FR": "French",
        "EN": "English",
        "QC": "Quebecois French",
    }
    language = lang_map.get(lead.get("Language"), "English")
    industry = lead.get("Industry") or lead.get("industry") or "your industry"

    prompt = f"""
    You are a Systems Integration Specialist at AI Agency Systems, based in Canada.
    TARGET: {company_name} in the {industry} industry.
    CONTACT PERSON: {lead.get("Contact Person", "Decision Maker")} ({lead.get("Title", "Leader")}).
    LANGUAGE: Write the entire email in {language}.
    CULTURAL HOOK: {lead.get("Hook", "Automation")}.
    
    TASK: Write a professional technical outreach email addressed to {lead.get("Contact Person", "the leadership team")}.
    GOAL: Offer a "Phase 1: Infrastructure Assessment" to evaluate autonomous systems opportunities for their Canadian operations.
    
    TONE: Professional, Technical, Canadian/Quebecois (use 'vous' for French, maintain technical precision).
    SIGN-OFF: Systems Integration Team | AI Agency Systems
    
    GUIDELINES:
    - Use Canadian English spelling (e.g., digitalisation, optimisation, programme).
    - Ensure the message is compliant with CASL (Canada's Anti-Spam Legislation) by being direct and professional.
    - Mention "Canadian Data Sovereignty" as a key benefit.
    
    Include this link for infrastructure assessment: https://meziani.org/
    """

    # 1. Try Groq First
    try:
        model = _clean_model(os.getenv("OPENAI_MODEL_NAME")) or "llama-3.3-70b-versatile"
        api_base = os.getenv("OPENAI_API_BASE") or "https://api.groq.com/openai/v1"
        api_key = os.getenv("GROQ_API_KEY") or os.getenv("OPENAI_API_KEY")
        response = completion(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            api_base=api_base,
            api_key=api_key,
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"⚠️ Groq failed/limited: {e}. Falling back to Local Ollama...")
        # Fallback to local Qwen 3 via Ollama
        try:
            response = completion(
                model="ollama/qwen3:8b", messages=[{"role": "user", "content": prompt}]
            )
            return response.choices[0].message.content
        except Exception as e2:
            print(f"❌ Local Fallback Error: {e2}")
            return None


from link_validator import validate_links_in_text


def send_outreach():
    if not os.path.exists("leads.json"):
        print("🛑 No leads found. Run lead_gen_dept.py first.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    with open("leads.json", "r") as f:
        leads = json.load(f)

    # SELECTIVITY: Sort by Conversion_Score (highest first)
    leads = sorted(leads, key=lambda x: x.get("Conversion_Score", 0), reverse=True)

    live_mode = os.getenv("OUTREACH_LIVE", "0").strip() == "1"
    test_to = _clean_model(os.getenv("OUTREACH_TEST_TO"))

    for lead in leads:
        company_name = lead.get("Company Name")
        if not company_name:
            print("⚠️  Skipping lead with missing Company Name.")
            continue

        # Check CRM status
        cursor.execute(
            "SELECT status FROM funnel WHERE company_name = ?", (company_name,)
        )
        row = cursor.fetchone()
        if row and row[0] != "PROSPECT":
            print(f"⏭️  Already processing {company_name}. Skipping.")
            continue

        email_body = generate_personalized_email(lead)
        if not email_body:
            continue

        # 🛡️ MANDATORY PRE-FLIGHT CHECKS
        is_links_ok, failing_urls = validate_links_in_text(email_body)
        if not is_links_ok:
            print(
                f"🛑 CRITICAL: Dead links detected for {company_name}: {failing_urls}. BLOCKING OUTREACH."
            )
            continue

        # MULTI-LINGUAL SAFETY FILTER
        # Checks for 'AI Agency Systems' in English/Arabic and our core domain
        has_name = any(name in email_body for name in ["AI Agency Systems"])
        has_link = "meziani.org" in email_body

        if not has_name or not has_link:
            print(
                f"⚠️  Safety Filter triggered for {company_name}. Missing name ({has_name}) or link ({has_link}). Skipping."
            )
            continue

        lead_email = lead.get("Email") or lead.get("email")
        if test_to:
            to_list = [test_to]
        elif live_mode and lead_email:
            to_list = [lead_email]
        else:
            to_list = None

        try:
            if not resend.api_key:
                raise RuntimeError("RESEND_API_KEY is missing.")

            params = {
                "from": "AI Agency Systems <onboarding@meziani.ai>",
                "to": to_list or [],
                "subject": f"Infrastructure Assessment for {company_name} — AI Agency Systems",
                "text": email_body,
            }
            if not to_list:
                print(
                    f"📝 DRY RUN for {company_name}: set OUTREACH_LIVE=1 (and ensure lead Email exists) or OUTREACH_TEST_TO to send."
                )
            else:
                print(f"🚀 SENDING to {company_name} -> {to_list[0]} (Score: {lead.get('Conversion_Score')})...")
                resend.Emails.send(params)
                print(f"✅ OUTREACH SUCCESSFUL for {company_name}")

            # Record in CRM
            cursor.execute(
                """
                INSERT INTO funnel (company_name, email, status, last_contacted)
                VALUES (?, ?, 'CONTACTED', ?)
                ON CONFLICT(company_name) DO UPDATE SET
                    email=excluded.email,
                    status='CONTACTED',
                    last_contacted=excluded.last_contacted
            """,
                (
                    company_name,
                    lead_email,
                    datetime.now().isoformat(),
                ),
            )
            conn.commit()

            print("⏳ Anti-spam delay (5s)...")
            time.sleep(5)
        except Exception as e:
            print(f"❌ Error: {e}")

    conn.close()


if __name__ == "__main__":
    send_outreach()
