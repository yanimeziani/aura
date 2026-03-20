import base64
import urllib.parse
import sys
from pathlib import Path
import os

# We need a simple Protobuf-less parser for the standard GA migration format
# based on the MigrationPayload specification.
def decode_migration_payload(payload_b64):
    """
    Decodes the raw Base64 migration payload from Google Authenticator.
    Returns a list of dicts: [{'name': ..., 'secret': ...}]
    """
    data = base64.b64decode(urllib.parse.unquote(payload_b64))
    
    # Manual Protobuf field extraction (minimal implementation)
    # Field 1: OTP parameters (repeated)
    # Inside OTP params: Field 1 (Secret), Field 2 (Name), Field 3 (Issuer)
    results = []
    i = 0
    while i < len(data):
        # Read Tag (field number << 3 | wire_type)
        tag = data[i]
        i += 1
        
        if (tag >> 3) == 1: # Field 1: OTP Parameters
            length = data[i]
            i += 1
            otp_data = data[i:i+length]
            i += length
            
            # Parse sub-message (OTP Parameters)
            otp_info = {}
            j = 0
            while j < len(otp_data):
                sub_tag = otp_data[j]
                j += 1
                sub_len = otp_data[j]
                j += 1
                val = otp_data[j:j+sub_len]
                j += sub_len
                
                field_num = sub_tag >> 3
                if field_num == 1: # Secret
                    # Secrets are base32 but Google stores them raw
                    otp_info['secret'] = base32_encode(val)
                elif field_num == 2: # Name
                    otp_info['name'] = val.decode('utf-8', errors='ignore')
                elif field_num == 3: # Issuer
                    otp_info['issuer'] = val.decode('utf-8', errors='ignore')
            
            if 'secret' in otp_info:
                display_name = f"{otp_info.get('issuer', '')}:{otp_info.get('name', 'Unknown')}".strip(':')
                results.append({'name': display_name, 'secret': otp_info['secret']})
        else:
            # Skip unknown fields
            break
            
    return results

def base32_encode(data):
    import base64
    return base64.b32encode(data).decode('utf-8').rstrip('=')

def import_to_aura(uri):
    if not uri.startswith("otpauth-migration://offline?data="):
        print("❌ Invalid URI format. Must start with 'otpauth-migration://offline?data='")
        return

    payload_b64 = uri.split("data=")[1]
    accounts = decode_migration_payload(payload_b64)
    
    if not accounts:
        print("❌ No accounts found in migration data.")
        return

    print(f"📦 Found {len(accounts)} accounts in Google Authenticator export.")
    
    # Use aura_2fa.py to add them
    import subprocess
    for acc in accounts:
        print(f"  - Importing: {acc['name']}")
        subprocess.run([
            "python3", "/home/yani/Aura/vault/aura_2fa.py", 
            "add", acc['name'], acc['secret']
        ], check=False)

    print("\n✅ Full Import Complete.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Google Authenticator to Aura Importer")
        print("-------------------------------------")
        print("1. Open Google Authenticator on your phone.")
        print("2. Go to 'Transfer accounts' -> 'Export accounts'.")
        print("3. Scan the QR code with any QR reader to get the 'otpauth-migration://...' URI.")
        print("4. Run: python3 google_auth_import.py '<YOUR_URI_HERE>'")
    else:
        import_to_aura(sys.argv[1])
