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

llm_architect = Agent(
    role='Lead LLM Solutions Architect (R&D Dept)',
    goal='Identify the best open-source LLMs and fine-tuning techniques for specific business needs (like Algerian SMBs or Wealth Management).',
    backstory='You are an expert in the LLM landscape. You track Ollama, Groq, Llama, Qwen, and DeepSeek. You know which model (8b, 70b, VL) is best for cost-efficiency and performance.',
    verbose=True,
    allow_delegation=False,
    tools=[search_tool],
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

deployment_engineer = Agent(
    role='Local AI Deployment Specialist (Ops Dept)',
    goal='Create a step-by-step technical guide to deploy these models locally using Ollama, Docker, or vLLM to ensure 100% data privacy.',
    backstory='You are a master of local AI infrastructure. You optimize quantization (GGUF, EXL2) and ensure low latency for automated business workflows.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- 2. Tasks ---

research_task = Task(
    description='Search for the latest open-source LLM benchmarks and find the top 3 models for: 1. Reasoning/Logic, 2. Fast Chat/Outreach, 3. Multilingual (French/Arabic) performance.',
    expected_output='A strategic report on the best open-source models available today for the agency.',
    agent=llm_architect
)

deployment_task = Task(
    description='Write a technical deployment guide for the recommended models using Ollama and n8n. Include specific commands to pull and run them on a local Linux server.',
    expected_output='A technical implementation guide for the Agency Infrastructure.',
    agent=deployment_engineer
)

# --- 3. Crew ---

llm_dept_crew = Crew(
    agents=[llm_architect, deployment_engineer],
    tasks=[research_task, deployment_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("================================================")
    print("🧠 BOOTING LLM ENGINEERING & R&D DEPT 🧠")
    print("================================================")
    
    try:
        result = llm_dept_crew.kickoff()
        print("\n================================================")
        print("📈 LLM DEPLOYMENT STRATEGY 📈")
        print("================================================")
        print(result)
    except Exception as e:
        print(f"Agency encountered an error: {e}")
