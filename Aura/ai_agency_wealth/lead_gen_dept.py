import os
import json
import time
from sovereign_crew import Agent, Task, Crew, Process
from dotenv import load_dotenv
from json_repair import loads as json_repair_loads

load_dotenv()

from sovereign_crew import web_snippet as _web_search_fn


def _web_snippet(query: str, limit_chars: int = 2000) -> str:
    try:
        s = _web_search_fn(query)
        if isinstance(s, str) and len(s) > limit_chars:
            return s[:limit_chars] + "\n...(truncated)..."
        return s
    except Exception as e:
        return f"(web search failed for {query!r}: {e})"


# --- Agent 1: Lead Hunter (The Snatcher) ---
lead_hunter = Agent(
    role="Lead Identification Specialist",
    goal="Identify high-potential mid-market organizations for autonomous systems deployment.",
    backstory="You hunt for companies (10-100 employees) in logistics, manufacturing, and law that have high manual overhead.",
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}",
)

# --- Agent 2: OSINT Intelligence Officer (The Enricher) ---
enricher = Agent(
    role="OSINT Intelligence Officer",
    goal="Find the specific Decision Maker (CEO, COO, or IT Director) and their contact details for identified companies.",
    backstory="You are a master of finding people. You find LinkedIn profiles, professional emails, and the specific names of leaders within target organizations.",
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}",
)

# --- Tasks ---


def create_tasks(region, industry, count):
    ctx = _web_snippet(f"{industry} mid-sized firms in {region} 10-100 employees")

    hunt_task = Task(
        description=f"""Use the following web research snippets (may be partial / noisy):

{ctx}

Task: Identify {count} mid-sized {industry} firms in {region}. Output a JSON list with: Company Name, Website, Industry, Language (AR/FR/EN), Hook.""",
        expected_output=f"A JSON list of {count} company profiles.",
        agent=lead_hunter,
    )

    enrich_task = Task(
        description="For each company found, identify the CEO, COO, or Head of IT. Find their full name, LinkedIn URL (if possible), and professional email structure. Output: JSON list of leads including Company Name, Contact Person, Title, LinkedIn, and Email.",
        expected_output="An enriched JSON list with specific contact points.",
        agent=enricher,
        context=[hunt_task],
    )
    return hunt_task, enrich_task


mena_hunt, mena_enrich = create_tasks(
    "Algeria/UAE", "logistics or medical distribution", 2
)
eu_hunt, eu_enrich = create_tasks("France/Switzerland", "manufacturing or law", 2)

lead_crew = Crew(
    agents=[lead_hunter, enricher],
    tasks=[mena_hunt, mena_enrich, eu_hunt, eu_enrich],
    process=Process.sequential,
)

if __name__ == "__main__":
    print("🎯 SNATCHING & ENRICHING PROSPECTS (FULL AUTO)...")

    try:
        result = lead_crew.kickoff()
    except Exception as e:
        print(f"Lead Gen encountered an error: {e}")
        raise SystemExit(0)  # graceful exit so orchestrator continues

    # Process the final markdown/string result into leads.json
    # CrewAI kickoff returns a CrewOutput object
    try:
        # CrewOutput.raw is often ONLY the final task. We need all task outputs
        # so we can merge company profiles (hunt) + contacts (enrich).
        if (
            hasattr(result, "tasks_output")
            and isinstance(result.tasks_output, list)
            and result.tasks_output
        ):
            parts = []
            for t in result.tasks_output:
                raw = getattr(t, "raw", None)
                parts.append(raw if isinstance(raw, str) and raw.strip() else str(t))
            res_str = "\n\n".join(parts)
        else:
            res_str = str(result)
        import re

        # Prefer fenced code blocks containing JSON arrays (more reliable than bracket regex).
        arrays = []
        for block in re.findall(
            r"```(?:json)?\s*([\s\S]*?)\s*```", res_str, re.IGNORECASE
        ):
            lines = []
            for line in block.splitlines():
                # CrewAI's TUI output may include a left border like: "│  ..."
                line = re.sub(r"^\s*│\s?", "", line)
                lines.append(line)
            cleaned = "\n".join(lines).strip()

            start = cleaned.find("[")
            end = cleaned.rfind("]")
            if start != -1 and end != -1 and end > start:
                arrays.append(cleaned[start : end + 1])

        # Fallback: best-effort bracket scan.
        if not arrays:
            arrays = re.findall(r"\[[\s\S]*?\]", res_str)
        company_profiles = {}
        contacts = {}

        def _is_company_profile(d: dict) -> bool:
            return any(k in d for k in ("Website", "Industry", "Hook", "Language"))

        def _is_contact_profile(d: dict) -> bool:
            return any(k in d for k in ("Contact Person", "LinkedIn", "Email", "Title"))

        for arr in arrays:
            try:
                try:
                    leads = json.loads(arr)
                except Exception:
                    leads = json_repair_loads(arr)
                if isinstance(leads, list):
                    for item in leads:
                        if not isinstance(item, dict):
                            continue
                        company = item.get("Company Name")
                        if not company or not isinstance(company, str):
                            continue
                        if _is_company_profile(item):
                            company_profiles.setdefault(company, {}).update(item)
                        if _is_contact_profile(item):
                            contacts.setdefault(company, {}).update(item)
            except:
                continue

        all_companies = sorted(set(company_profiles.keys()) | set(contacts.keys()))
        merged = []
        for company in all_companies:
            merged_item = {"Company Name": company}
            merged_item.update(company_profiles.get(company, {}))
            merged_item.update(contacts.get(company, {}))
            merged.append(merged_item)

        if merged:
            with open("leads.json", "w") as f:
                json.dump(merged, f, indent=4)
            print(f"✅ ENRICHED {len(merged)} PROSPECTS. Saved to leads.json")
    except Exception as e:
        print(f"❌ Failed to parse enriched results: {e}")
