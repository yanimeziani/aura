#!/usr/bin/env python3
import os
import sys
import argparse
import json
import requests

def send_email(api_key, from_email, to_email, subject, html_content):
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "from": from_email,
        "to": [to_email],
        "subject": subject,
        "html": html_content
    }
    
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 200 or response.status_code == 201:
        print(f"✅ Email sent successfully to {to_email}")
        return response.json()
    else:
        print(f"❌ Failed to send email: {response.status_code} - {response.text}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Resend Outreach Tool for Meziani AI Digital Studio")
    parser.add_argument("--to", required=True, help="Recipient email address")
    parser.add_argument("--subject", default="Meziani AI Digital Studio - Digital Real Estate Inquiry", help="Email subject")
    parser.add_argument("--name", default="Prospect", help="Recipient name")
    
    args = parser.parse_args()
    
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key:
        print("❌ Error: RESEND_API_KEY environment variable not set.")
        sys.exit(1)
        
    from_email = "Yani Meziani <yani@meziani.ai>"
    
    html_template = f"""
    <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee;">
        <h2 style="color: #333;">Meziani AI Digital Studio</h2>
        <p>Hello {args.name},</p>
        <p>I am reaching out from <strong>Meziani AI Digital Studio</strong> regarding digital real estate opportunities.</p>
        <p>Our studio specializes in sovereign AI infrastructure and high-performance digital assets.</p>
        <p>We ensure that our clients have full control and ownership over their digital presence, powered by the Aura Mesh Protocol.</p>
        <br/>
        <p>Best regards,</p>
        <p><strong>Yani Meziani</strong><br/>
        Founder, Meziani AI Digital Studio<br/>
        <a href="https://meziani.ai">meziani.ai</a></p>
    </div>
    """
    
    send_email(api_key, from_email, args.to, args.subject, html_template)

if __name__ == "__main__":
    main()
