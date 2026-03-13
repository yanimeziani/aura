import os
from sovereign_crew import Agent, Task, Crew, Process
from dotenv import load_dotenv

# Load environment variables
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

# --- 1. Agent: Health Strategy & Benefits Manager ---

health_manager = Agent(
    role='Private Health Strategy Manager (Benefits Dept)',
    goal='Optimize private health spending and access for the business owner using tax-efficient structures like HSAs.',
    backstory='You are a specialist in Canadian private healthcare and corporate benefits. You know how to bypass public wait times by leveraging private clinics and Health Spending Accounts (HSAs). You ensure every dollar spent on health is tax-deductible for the corporation.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Tasks ---

_hsa_context = "\n\n".join(
    [
        _web_snippet("Olympia Benefits Health Spending Account fees setup time Canada"),
        _web_snippet("myHSA Canada HSA fees setup"),
        _web_snippet("Kibono HSA Canada fees setup"),
    ]
)
_clinic_context = "\n\n".join(
    [
        _web_snippet("RocklandMD executive health services pricing Canada"),
        _web_snippet("ExcelleMD services executive physicals Canada"),
        _web_snippet("TELUS Health Care Centres executive health services Canada"),
    ]
)

hsa_setup_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_hsa_context}

Task: Compare the top 3 HSA providers in Canada (e.g., Olympia Benefits, myHSA, Kibono) for a "class of one" incorporated business. Compare setup fees, admin fees, and ease of use for private clinic reimbursements.""",
    expected_output='A comparative report on HSA providers with a recommendation for the fastest setup.',
    agent=health_manager
)

private_clinic_mapping_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_clinic_context}

Task: Identify the leading private medical clinic networks in Canada (e.g., RocklandMD, ExcelleMD, Telus Health Care Centres). List their core services (e.g., executive physicals, rapid diagnostics) and how they integrate with HSA payments.""",
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
