#!/usr/bin/env python3
import os
import requests
import json
from pathlib import Path
import sys

# Import lead manager from tools
sys.path.append(str(Path(__file__).resolve().parent.parent.parent / "tools"))
import lead_manager

RESEND_API_KEY = os.environ.get("RESEND_API_KEY")
FROM_EMAIL = "Yani Meziani <yani@meziani.ai>"

def send_outbound(to_email, subject, html_content, company=None):
    if not RESEND_API_KEY:
        print("❌ RESEND_API_KEY not set")
        return False

    # Ensure lead is in DB
    lead_manager.init_db()
    lead_manager.add_lead(to_email, company)
    
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "from": FROM_EMAIL,
        "to": [to_email],
        "subject": subject,
        "html": html_content
    }
    
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code in [200, 201]:
        print(f"📧 Outbound sent to {to_email}")
        # Log interaction (simplified)
        return True
    else:
        print(f"❌ Failed to send outbound: {response.text}")
        return False

def check_mental_biological_safety(text):
    """
    Nexa Level 0 Invariant: Mental Biological Safety Filter.
    Ensures 0% cognitive casualty probability. If the prospect shows signs of
    stress, anger, annoyance, or cognitive overload, we immediately isolate (close)
    the lead to preserve their equanimous state.
    """
    text_lower = text.lower()
    
    # High-stress / negative signals (Biological Safety Violations)
    stress_signals = [
        "unsubscribe", "stop", "remove me", "not interested", "no thanks",
        "don't email", "spam", "annoyed", "bothering", "frustrated", "angry",
        "never contact", "take me off", "hate", "waste of time"
    ]
    
    # Positive / equanimous signals
    positive_signals = [
        "interested", "tell me more", "schedule", "call", "meeting", "yes",
        "how does this work", "pricing", "demo", "sounds good"
    ]
    
    safety_violation = any(signal in text_lower for signal in stress_signals)
    positive_intent = any(signal in text_lower for signal in positive_signals)
    
    if safety_violation:
        return "VIOLATION" # Auto-close immediately
    elif positive_intent:
        return "EQUANIMOUS" # Safe to proceed down funnel
    else:
        return "NEUTRAL" # Monitor, do not escalate

def handle_inbound(payload):
    """
    Processes inbound Resend webhook payload.
    Implements 'Auto Close' logic based on Nexa Mental Biological Safety.
    """
    from_email = payload.get("from")
    content = payload.get("text", "").lower()
    
    print(f"📩 Processing inbound from {from_email}")
    
    # Nexa Filter applied
    safety_status = check_mental_biological_safety(content)
    
    if safety_status == "VIOLATION":
        print(f"🛑 [NEXA SAFETY] Mental Biological Safety Violation detected.")
        print(f"🔒 Auto-closing lead {from_email} to preserve recipient equanimity.")
        lead_manager.update_lead_status(from_email, "closed_opt_out")
        return True
    elif safety_status == "EQUANIMOUS":
        print(f"✅ [NEXA SAFETY] Positive intent detected. Routing {from_email} to sales queue.")
        lead_manager.update_lead_status(from_email, "engaged")
        return False
    else:
        print(f"⚖️ [NEXA SAFETY] Neutral response from {from_email}. Maintaining active status.")
        return False

if __name__ == "__main__":
    # Test
    if len(sys.argv) > 1 and sys.argv[1] == "test_inbound":
        test_payload = {
            "from": "test@example.com",
            "text": "Please remove me from your list"
        }
        handle_inbound(test_payload)
