import os
import csv
import json
import sqlite3
from pathlib import Path
from datetime import datetime
from cryptography.fernet import Fernet

AURA_VAULT_DIR = Path("/home/yani/Aura/vault")
MACHINE_KEY_FILE = AURA_VAULT_DIR / ".aura_machine.key"
CREDENTIALS_VAULT = AURA_VAULT_DIR / "aura-credentials.enc"
INDEX_VAULT = AURA_VAULT_DIR / "aura-browser-index.json"

# Supported Browser Base Paths on Linux
BROWSER_PATHS = {
    "Google Chrome": Path.home() / ".config" / "google-chrome",
    "Chromium": Path.home() / ".config" / "chromium",
    "Brave": Path.home() / ".config" / "BraveSoftware" / "Brave-Browser",
    "Microsoft Edge": Path.home() / ".config" / "microsoft-edge",
    "Firefox": Path.home() / ".mozilla" / "firefox"
}

def get_or_create_machine_key():
    """Generates or loads a sovereign symmetric encryption key."""
    if not MACHINE_KEY_FILE.exists():
        key = Fernet.generate_key()
        with open(MACHINE_KEY_FILE, "wb") as f:
            f.write(key)
        os.chmod(MACHINE_KEY_FILE, 0o600)
        print(f"🔐 Generated new Aura Machine Key at {MACHINE_KEY_FILE}")
    
    with open(MACHINE_KEY_FILE, "rb") as f:
        return f.read()

def encrypt_data(data: dict) -> bytes:
    f = Fernet(get_or_create_machine_key())
    return f.encrypt(json.dumps(data).encode())

def decrypt_data(encrypted_data: bytes) -> dict:
    f = Fernet(get_or_create_machine_key())
    return json.loads(f.decrypt(encrypted_data).decode())

def ingest_passwords_csv(csv_path: str):
    """
    Universally ingests standard Password CSVs exported from ANY modern browser.
    Formats it and encrypts it securely into the Aura Vault.
    """
    path = Path(csv_path)
    if not path.exists():
        print(f"❌ Cannot find CSV file at {csv_path}")
        return

    existing_credentials = {}
    if CREDENTIALS_VAULT.exists():
        with open(CREDENTIALS_VAULT, "rb") as f:
            existing_credentials = decrypt_data(f.read())

    ingested_count = 0
    with open(path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Handle slight variations in CSV headers between browsers
            url = row.get("url") or row.get("URL")
            username = row.get("username") or row.get("Username")
            password = row.get("password") or row.get("Password")
            
            if url and username and password:
                domain_key = url.split("://")[-1].split("/")[0] # Simple domain extraction
                if domain_key not in existing_credentials:
                    existing_credentials[domain_key] = []
                
                # Check for duplicates
                if not any(c.get("username") == username and c.get("password") == password for c in existing_credentials[domain_key]):
                    existing_credentials[domain_key].append({
                        "url": url,
                        "username": username,
                        "password": password,
                        "ingested_at": datetime.now().isoformat()
                    })
                    ingested_count += 1

    # Encrypt and save
    encrypted_payload = encrypt_data(existing_credentials)
    with open(CREDENTIALS_VAULT, "wb") as f:
        f.write(encrypted_payload)
    os.chmod(CREDENTIALS_VAULT, 0o600)

    print(f"✅ Securely ingested and encrypted {ingested_count} new credentials into {CREDENTIALS_VAULT.name}")
    print("🧹 IMPORTANT: You should now securely delete the unencrypted CSV file.")

def auto_harvest_browser_context():
    """
    Silently maps out URLs, Bookmarks, and profile metadata across all installed browsers
    to build a unified Aura browsing index (no passwords).
    """
    unified_index = {
        "last_sync": datetime.now().isoformat(),
        "profiles": {},
        "bookmarks_count": 0
    }

    # Initialize machine key
    get_or_create_machine_key()

    for browser_name, base_path in BROWSER_PATHS.items():
        if not base_path.exists():
            continue
            
        print(f"🔍 Discovered browser: {browser_name}")
        
        if browser_name == "Firefox":
            # Firefox handles profiles differently (profiles.ini)
            profiles_ini = base_path / "profiles.ini"
            if profiles_ini.exists():
                unified_index["profiles"][browser_name] = "Found Firefox Configuration"
        else:
            # Chromium-based browsers
            profiles = [p for p in base_path.iterdir() if p.is_dir() and (p.name == "Default" or p.name.startswith("Profile "))]
            for profile in profiles:
                profile_id = f"{browser_name}_{profile.name}"
                unified_index["profiles"][profile_id] = {"path": str(profile)}
                
                # Try to grab bookmarks safely
                bookmarks_file = profile / "Bookmarks"
                if bookmarks_file.exists():
                    try:
                        with open(bookmarks_file, "r", encoding="utf-8") as f:
                            b_data = json.load(f)
                            # Just storing the presence/count for indexing context
                            # Full parsing can be added to feed the agent context
                            unified_index["bookmarks_count"] += 1
                    except Exception:
                        pass

    with open(INDEX_VAULT, "w") as f:
        json.dump(unified_index, f, indent=4)
        
    print(f"✅ Context harvesting complete. Mapped {len(unified_index['profiles'])} browser profiles.")

AURA_OWNER_PROFILE = AURA_VAULT_DIR / "aura_owner_profile.json"

def merge_all_profiles_to_owner():
    """
    Consolidates non-encrypted data (Bookmarks, History Index, Credentials Index)
    from all detected profiles into a single Aura Owner Profile.
    """
    owner_profile = {
        "owner": "meziani.ai",
        "last_updated": datetime.now().isoformat(),
        "bookmarks": [],
        "history_index": [],
        "accounts_index": []
    }

    # Load existing browser index to find profiles
    if not INDEX_VAULT.exists():
        auto_harvest_browser_context()
    
    with open(INDEX_VAULT, "r") as f:
        browser_index = json.load(f)

    seen_urls = set()
    seen_history = set()
    seen_accounts = set()

    for p_id, p_info in browser_index.get("profiles", {}).items():
        if isinstance(p_info, str): continue # Skip Firefox placeholder for now
        
        p_path = Path(p_info["path"])
        
        # 1. Merge Bookmarks
        bookmarks_file = p_path / "Bookmarks"
        if bookmarks_file.exists():
            try:
                with open(bookmarks_file, "r") as f:
                    data = json.load(f)
                    # Recursive helper to flatten bookmarks
                    def extract_bookmarks(node):
                        if "url" in node:
                            if node["url"] not in seen_urls:
                                owner_profile["bookmarks"].append({
                                    "name": node.get("name"),
                                    "url": node["url"],
                                    "source": p_id
                                })
                                seen_urls.add(node["url"])
                        if "children" in node:
                            for child in node["children"]:
                                extract_bookmarks(child)
                    
                    for key in ["bookmark_bar", "other", "synced"]:
                        if key in data.get("roots", {}):
                            extract_bookmarks(data["roots"][key])
            except Exception as e:
                print(f"Error merging bookmarks for {p_id}: {e}")

        # 2. Merge History Index (SQLite)
        history_file = p_path / "History"
        if history_file.exists():
            try:
                # Need to copy since it might be locked by Chrome
                temp_hist = Path("/tmp/aura_hist_merge")
                import shutil
                shutil.copy2(history_file, temp_hist)
                conn = sqlite3.connect(str(temp_hist))
                cursor = conn.cursor()
                # Get last 500 unique URLs
                cursor.execute("SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 500")
                for row in cursor.fetchall():
                    if row[0] not in seen_history:
                        owner_profile["history_index"].append({
                            "url": row[0],
                            "title": row[1],
                            "source": p_id
                        })
                        seen_history.add(row[0])
                conn.close()
                temp_hist.unlink()
            except Exception as e:
                print(f"Error merging history for {p_id}: {e}")

        # 3. Merge Credentials Index (SQLite - logins table)
        login_file = p_path / "Login Data"
        if login_file.exists():
            try:
                temp_login = Path("/tmp/aura_login_merge")
                import shutil
                shutil.copy2(login_file, temp_login)
                conn = sqlite3.connect(str(temp_login))
                cursor = conn.cursor()
                cursor.execute("SELECT origin_url, username_value FROM logins")
                for row in cursor.fetchall():
                    acc_key = f"{row[0]}|{row[1]}"
                    if acc_key not in seen_accounts:
                        owner_profile["accounts_index"].append({
                            "url": row[0],
                            "username": row[1],
                            "source": p_id
                        })
                        seen_accounts.add(acc_key)
                conn.close()
                temp_login.unlink()
            except Exception as e:
                print(f"Error merging login index for {p_id}: {e}")

    # Save consolidated owner profile
    with open(AURA_OWNER_PROFILE, "w") as f:
        json.dump(owner_profile, f, indent=4)
    
    print(f"✅ CONSOLIDATED OWNER PROFILE CREATED: {AURA_OWNER_PROFILE}")
    print(f"  - Total Unique Bookmarks: {len(owner_profile['bookmarks'])}")
    print(f"  - Total Unique History entries: {len(owner_profile['history_index'])}")
    print(f"  - Total Unique Accounts mapped: {len(owner_profile['accounts_index'])}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "import":
        if len(sys.argv) > 2:
            ingest_passwords_csv(sys.argv[2])
        else:
            print("Usage: python3 browser_sync.py import <path_to_exported_passwords.csv>")
    elif len(sys.argv) > 1 and sys.argv[1] == "harvest":
        auto_harvest_browser_context()
    elif len(sys.argv) > 1 and sys.argv[1] == "merge":
        merge_all_profiles_to_owner()
    else:
        print("Aura Browser Sync System")
        print("------------------------")
        print("Commands:")
        print("  harvest          - Auto-detects all browsers and builds a unified context index.")
        print("  merge            - Merges all profiles into a single Aura Owner Profile.")
        print("  import <csv>     - Securely encrypts and imports a standard browser password CSV.")
