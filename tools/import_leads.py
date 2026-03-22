#!/usr/bin/env python3
import csv
import sys
from pathlib import Path

# Add tools directory to path
sys.path.append(str(Path(__file__).resolve().parent))
import lead_manager

def import_leads_from_csv(csv_path, campaign_name):
    lead_manager.add_campaign(campaign_name, "Imported from " + str(csv_path))
    
    with open(csv_path, mode='r', encoding='utf-8') as f:
        for line in f:
            line = line.strip().strip('"')
            if not line:
                continue
            
            parts = line.split(", ", 2)
            if len(parts) < 2:
                continue
                
            company = parts[0]
            url = parts[1]
            pain_point = parts[2] if len(parts) > 2 else ""
            
            lead_manager.add_lead(
                campaign_name=campaign_name,
                company=company,
                url=url,
                pain_point=pain_point
            )

if __name__ == "__main__":
    csv_file = Path("apps/research/quebec_smb_leads.csv")
    if csv_file.exists():
        import_leads_from_csv(csv_file, "Quebec SMB Initial Outreach")
    else:
        print(f"❌ CSV file not found: {csv_file}")
