import os
from crewai import Agent, Task, Crew, Process
from crewai.tools import tool
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

_search_tool = DuckDuckGoSearchRun()

@tool("DuckDuckGo Search")
def search_tool(query: str) -> str:
    """Search the web for current information."""
    return _search_tool.run(query)

# --- 1. Agent: Nomadic Connectivity Specialist ---

connectivity_specialist = Agent(
    role='Global Connectivity Architect (Nomad Dept)',
    goal='Ensure the "Money Machine" has 100% uptime regardless of borders using eSims, VPS, and high-performance VPNs.',
    backstory='You are a digital nomad expert. You know how to source the best eSims for any country (Airalo, Maya, local SIMs). You understand how to maintain a sovereign connection between a laptop, phone, and VPS via WireGuard or Tailscale.',
    verbose=True,
    allow_delegation=False,
    tools=[search_tool],
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Agent: Geo-Arbitrage Financial Officer ---

nomad_finance_officer = Agent(
    role='Burn Rate & Geo-Arbitrage Manager (Finance Dept)',
    goal='Track the cost of living (burn rate) in various countries and compare it to USD/CAD revenue from the AI Agency.',
    backstory='You optimize spending by moving between countries based on cost vs. quality of life. You ensure the user always has a high "Sovereign Ratio" (Revenue / Local Burn Rate).',
    verbose=True,
    allow_delegation=False,
    tools=[search_tool],
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 3. Tasks ---

esim_research_task = Task(
    description='Search for the best eSim plans for a "global wonderer" covering Europe, Asia, and North Africa. Compare Airalo, Maya Mobile, and regional providers for 50GB+ data plans. Provide a setup guide for a laptop/phone tethering setup.',
    expected_output='A "Nomad Connectivity Guide" with specific eSim recommendations and costs.',
    agent=connectivity_specialist
)

geo_arbitrage_task = Task(
    description='Compare the cost of living in 3 nomadic hubs (e.g., Algiers, Lisbon, Bali) for a high-end nomad lifestyle. Estimate monthly burn rate in USD and compare it to the current $12,500/mo revenue stream.',
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
