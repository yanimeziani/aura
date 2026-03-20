import os
import shutil
import json
from pathlib import Path
from datetime import datetime

def backup_chrome_profiles():
    chrome_base = Path.home() / ".config" / "google-chrome"
    backup_root = Path("/home/yani/Aura/vault/chrome_backup")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = backup_root / f"backup_{timestamp}"
    
    if not chrome_base.exists():
        print(f"Chrome directory not found at {chrome_base}")
        return

    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # Files to collect from each profile
    target_files = [
        "Login Data",
        "Web Data",
        "Bookmarks",
        "History",
        "Cookies",
        "Preferences",
        "Network/Cookies"
    ]

    # Global files
    global_files = ["Local State"]
    for gf in global_files:
        src = chrome_base / gf
        if src.exists():
            shutil.copy2(src, backup_dir / gf)

    # Find profiles
    profiles = [p for p in chrome_base.iterdir() if p.is_dir() and (p.name == "Default" or p.name.startswith("Profile "))]
    
    for profile in profiles:
        print(f"Processing profile: {profile.name}")
        profile_backup = backup_dir / profile.name
        profile_backup.mkdir(parents=True, exist_ok=True)
        
        # Try to get profile name from Preferences
        pref_path = profile / "Preferences"
        profile_display_name = profile.name
        if pref_path.exists():
            try:
                with open(pref_path, "r") as f:
                    prefs = json.load(f)
                    profile_display_name = prefs.get("profile", {}).get("name", profile.name)
            except:
                pass
        
        print(f"  Display name: {profile_display_name}")
        
        for tf in target_files:
            src = profile / tf
            dest = profile_backup / tf
            if src.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dest)
            elif (profile / "Network" / "Cookies").exists() and tf == "Network/Cookies":
                # Handle newer Chrome cookie location
                src = profile / "Network" / "Cookies"
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dest)

    # Create a summary index (usernames and URLs only)
    credentials_index = []
    login_db = backup_dir / "Profile 1" / "Login Data"
    if login_db.exists():
        try:
            import sqlite3
            conn = sqlite3.connect(str(login_db))
            cursor = conn.cursor()
            cursor.execute("SELECT origin_url, username_value FROM logins")
            for row in cursor.fetchall():
                credentials_index.append({
                    "url": row[0],
                    "username": row[1]
                })
            conn.close()
        except Exception as e:
            print(f"Error indexing Login Data: {e}")

    with open(backup_dir / "credentials_index.json", "w") as f:
        json.dump(credentials_index, f, indent=4)

    # Recovery Plan
    recovery_plan = f"""# AURA CHROME RECOVERY PLAN
Timestamp: {timestamp}
Profile Name: meziani.ai

## Contents
- Full profiles backed up (Login Data, Cookies, Bookmarks, History).
- Global Chrome configuration (Local State).
- Credentials Index: A searchable list of accounts (usernames/URLs).

## How to Restore
1. Install Google Chrome on the new system.
2. Stop all Chrome processes.
3. Replace the `~/.config/google-chrome/` directory with the contents of this backup.
4. IMPORTANT: Passwords and cookies are encrypted using the OS Keyring. You must have the original system's keyring login to decrypt them.

## Forget-Safe Strategy
- Encrypt this folder using: `gpg -c -o {backup_dir}.tar.gz.gpg {backup_dir}`
- Store the GPG passphrase in your physical/offline vault.
- Keep one copy of the encrypted file on your local machine and one on a redundant physical drive.
"""
    with open(backup_dir / "RECOVERY_PLAN.md", "w") as f:
        f.write(recovery_plan)

    print(f"\n✅ Backup and indexing completed to: {backup_dir}")
    print("\nNext steps to make it 'forget safe':")
    print(f"1. Encrypt the backup: gpg -c -o {backup_dir}.tar.gz.gpg {backup_dir}")
    print("2. Store the passphrase in your physical vault or a secure secondary system.")

if __name__ == "__main__":
    backup_chrome_profiles()
