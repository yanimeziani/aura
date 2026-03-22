#!/usr/bin/env python3
import sqlite3
import sys
import os
import time
from pathlib import Path

# Add tools directory to path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(ROOT_DIR / "tools"))
import lead_manager
import resend_outreach

def run_mass_mailer(campaign_name):
    print(f"🚀 Starting Mass Cold Mailer for: {campaign_name}")
    print(f"🛡️  Enforcing Nexa Mental Biological Safety Constraints (Batch Pacing & Funnel Targeting)")
    
    conn = sqlite3.connect(ROOT_DIR / "vault" / "leads.db")
    cursor = conn.cursor()
    
    # We target leads that have an email and are either 'new' or 'pending_research'
    cursor.execute("""
        SELECT l.id, l.email, l.company, l.url, l.pain_point
        FROM leads l
        JOIN campaigns c ON l.campaign_id = c.id
        WHERE c.name = ? AND (l.status = 'new' OR l.status = 'pending_research') AND l.email IS NOT NULL
    """, (campaign_name,))
    
    leads = cursor.fetchall()
    
    if not leads:
        print("ℹ️ No leads with valid emails found ready for outreach in this campaign.")
        conn.close()
        return

    print(f"📧 Found {len(leads)} leads ready for safe outreach.")
    
    for lead_id, email, company, url, pain_point in leads:
        print(f"\n---")
        print(f"🎯 Processing: {company} ({email})")
        
        # Crafting the safe, high-signal value-add email
        subject = f"Digital Sovereign Infrastructure for {company}"
        
        html_template = f"""
        <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee;">
            <h2 style="color: #333;">Meziani AI Digital Studio</h2>
            <p>Hello team at <strong>{company}</strong>,</p>
            <p>I am reaching out regarding your digital infrastructure and data sovereignty.</p>
            <p>We noticed that organizations like yours often face challenges with: <em>{pain_point}</em></p>
            <p>Our studio specializes in sovereign AI deployments and automated revenue recovery workflows that respect strict privacy standards (like Law 25), entirely powered by the Aura Mesh Protocol.</p>
            <p>If exploring a zero-trust, automated architecture aligns with your current priorities, let's schedule a brief 15-minute sync.</p>
            <br/>
            <p>Best regards,</p>
            <p><strong>Yani Meziani</strong><br/>
            Founder, Meziani AI Digital Studio<br/>
            <a href="https://meziani.ai">meziani.ai</a></p>
            <br/>
            <p style="font-size: 10px; color: #999;">If you prefer not to receive these communications, please reply with 'unsubscribe' to be immediately removed.</p>
        </div>
        """
        
        # Send via Resend Outreach tool
        api_key = os.environ.get("RESEND_API_KEY")
        if not api_key:
            print("❌ RESEND_API_KEY not set. Halting mass mailer.")
            break
            
        from_email = "Yani Meziani <yani@meziani.ai>"
        
        print(f"📤 Sending to {email}...")
        res = resend_outreach.send_email(api_key, from_email, email, subject, html_template)
        
        if res:
            # Update status to contacted
            cursor.execute("UPDATE leads SET status = 'contacted', last_contacted_at = CURRENT_TIMESTAMP WHERE id = ?", (lead_id,))
            conn.commit()
            print(f"✅ Successfully contacted {company}.")
            
            # Log interaction
            cursor.execute("""
                INSERT INTO interactions (lead_id, direction, channel, content)
                VALUES (?, 'outbound', 'email', ?)
            """, (lead_id, subject))
            conn.commit()
        
        # Mental Safety Pacing: Avoid overwhelming the network and API limits
        print("⏳ Pacing... waiting 2 seconds before next send to respect mesh safety limits.")
        time.sleep(2)
        
    conn.close()
    print("\n🏁 Mass Cold Mailer sequence completed.")

if __name__ == "__main__":
    run_mass_mailer("Quebec SMB Initial Outreach")
