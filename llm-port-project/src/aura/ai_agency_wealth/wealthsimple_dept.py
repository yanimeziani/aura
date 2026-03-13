import os
from sovereign_crew import Agent, Task, Crew, Process
from dotenv import load_dotenv

# Load environment variables (API keys, etc.)
load_dotenv()

# We will use DuckDuckGo Search as our free open-source research tool.
# We run it directly and inject results into prompts to avoid LLM tool-calling.
from sovereign_crew import web_snippet as _web_search_fn

def _web_snippet(query: str, limit_chars: int = 2000) -> str:
    try:
        s = _web_search_fn(query)
        if isinstance(s, str) and len(s) > limit_chars:
            return s[:limit_chars] + "\n...(truncated)..."
        return s
    except Exception as e:
        return f"(web search failed for {query!r}: {e})"

# --- 1. Agents ---

wealthsimple_specialist = Agent(
    role='Wealthsimple Portfolio Manager (Finance Dept)',
    goal='Manage and track USD funds in Wealthsimple (WS) to maximize long-term growth and yield.',
    backstory='You are an expert in the Canadian financial ecosystem, specifically Wealthsimple. You know how to navigate WS Cash, Trade, and Crypto. You understand the limitations of unofficial APIs and focus on low-maintenance, high-yield strategies.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

tax_accountant = Agent(
    role='Cross-Border Tax & Compliance Officer (Accounting Dept)',
    goal='Track USD/CAD movements and ensure all Wealthsimple and Coinbase activities are tax-optimized for the user.',
    backstory='You are a specialist in tax reporting for Canadian-based users with USD/CAD cross-border accounts. You ensure that transfers between Coinbase and Wealthsimple are documented and optimized for tax efficiency.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Tasks ---

_ws_context = "\n\n".join(
    [
        _web_snippet("Wealthsimple Cash USD interest rate 2026"),
        _web_snippet("CASH.TO yield 2026 ETF"),
        _web_snippet("HISU.U yield 2026"),
    ]
)

ws_portfolio_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_ws_context}

Task: Analyze the current USD yield options in Wealthsimple (Cash vs. Stocks/ETFs like CASH.TO or HISU.U). Recommend a strategy to maximize the USD in the user's Wealthsimple account while keeping risk low.""",
    expected_output='A USD growth strategy for Wealthsimple, including specific ticker symbols or account types.',
    agent=wealthsimple_specialist
)

compliance_task = Task(
    description='Outline the reporting requirements for moving funds between a crypto exchange (Coinbase) and a traditional brokerage (Wealthsimple) in Canada. Focus on tracking ACB (Adjusted Cost Base) for USD and USDC.',
    expected_output='A compliance checklist for tracking cross-platform wealth transfers.',
    agent=tax_accountant
)

# --- 3. Crew ---

wealthsimple_dept_crew = Crew(
    agents=[wealthsimple_specialist, tax_accountant],
    tasks=[ws_portfolio_task, compliance_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("💰 BOOTING WEALTHSIMPLE USD DEPT 💰")
    print("================================================")
    
    try:
        result = wealthsimple_dept_crew.kickoff()
        print("\n================================================")
        print("📈 WEALTHSIMPLE GROWTH STRATEGY 📈")
        print("================================================")
        print(result)
    except Exception as e:
        print(f"Agency encountered an error: {e}")
