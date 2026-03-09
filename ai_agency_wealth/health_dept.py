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

# --- 1. Agent: Health Strategy & Benefits Manager ---

health_manager = Agent(
    role='Private Health Strategy Manager (Benefits Dept)',
    goal='Optimize private health spending and access for the business owner using tax-efficient structures like HSAs.',
    backstory='You are a specialist in Canadian private healthcare and corporate benefits. You know how to bypass public wait times by leveraging private clinics and Health Spending Accounts (HSAs). You ensure every dollar spent on health is tax-deductible for the corporation.',
    verbose=True,
    allow_delegation=False,
    tools=[search_tool],
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Tasks ---

hsa_setup_task = Task(
    description='Research the top 3 HSA providers in Canada (e.g., Olympia Benefits, myHSA, Kibono) for a "class of one" incorporated business. Compare their setup fees, admin fees, and ease of use for private clinic reimbursements.',
    expected_output='A comparative report on HSA providers with a recommendation for the fastest setup.',
    agent=health_manager
)

private_clinic_mapping_task = Task(
    description='Identify the leading private medical clinic networks in Canada (e.g., RocklandMD, ExcelleMD, Telus Health Care Centres). List their core services (e.g., executive physicals, rapid diagnostics) and how they integrate with HSA payments.',
    expected_output='A directory of private medical resources and a protocol for "private-first" healthcare access.',
    agent=health_manager
)

# --- 3. Crew ---

health_dept_crew = Crew(
    agents=[health_manager],
    tasks=[hsa_setup_task, private_clinic_mapping_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("🏥 BOOTING PRIVATE HEALTH DEPT 🏥")
    print("================================================")
    
    try:
        result = health_dept_crew.kickoff()
        print("\n================================================")
        print("📈 PRIVATE HEALTH STRATEGY 📈")
        print("================================================")
        print(result)
    except Exception as e:
        print(f"Health Dept encountered an error: {e}")
