import os
import sqlite3
import resend
from datetime import datetime
from dotenv import load_dotenv
from litellm import completion
from link_validator import validate_links_in_text

load_dotenv()
resend.api_key = os.getenv("RESEND_API_KEY")
DB_PATH = "agency.db"

def repair_dead_link_outreach():
    print("🛠️  STARTING ENGAGEMENT REPAIR CYCLE...")
    
    # 1. Verify our core IP is UP before starting
    is_ok, _ = validate_links_in_text("https://meziani.org")
    if not is_ok:
        print("🛑 ABORT: VPS IP is still down. Cannot send repair emails.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 2. Find all companies in 'CONTACTED' status
    cursor.execute("SELECT company_name, email FROM funnel WHERE status = 'CONTACTED'")
    leads = cursor.fetchall()

    if not leads:
        print("✅ No previous outreach found to repair.")
        return

    for company_name, email in leads:
        print(f"🔄 Crafting repair follow-up for {company_name}...")
        
        prompt = f"""
        You are Yani Meziani, Lead Architect at Meziani AI Labs.
        You previously sent an outreach email to {company_name}, but our server migration was still in progress.
        
        TASK: Write a short, professional follow-up email.
        MESSAGE: "Apologies, we were in the middle of a massive infrastructure upgrade when I last reached out. Our Sovereign Dashboard is now fully live and optimized at https://meziani.org. I've cleared a slot for your 48-hour automation audit."
        
        TONE: Elite, Technical, Direct.
        SIGN-OFF: Yani Meziani | Meziani AI Labs
        """
        
        try:
            response = completion(
                model=os.getenv("OPENAI_MODEL_NAME"),
                messages=[{"role": "user", "content": prompt}],
                api_base=os.getenv("OPENAI_API_BASE"),
                api_key=os.getenv("OPENAI_API_KEY")
            )
            email_body = response.choices[0].message.content

            # Safety check on the repair email
            is_ok, _ = validate_links_in_text(email_body)
            if not is_ok:
                continue

            print(f"🚀 SENDING REPAIR to {company_name}...")
            resend.Emails.send({
                "from": "Meziani AI Labs <onboarding@meziani.ai>",
                "to": ["mezianiyani0@gmail.com"], # Redirect to you for approval
                "subject": f"Update: Infrastructure Optimized for {company_name} — Meziani AI Labs",
                "text": email_body,
            })
            
            # Update CRM status to 'REPAIRED'
            cursor.execute("UPDATE funnel SET status = 'REPAIRED' WHERE company_name = ?", (company_name,))
            conn.commit()
            print(f"✅ {company_name} marked as REPAIRED.")
            
        except Exception as e:
            print(f"❌ Error during repair for {company_name}: {e}")

    conn.close()

if __name__ == "__main__":
    repair_dead_link_outreach()
