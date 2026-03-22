# Linking Digital Metaverse Identity (Google Workspace MCP)

This setup allows Nexa to act as an entry point to your digital identity via Google Workspace (Gmail, Calendar, Drive, etc.).

## Accounts
- yani@meziani.ai
- mezianiyani0@gmail.com

## Prerequisites

1. **Google Cloud Project**: Create a project at [Google Cloud Console](https://console.cloud.google.com/).
2. **Enable APIs**: Enable Gmail API, Google Calendar API, Google Drive API, etc.
3. **OAuth Credentials**:
   - Go to **APIs & Services > Credentials**.
   - Create **OAuth client ID**.
   - Choose **Application type: Desktop App**.
   - Note your `Client ID` and `Client Secret`.

## Setup

Set the following environment variables (e.g., in your `.env` file or export them):

```bash
export GOOGLE_OAUTH_CLIENT_ID="your-client-id"
export GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
```

## Running

Run the following command to start the MCP server:

```bash
python nexa.py identity
```

The first time you run a tool through this MCP server, it will provide an authorization URL. Open it in your browser and authorize the accounts.

## Multiple Accounts (OAuth 2.1)

This server uses OAuth 2.1 which supports multi-account management. You can authorize both `yani@meziani.ai` and `mezianiyani0@gmail.com` when prompted.
