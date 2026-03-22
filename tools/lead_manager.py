#!/usr/bin/env python3
import sqlite3
import os
from pathlib import Path

# Resolve absolute path to vault/leads.db
ROOT_DIR = Path(__file__).resolve().parent.parent
DB_PATH = ROOT_DIR / "vault" / "leads.db"

def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Campaigns table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS campaigns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            status TEXT DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Leads table (email made optional if we have other ID, but keep UNIQUE if present)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS leads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER,
            email TEXT,
            company TEXT,
            url TEXT,
            pain_point TEXT,
            status TEXT DEFAULT 'new',
            last_contacted_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(campaign_id) REFERENCES campaigns(id),
            UNIQUE(campaign_id, email)
        )
    """)
    
    # Interactions table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS interactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lead_id INTEGER,
            direction TEXT, -- inbound, outbound
            channel TEXT DEFAULT 'email',
            content TEXT,
            occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(lead_id) REFERENCES leads(id)
        )
    """)
    conn.commit()
    conn.close()

def add_campaign(name, description=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO campaigns (name, description) VALUES (?, ?)", (name, description))
        conn.commit()
        print(f"📁 Campaign created: {name}")
    except sqlite3.IntegrityError:
        print(f"ℹ️ Campaign already exists: {name}")
    finally:
        conn.close()

def add_lead(campaign_name, email=None, company=None, url=None, pain_point=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get campaign ID
    cursor.execute("SELECT id FROM campaigns WHERE name = ?", (campaign_name,))
    row = cursor.fetchone()
    if not row:
        print(f"❌ Campaign not found: {campaign_name}")
        conn.close()
        return
    campaign_id = row[0]
    
    try:
        cursor.execute("""
            INSERT INTO leads (campaign_id, email, company, url, pain_point) 
            VALUES (?, ?, ?, ?, ?)
        """, (campaign_id, email, company, url, pain_point))
        conn.commit()
        print(f"✅ Lead added to {campaign_name}: {company or email}")
    except sqlite3.IntegrityError:
        print(f"ℹ️ Lead already exists in {campaign_name}: {email or company}")
    finally:
        conn.close()

def update_lead_status(email, status):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("UPDATE leads SET status = ? WHERE email = ?", (status, email))
    conn.commit()
    conn.close()
    print(f"🔒 Lead {email} status updated to: {status}")

if __name__ == "__main__":
    init_db()
