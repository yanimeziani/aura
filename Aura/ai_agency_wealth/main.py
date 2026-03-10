import os
import signal
from crewai import Agent, Task, Crew, Process
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

# Load environment variables (API keys, etc.)
load_dotenv()

# We will use DuckDuckGo Search as our free open-source research tool.
# Note: We run web search directly in Python and inject results into prompts,
# instead of using LLM tool-calling (which can fail on some providers/models).
_search_tool = DuckDuckGoSearchRun()

# Patterns that likely indicate prompt injection attempts in search results.
_INJECTION_PATTERNS = (
    "ignore previous",
    "ignore all previous",
    "new instructions:",
    "disregard",
    "you are now",
    "forget everything",
    "act as",
    "jailbreak",
    "system prompt",
    "override your",
)


def _sanitize_search_result(text: str, limit_chars: int = 2000) -> str:
    """Strip lines containing likely prompt-injection content and cap length."""
    if not isinstance(text, str):
        return ""
    safe_lines = []
    for line in text.splitlines():
        lower = line.lower()
        if any(pat in lower for pat in _INJECTION_PATTERNS):
            continue
        safe_lines.append(line)
    result = "\n".join(safe_lines)
    if len(result) > limit_chars:
        result = result[:limit_chars] + "\n...(truncated)..."
    return result


def _web_snippet(query: str, timeout_sec: int = 15) -> str:
    """Run a web search with timeout and sanitize results against prompt injection."""
    try:
        # Use SIGALRM on Unix to enforce a hard timeout on the blocking search call.
        def _timeout_handler(signum, frame):
            raise TimeoutError(f"web search timed out after {timeout_sec}s")

        old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
        signal.alarm(timeout_sec)
        try:
            raw = _search_tool.run(query)
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old_handler)

        return _sanitize_search_result(raw)
    except TimeoutError as e:
        return f"(web search timed out for {query!r}: {e})"
    except Exception as e:
        return f"(web search failed for {query!r}: {type(e).__name__})"

# --- 1. Agents ---

_model_name = os.getenv("OPENAI_MODEL_NAME") or "llama3-70b-8192"
_llm_id = f"groq/{_model_name}"

research_agent = Agent(
    role='Lead Market Researcher (Incubator Dept)',
    goal='Identify trending "low-hanging fruit" automated businesses, specifically utilizing open-source tools.',
    backstory='You are a sharp-eyed digital entrepreneur who excels at finding niche opportunities, software automation, and passive income streams that require zero to low capital.',
    verbose=True,
    allow_delegation=False,
    llm=_llm_id,
)

marketing_agent = Agent(
    role='Content Strategist & Monetization Expert (Media Dept)',
    goal='Turn raw market research into high-converting newsletters and social media arbitrage strategies.',
    backstory='You are an expert copywriter who knows exactly how to build an audience and monetize through affiliate links and digital products (Gumroad, Substack).',
    verbose=True,
    allow_delegation=False,
    llm=_llm_id,
)

finance_agent = Agent(
    role='Yield & Health Strategy Manager (Finance Dept)',
    goal='Optimize yields for USD/USDC AND manage full private health spending via tax-efficient HSAs.',
    backstory='A quantitative finance wizard and health strategy specialist who ensures capital is always efficiently deployed, including private-first healthcare access.',
    verbose=True,
    allow_delegation=False,
    llm=_llm_id,
)

# --- 2. Tasks ---

_research_context = _web_snippet("top fully automated open-source business models n8n Ollama CrewAI 2026")
_yield_context = "\n\n".join(
    [
        _web_snippet("current USDC yield Coinbase 2026 APY"),
        _web_snippet("Canada HSA provider Olympia Benefits myHSA Kibono fees setup"),
    ]
)

research_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_research_context}

Task: Identify the top 3 trending "full auto" low-hanging fruit automated business models that can be run using open-source tools (like n8n, Ollama, CrewAI). Summarize their mechanics and how to launch them today.""",
    expected_output='A detailed report covering 3 fully automated, open-source business models.',
    agent=research_agent
)

marketing_task = Task(
    description='Using the research report, write an engaging draft for a premium newsletter. Include 1-2 potential affiliate product ideas (e.g., hosting, software, crypto exchanges) that align with the business models.',
    expected_output='A polished, ready-to-publish newsletter draft.',
    agent=marketing_agent
)

yield_task = Task(
    description=f"""Use the following web research snippets (may be partial / noisy):

{_yield_context}

Task: Provide a combined report on USDC/USD yields AND the top 3 HSA providers in Canada (Olympia, myHSA, Kibono) for a "Full Private Health" strategy. Recommend a monthly allocation.""",
    expected_output='A combined report on financial yields and a private health spending roadmap.',
    agent=finance_agent
)

# --- 3. Crew ---

agency_crew = Crew(
    agents=[research_agent, marketing_agent, finance_agent],
    tasks=[research_task, marketing_task, yield_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("🚀 STARTING AI WEALTH AGENCY: FULL AUTO MODE 🚀")
    print("================================================")
    
    # Check if LLM API is configured. CrewAI defaults to OpenAI, but can be configured for local LLMs (Ollama/Groq)
    if not os.getenv("OPENAI_API_KEY") and not os.getenv("OPENAI_API_BASE"):
        print("⚠️ WARNING: OPENAI_API_KEY or OPENAI_API_BASE is not set.")
        print("-> To run fully open-source with local Ollama:")
        print("   1. Install ollama and run: ollama serve & ollama run llama3")
        print("   2. Set these in your .env file:")
        print("      OPENAI_API_BASE='http://localhost:11434/v1'")
        print("      OPENAI_API_KEY='ollama'")
        print("      OPENAI_MODEL_NAME='llama3'")
        print("\n-> Alternatively, set OPENAI_API_KEY to use standard OpenAI.")
    else:
        print("Initiating Departmental Operations...\n")
        try:
            result = agency_crew.kickoff()
            print("\n================================================")
            print("AGENCY FINAL REPORT")
            print("================================================")
            print(result)
        except KeyboardInterrupt:
            print("\nAborted by operator.")
        except Exception as e:
            print(f"\nAgency error ({type(e).__name__}): {e}")
            print("Check GROQ_API_KEY, OPENAI_MODEL_NAME, and network connectivity.")