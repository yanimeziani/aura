import os
from crewai import Agent, Task, Crew, Process
from crewai.tools import tool
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

# Load environment variables (API keys, etc.)
load_dotenv()

# We will use DuckDuckGo Search as our free open-source research tool
_search_tool = DuckDuckGoSearchRun()

@tool("DuckDuckGo Search")
def search_tool(query: str) -> str:
    """Search the web for current information."""
    return _search_tool.run(query)

# --- 1. Agents ---

market_analyst = Agent(
    role='Algerian SMB Specialist (Research Dept)',
    goal='Identify specific digitalization gaps and automation needs for Small and Medium Businesses (SMBs) in Algeria.',
    backstory='You are an expert in the Algerian market, from Algiers to Oran. You understand the unique challenges of local commerce, import/export, and the growing tech scene. You identify where open-source automation (n8n, CRM, ERP) can save them time and money.',
    verbose=True,
    allow_delegation=False,
    tools=[search_tool],
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

sales_strategist = Agent(
    role='Business Development Manager (Sales Dept)',
    goal='Create a high-impact outreach plan and service offering for Algerian SMBs (e.g., Automated Invoicing, Inventory Management, Social Media CRM).',
    backstory='You are a master of B2B sales in the MENA region. You know how to pitch value-driven automation services that speak to the bottom line of local business owners.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Tasks ---

research_task = Task(
    description='Search for the most common manual processes and "pain points" for Algerian SMBs in sectors like retail, logistics, and professional services. Identify which open-source tools (e.g., Odoo, n8n, Dolibarr) solve these best.',
    expected_output='A strategic report on the top 3 automation opportunities for SMBs in Algeria.',
    agent=market_analyst
)

sales_task = Task(
    description='Develop a "Service Package" (e.g., "The Algiers Automation Bundle") including pricing (in DZD/USD) and an outreach script in both French and Arabic (Dardja/Modern Standard) to target these SMBs.',
    expected_output='A complete sales proposal and multilingual outreach strategy.',
    agent=sales_strategist
)

# --- 3. Crew ---

algeria_smb_crew = Crew(
    agents=[market_analyst, sales_strategist],
    tasks=[research_task, sales_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("🇩🇿 BOOTING ALGERIA SMB AUTOMATION DEPT 🇩🇿")
    print("================================================")
    
    try:
        result = algeria_smb_crew.kickoff()
        print("\n================================================")
        print("📈 ALGERIA MARKET ENTRY STRATEGY 📈")
        print("================================================")
        print(result)
    except Exception as e:
        print(f"Agency encountered an error: {e}")