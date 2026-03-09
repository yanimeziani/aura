import os
from crewai import Agent, Task, Crew, Process
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

_search_tool = DuckDuckGoSearchRun()

def _web_snippet(query: str, limit_chars: int = 2000) -> str:
    try:
        s = _search_tool.run(query)
        if isinstance(s, str) and len(s) > limit_chars:
            return s[:limit_chars] + "\n...(truncated)..."
        return s
    except Exception as e:
        return f"(web search failed for {query!r}: {e})"

# --- 1. Agent: Nomadic Connectivity Specialist ---

connectivity_specialist = Agent(
    role='Global Connectivity Architect (Nomad Dept)',
    goal='Ensure the "Money Machine" has 100% uptime regardless of borders using eSims, VPS, and high-performance VPNs.',
    backstory='You are a digital nomad expert. You know how to source the best eSims for any country (Airalo, Maya, local SIMs). You understand how to maintain a sovereign connection between a laptop, phone, and VPS via WireGuard or Tailscale.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Agent: Geo-Arbitrage Financial Officer ---

nomad_finance_officer = Agent(
    role='Burn Rate & Geo-Arbitrage Manager (Finance Dept)',
    goal='Track the cost of living (burn rate) in various countries and compare it to USD/CAD revenue from the AI Agency.',
    backstory='You optimize spending by moving between countries based on cost vs. quality of life. You ensure the user always has a high "Sovereign Ratio" (Revenue / Local Burn Rate).',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 3. Tasks ---

_esim_context = "\n\n".join(
    [
        _web_snippet("Airalo 50GB eSIM global plan Europe Asia North Africa price"),
        _web_snippet("Maya Mobile 50GB eSIM global plan price"),
        _web_snippet("regional eSIM providers Europe Asia North Africa 50GB plan"),
    ]
)
_burn_context = "\n\n".join(
    [
        _web_snippet("cost of living Algiers monthly budget 2026"),
        _web_snippet("cost of living Lisbon high-end nomad monthly 2026"),
        _web_snippet("cost of living Bali high-end nomad monthly 2026"),
    ]
)

esim_research_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_esim_context}

Task: Recommend the best eSim plans for a "global wanderer" covering Europe, Asia, and North Africa. Compare Airalo, Maya Mobile, and regional providers for 50GB+ data plans. Provide a setup guide for a laptop/phone tethering setup.""",
    expected_output='A "Nomad Connectivity Guide" with specific eSim recommendations and costs.',
    agent=connectivity_specialist
)

geo_arbitrage_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_burn_context}

Task: Compare the cost of living in 3 nomadic hubs (e.g., Algiers, Lisbon, Bali) for a high-end nomad lifestyle. Estimate monthly burn rate in USD and compare it to the current $12,500/mo revenue stream.""",
    expected_output='A geo-arbitrage report showing the "Sovereign Ratio" for each location.',
    agent=nomad_finance_officer
)

# --- 4. Crew ---

nomad_ops_crew = Crew(
    agents=[connectivity_specialist, nomad_finance_officer],
    tasks=[esim_research_task, geo_arbitrage_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("🌍 BOOTING NOMADIC OPERATIONS DEPT 🌍")
    print("================================================")
    
    try:
        result = nomad_ops_crew.kickoff()
        print("\n================================================")
        print("📈 NOMADIC SOVEREIGNTY STRATEGY 📈")
        print("================================================")
        print(result)
    except Exception as e:
        print(f"Nomad Ops encountered an error: {e}")
