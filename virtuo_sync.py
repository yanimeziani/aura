#!/usr/bin/env python3
"""
Virtuo HR Schedule Sync - Fetches schedule from CIUSSS Virtuo portal and generates ICS calendar.

Usage:
    python virtuo_sync.py                    # Fetch schedule and generate ICS
    python virtuo_sync.py --months 3         # Fetch 3 months of schedule
    python virtuo_sync.py --output cal.ics   # Custom output path
"""

import asyncio
import json
import os
import subprocess
import sys
import time
import random
import hashlib
from datetime import datetime, timedelta
from pathlib import Path

os.environ["PLAYWRIGHT_BROWSERS_PATH"] = "/tmp/pw-browsers"

BASE_URL = "https://virtuo.ciussscn.rtss.qc.ca"
USERNAME = "517910"
PASSWORD = "tvt-B6!4$nekGGX"
TIMEZONE = "America/Toronto"
CALENDAR_NAME = "Virtuo - Horaire de travail"

CAPTURED = {}


def generate_ics(schedule_entries, output_path="virtuo_schedule.ics"):
    """Generate RFC 5545 compliant ICS file from schedule entries."""
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Virtuo Schedule Sync//EN",
        f"X-WR-CALNAME:{CALENDAR_NAME}",
        f"X-WR-TIMEZONE:{TIMEZONE}",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "",
        "BEGIN:VTIMEZONE",
        f"TZID:{TIMEZONE}",
        "BEGIN:DAYLIGHT",
        "TZOFFSETFROM:-0500",
        "TZOFFSETTO:-0400",
        "TZNAME:EDT",
        "DTSTART:19700308T020000",
        "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU",
        "END:DAYLIGHT",
        "BEGIN:STANDARD",
        "TZOFFSETFROM:-0400",
        "TZOFFSETTO:-0500",
        "TZNAME:EST",
        "DTSTART:19701101T020000",
        "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU",
        "END:STANDARD",
        "END:VTIMEZONE",
    ]

    for entry in schedule_entries:
        if entry.get("allDay"):
            continue

        start = entry.get("startDate", "")
        end = entry.get("endDate", "")
        if not start or not end:
            continue

        start_dt = datetime.fromisoformat(start)
        end_dt = datetime.fromisoformat(end)

        uid_seed = f"{entry['id']}-{start}"
        uid = hashlib.md5(uid_seed.encode()).hexdigest()

        summary = entry.get("title", "Shift")
        dept = entry.get("departmentDisplay", "")
        job = entry.get("jobTitleDescription", "")
        location_parts = []
        if entry.get("establishmentDisplay"):
            location_parts.append(entry["establishmentDisplay"])
        if entry.get("establishmentAbbreviation"):
            location_parts.append(f"Site {entry['establishmentAbbreviation']}")
        location = " - ".join(location_parts) if location_parts else ""

        desc_parts = []
        if dept:
            desc_parts.append(f"Dept: {dept}")
        if job:
            desc_parts.append(f"Poste: {job}")
        if entry.get("jobTitleNo"):
            desc_parts.append(f"Code: {entry['jobTitleNo']}")
        if entry.get("shiftDescription"):
            desc_parts.append(f"Quart: {entry['shiftDescription']}")
        if entry.get("totalHoursDisplay"):
            desc_parts.append(f"Heures: {entry['totalHoursDisplay']}")
        if entry.get("position"):
            desc_parts.append(f"Position: {entry['position']}")
        if entry.get("annotation"):
            desc_parts.append(f"Note: {entry['annotation']}")
        if entry.get("special"):
            desc_parts.append(f"Special: {entry['special']}")
        description = "\\n".join(desc_parts)

        dtstart = start_dt.strftime("%Y%m%dT%H%M%S")
        dtend = end_dt.strftime("%Y%m%dT%H%M%S")
        dtstamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

        lines.extend([
            "",
            "BEGIN:VEVENT",
            f"UID:{uid}@virtuo-sync",
            f"DTSTAMP:{dtstamp}",
            f"DTSTART;TZID={TIMEZONE}:{dtstart}",
            f"DTEND;TZID={TIMEZONE}:{dtend}",
            f"SUMMARY:{summary}",
        ])
        if location:
            lines.append(f"LOCATION:{location}")
        if description:
            lines.append(f"DESCRIPTION:{description}")
        if entry.get("scheduleCodeDescription"):
            lines.append(f"CATEGORIES:{entry['scheduleCodeDescription']}")

        lines.append("STATUS:CONFIRMED")
        lines.append("TRANSP:OPAQUE")
        lines.append("END:VEVENT")

    lines.append("")
    lines.append("END:VCALENDAR")
    lines.append("")

    ics_content = "\r\n".join(lines)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(ics_content)

    return output_path


async def human_type(page, selector, text):
    await page.click(selector)
    await page.wait_for_timeout(random.randint(200, 500))
    for char in text:
        await page.keyboard.type(char, delay=random.randint(40, 120))
    await page.wait_for_timeout(random.randint(200, 400))


async def fetch_schedule(months_ahead=2):
    """Login to Virtuo and fetch employee schedule data."""
    from playwright.async_api import async_playwright

    captured = {}

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=["--no-sandbox", "--disable-blink-features=AutomationControlled"]
        )
        context = await browser.new_context(
            ignore_https_errors=True,
            viewport={"width": 1920, "height": 1080},
            locale="fr-CA",
            timezone_id=TIMEZONE,
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        )
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
            window.chrome = { runtime: {}, loadTimes: () => ({}), csi: () => ({}) };
            Object.defineProperty(navigator, 'languages', { get: () => ['fr-CA', 'fr', 'en-US', 'en'] });
        """)
        page = await context.new_page()

        async def handle_response(response):
            url = response.url
            if "/api/" in url:
                try:
                    ct = response.headers.get("content-type", "")
                    if "json" in ct:
                        body = await response.text()
                        short = url.replace(BASE_URL, "")
                        captured[short] = {"status": response.status, "body": body}
                except:
                    pass

        page.on("response", handle_response)

        # Login with retries
        auth_ok = False
        for attempt in range(5):
            captured.clear()
            print(f"  Login attempt {attempt + 1}/5...")
            await page.goto(f"{BASE_URL}/portals/home/app/login", wait_until="networkidle", timeout=60000)
            await page.wait_for_timeout(3000 + random.randint(500, 2000))

            for _ in range(3):
                await page.mouse.move(random.randint(100, 800), random.randint(100, 600))
                await page.wait_for_timeout(random.randint(200, 500))

            await human_type(page, '#username-txt', USERNAME)
            await page.keyboard.press('Tab')
            await page.wait_for_timeout(random.randint(300, 600))
            await human_type(page, '#password-txt', PASSWORD)
            await page.wait_for_timeout(random.randint(1000, 2000))
            await page.click('button:has-text("Connexion")')
            await page.wait_for_timeout(15000)

            for short, data in captured.items():
                if "auth/token" in short and data["status"] == 200:
                    parsed = json.loads(data["body"])
                    if parsed.get("result", {}).get("access_token"):
                        auth_ok = True
                        auth_data = parsed["result"]
                        print(f"  Logged in as {auth_data['user']['firstName']} {auth_data['user']['lastName']}")
                        break
            if auth_ok:
                break
            await page.wait_for_timeout(random.randint(3000, 5000))

        if not auth_ok:
            print("ERROR: Failed to log in after 5 attempts")
            await browser.close()
            return None

        # Fetch schedule
        captured.clear()
        now = datetime.now()
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=30 * months_ahead + 15)

        schedule_url = (
            f"{BASE_URL}/portals/new-employee/app/employee-schedule"
        )
        print(f"  Navigating to schedule page...")
        await page.goto(schedule_url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(10000)

        # Collect schedule entries
        schedule_entries = []
        for short, data in captured.items():
            if "employee-schedule" in short and "?" in short and data["status"] == 200:
                try:
                    parsed = json.loads(data["body"])
                    if isinstance(parsed.get("result"), list):
                        schedule_entries.extend(parsed["result"])
                except:
                    pass

        print(f"  Found {len(schedule_entries)} schedule entries")

        # If we need more months, navigate forward
        if months_ahead > 1:
            for m in range(months_ahead - 1):
                captured.clear()
                print(f"  Loading next month ({m + 2}/{months_ahead})...")
                try:
                    next_btn = page.locator('[title*="Suivant"], [aria-label*="next"], .dx-scheduler-navigator-next, button:has-text("›")').first
                    await next_btn.click(timeout=5000)
                    await page.wait_for_timeout(8000)

                    for short, data in captured.items():
                        if "employee-schedule" in short and "?" in short and data["status"] == 200:
                            try:
                                parsed = json.loads(data["body"])
                                if isinstance(parsed.get("result"), list):
                                    existing_ids = {e["id"] for e in schedule_entries}
                                    new_entries = [e for e in parsed["result"] if e["id"] not in existing_ids]
                                    schedule_entries.extend(new_entries)
                                    print(f"    Added {len(new_entries)} new entries")
                            except:
                                pass
                except Exception as e:
                    print(f"    Could not navigate forward: {e}")

        print(f"  Total schedule entries: {len(schedule_entries)}")

        # Save raw data
        with open("/tmp/virtuo_schedule_entries.json", "w") as f:
            json.dump(schedule_entries, f, indent=2, ensure_ascii=False)

        await browser.close()
        return schedule_entries


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Virtuo Schedule Sync")
    parser.add_argument("--months", type=int, default=2, help="Months ahead to fetch")
    parser.add_argument("--output", type=str, default="virtuo_schedule.ics", help="Output ICS file path")
    parser.add_argument("--from-cache", action="store_true", help="Use cached schedule data")
    args = parser.parse_args()

    if args.from_cache and os.path.exists("/tmp/virtuo_schedule_entries.json"):
        print("Using cached schedule data...")
        with open("/tmp/virtuo_schedule_entries.json") as f:
            entries = json.load(f)
    else:
        xvfb = subprocess.Popen(
            ["Xvfb", ":99", "-screen", "0", "1920x1080x24"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        time.sleep(1)
        os.environ["DISPLAY"] = ":99"

        try:
            print("Fetching schedule from Virtuo...")
            entries = asyncio.run(fetch_schedule(months_ahead=args.months))
        finally:
            xvfb.terminate()

        if not entries:
            print("Failed to fetch schedule data")
            sys.exit(1)

    output_path = generate_ics(entries, args.output)
    print(f"\nGenerated ICS calendar: {output_path}")
    print(f"  {len(entries)} events")

    if entries:
        dates = sorted(set(e["date"][:10] for e in entries if e.get("date")))
        print(f"  Date range: {dates[0]} to {dates[-1]}")

    print(f"\nTo import into Google Calendar:")
    print(f"  1. Go to calendar.google.com")
    print(f"  2. Settings > Import & Export > Import")
    print(f"  3. Select {output_path}")

    return entries


if __name__ == "__main__":
    main()
