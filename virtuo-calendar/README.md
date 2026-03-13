# Virtuo HR Schedule Sync

Fetches your work schedule from the CIUSSS Virtuo HR portal and provides:
- **ICS calendar file** for Google Calendar import
- **MCP server** for AI assistant integration (Claude, Cursor)

## Quick Start

### Generate ICS Calendar
```bash
# Fetch schedule and generate ICS (opens headless browser)
python3 virtuo_sync.py

# Use cached data (no browser needed)
python3 virtuo_sync.py --from-cache

# Fetch 3 months ahead
python3 virtuo_sync.py --months 3
```

Then import `virtuo_schedule.ics` into Google Calendar:
1. Go to calendar.google.com
2. Settings > Import & Export > Import
3. Select the `.ics` file

### MCP Server (for Cursor/Claude)

Add to your Cursor MCP settings (`~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "virtuo-schedule": {
      "command": "python3",
      "args": ["/root/virtuo-calendar/virtuo_mcp_server.py", "--stdio"]
    }
  }
}
```

### Test MCP Tools
```bash
python3 virtuo_mcp_server.py --test
```

## MCP Tools

| Tool | Description |
|------|-------------|
| `get_schedule` | Get all shifts, optionally filtered by date range |
| `get_today_shift` | Get today's shift details |
| `get_week_schedule` | Get shifts for current/any week |
| `get_next_shift` | Get next upcoming shift with countdown |
| `generate_ics` | Generate ICS file from cached data |
| `refresh_schedule` | Re-fetch schedule from Virtuo (browser-based) |

## Dependencies

- Python 3.10+
- Playwright (`pip install playwright`)
- Chromium (`playwright install chromium`)
- Xvfb (`apt install xvfb`)

## API Endpoints Discovered

- Auth: `POST /portals/home/api/auth/token`
- Schedule: `GET /portals/new-employee/api/employee-schedule?startDate=...&endDate=...`
- Settings: `GET /portals/new-employee/api/employee-schedule/settings`
- Filters: `GET /portals/new-employee/api/employee-schedule/filter-values`
- Environment: `GET /portals/home/api/environment/?language=fr-ca`
