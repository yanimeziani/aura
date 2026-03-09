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


def generate_personalized_email(lead):
    """Uses Groq (fast) with Ollama (sovereign) fallback."""
    print(
        f"✍️  Crafting {lead.get('Language', 'EN')} systems proposal for {lead['Company Name']}..."
    )

    lang_map = {
        "AR": "Arabic",
        "FR": "French",
        "EN": "English",
        "QC": "Quebecois French",
    }
    language = lang_map.get(lead.get("Language"), "English")

    prompt = f"""
    You are a Systems Integration Specialist at AI Agency Systems, based in Quebec.
    TARGET: {lead["Company Name"]} in the {lead["Industry"]} industry.
    LANGUAGE: Write the entire email in {language}.
    CULTURAL HOOK: {lead.get("Hook", "Automation")}.
    
    TASK: Write a professional technical outreach email.
    GOAL: Offer a "Phase 1: Infrastructure Assessment" to evaluate autonomous systems opportunities.
    
    TONE: Professional, Technical, Quebecois (use 'vous', maintain technical precision).
    SIGN-OFF: Systems Integration Team | AI Agency Systems
    
    Include this link for infrastructure assessment: https://meziani.org/
    """

    # 1. Try Groq First
    try:
        response = completion(
            model=os.getenv("OPENAI_MODEL_NAME"),
            messages=[{"role": "user", "content": prompt}],
            api_base=os.getenv("OPENAI_API_BASE"),
            api_key=os.getenv("OPENAI_API_KEY"),
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

    for lead in leads:
        # Check CRM status
        cursor.execute(
            "SELECT status FROM funnel WHERE company_name = ?", (lead["Company Name"],)
        )
        row = cursor.fetchone()
        if row and row[0] != "PROSPECT":
            print(f"⏭️  Already processing {lead['Company Name']}. Skipping.")
            continue

        email_body = generate_personalized_email(lead)
        if not email_body:
            continue

        # 🛡️ MANDATORY PRE-FLIGHT CHECKS
        is_links_ok, failing_urls = validate_links_in_text(email_body)
        if not is_links_ok:
            print(
                f"🛑 CRITICAL: Dead links detected for {lead['Company Name']}: {failing_urls}. BLOCKING OUTREACH."
            )
            continue

        # MULTI-LINGUAL SAFETY FILTER
        # Checks for 'AI Agency Systems' in English/Arabic and our core domain
        has_name = any(name in email_body for name in ["AI Agency Systems"])
        has_link = "meziani.org" in email_body

        if not has_name or not has_link:
            print(
                f"⚠️  Safety Filter triggered for {lead['Company Name']}. Missing name ({has_name}) or link ({has_link}). Skipping."
            )
            continue

        print(
            f"🚀 SENDING to {lead['Company Name']} (Score: {lead.get('Conversion_Score')})..."
        )

        try:
            params = {
                "from": "AI Agency Systems <onboarding@meziani.ai>",
                "to": ["mezianiyani0@gmail.com"],
                "subject": f"Infrastructure Assessment for {lead['Company Name']} — AI Agency Systems",
                "text": email_body,
            }
            resend.Emails.send(params)
            print(f"✅ OUTREACH SUCCESSFUL for {lead['Company Name']}")

            # Record in CRM
            cursor.execute(
                """
                INSERT INTO funnel (company_name, status, last_contacted)
                VALUES (?, 'CONTACTED', ?)
                ON CONFLICT(email) DO UPDATE SET status='CONTACTED', last_contacted=?
            """,
                (
                    lead["Company Name"],
                    datetime.now().isoformat(),
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
