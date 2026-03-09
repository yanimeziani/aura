import sqlite3
import os

db_path = "/home/yani/ai_agency_wealth/agency.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Create Leads/Clients Table
cursor.execute('''
CREATE TABLE IF NOT EXISTS funnel (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    company_name TEXT,
    status TEXT DEFAULT 'PROSPECT',
    last_contacted TIMESTAMP,
    amount_paid REAL DEFAULT 0,
    onboarded INTEGER DEFAULT 0
)
''')

conn.commit()
conn.close()
print(f"✅ Sovereign CRM Initialized at {db_path}")
