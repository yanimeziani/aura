# AURA CHROME RECOVERY PLAN
Timestamp: 20260308_231421
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
- Encrypt this folder using: `gpg -c -o /home/yani/Aura/vault/chrome_backup/backup_20260308_231421.tar.gz.gpg /home/yani/Aura/vault/chrome_backup/backup_20260308_231421`
- Store the GPG passphrase in your physical/offline vault.
- Keep one copy of the encrypted file on your local machine and one on a redundant physical drive.
