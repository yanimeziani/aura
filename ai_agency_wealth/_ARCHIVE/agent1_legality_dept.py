import os
import time
from crewai import Agent, Task, Crew, Process
from crewai.tools import tool
from duckduckgo_search import DDGS
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# --- Custom Search Tool (OSS & Robust) ---
@tool("internet_search")
def internet_search(query: str) -> str:
    """Search the internet for the latest money-making schemes or ruses."""
    with DDGS() as ddgs:
        results = [r for r in ddgs.text(query, max_results=5)]
        return str(results)

# --- Agent 1 ---
legal_analyst = Agent(
    role='Legal Compliance Analyst (Agent 1)',
    goal='Find 3 trending money ruses and assess their legality.',
    backstory='You are Agent 1, a financial investigator. You find arbitrage loops and automated business ruses, then checking if they are legal.',
    verbose=True,
    allow_delegation=False,
    tools=[internet_search],
    llm=os.getenv("OPENAI_MODEL_NAME")
)

# --- Tasks ---
investigation_task = Task(
    description='Search for "trending automated business ruses 2026" and "money-making loopholes". Pick 3 and provide a 1-sentence legal/risk summary for each.',
    expected_output='A report on 3 trending ruses with their legal status.',
    agent=legal_analyst
)

# --- Crew ---
legal_crew = Crew(
    agents=[legal_analyst],
    tasks=[investigation_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("⚖️ BOOTING AGENT 1: MONEY LEGALITY & RUSE DEPT ⚖️")
    try:
        result = legal_crew.kickoff()
        print("📜 AGENT 1 INVESTIGATION REPORT 📜")
        print(result)
        
        # Save output
        log_path = os.path.join(os.path.expanduser("~"), "ai_agency_wealth", "agent1_legality_report.txt")
        with open(log_path, "a") as f:
            f.write(f"\n--- Report Generated at {time.ctime()} ---\n")
            f.write(str(result) + "\n")
            
    except Exception as e:
        print(f"Agent 1 encountered an error: {e}")
