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

def launch_campaign(campaign_name):
    print(f"🚀 Launching Campaign: {campaign_name}")
    
    conn = sqlite3.connect(ROOT_DIR / "vault" / "leads.db")
    cursor = conn.cursor()
    
    # Get leads for this campaign that are "new"
    cursor.execute("""
        SELECT l.id, l.company, l.url, l.pain_point, c.name 
        FROM leads l
        JOIN campaigns c ON l.campaign_id = c.id
        WHERE c.name = ? AND l.status = 'new'
    """, (campaign_name,))
    
    leads = cursor.fetchall()
    
    if not leads:
        print("ℹ️ No new leads to process.")
        return

    print(f"📈 Found {len(leads)} new leads.")
    
    for lead_id, company, url, pain_point, _ in leads:
        print(f"🔍 Processing: {company}")
        
        # In a real scenario, we'd need an email. 
        # Since we don't have them in the CSV, I'll check if we can skip or log.
        # For this execution, I'll log a 'manual_intervention_required' status
        # because we need the actual email address.
        
        # update_lead_status is in lead_manager, but it takes email.
        # I'll update by ID directly here.
        cursor.execute("UPDATE leads SET status = 'pending_research' WHERE id = ?", (lead_id,))
        conn.commit()
        
    conn.close()
    print("✅ Initial processing complete. Leads moved to 'pending_research'.")

if __name__ == "__main__":
    launch_campaign("Quebec SMB Initial Outreach")
