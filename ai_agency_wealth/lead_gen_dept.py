import os
import json
from crewai import Agent, Task, Crew, Process
from crewai.tools import tool
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

load_dotenv()

_search_tool = DuckDuckGoSearchRun()

@tool("DuckDuckGo Search")
def search_tool(query: str) -> str:
    """Search the web for current information."""
    return _search_tool.run(query)

# --- Agent: Systems Integration Specialist ---
 lead_hunter = Agent(
     role='Systems Integration Specialist',
     goal='Identify mid-market organizations (10-100 employees) with operational inefficiencies suitable for autonomous systems deployment. Focus on companies with complex manual processes that would benefit from systematic automation.',
     backstory='You specialize in finding organizations ready for infrastructure modernization. You target companies large enough to require systematic solutions but agile enough to implement new technologies. You assess operational maturity and assign readiness scores based on infrastructure needs.',
     verbose=True,
     allow_delegation=False,
     tools=[search_tool],
     llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
 )

# --- Tasks ---
hunt_mena = Task(
    description='Search for 10 mid-sized logistics or medical distribution firms in Algeria/UAE. Output: JSON list with Company Name, Website, Industry, Language: "AR", Hook: "Sovereignty", Conversion_Score: (integer 1-100).',
    expected_output='A JSON list of 10 high-conversion MENA prospects.',
    agent=lead_hunter
)

hunt_eu = Task(
    description='Search for 10 mid-sized manufacturing or law firms in France/Switzerland. Output: JSON list with Company Name, Website, Industry, Language: "FR", Hook: "Labor Cost Reduction", Conversion_Score: (integer 1-100).',
    expected_output='A JSON list of 10 high-conversion EU prospects.',
    agent=lead_hunter
)

hunt_global = Task(
    description='Search for 10 high-growth e-commerce or SaaS startups (US/Asia) with 20-50 employees. Output: JSON list with Company Name, Website, Industry, Language: "EN", Hook: "Hyper-Scale", Conversion_Score: (integer 1-100).',
    expected_output='A JSON list of 10 high-conversion Global prospects.',
    agent=lead_hunter
)

hunt_quebec = Task(
    description='Search for 10 mid-sized manufacturing or service firms in Montreal or Quebec City. Output: JSON list with Company Name, Website, Industry, Language: "QC", Hook: "Labor Shortage Mitigation", Conversion_Score: (integer 1-100).',
    expected_output='A JSON list of 10 high-conversion Quebec prospects.',
    agent=lead_hunter
)

hunt_canada = Task(
    description='Search for 10 high-growth mid-sized firms in Toronto or Vancouver (Finance/Tech/Logistics). Output: JSON list with Company Name, Website, Industry, Language: "EN", Hook: "Operational Efficiency", Conversion_Score: (integer 1-100).',
    expected_output='A JSON list of 10 high-conversion Canadian prospects.',
    agent=lead_hunter
)

lead_crew = Crew(
    agents=[lead_hunter],
    tasks=[hunt_mena, hunt_eu, hunt_global, hunt_quebec, hunt_canada],
    process=Process.sequential
)

import time

if __name__ == "__main__":
    print("🎯 HUNTING FOR REAL PROSPECTS (WORLDWIDE + CANADA METRO)...")
    
    # Run tasks with manual delays to respect Groq TPM limits
    all_leads = []
    
    for task in [hunt_mena, hunt_eu, hunt_global, hunt_quebec, hunt_canada]:
        print(f"🔄 Executing: {task.description[:50]}...")
        try:
            task_result = task.execute_sync()
            res_str = str(task_result)
            import re
            arrays = re.findall(r'\[.*?\]', res_str, re.DOTALL)
            for arr in arrays:
                try:
                    leads = json.loads(arr)
                    if isinstance(leads, list):
                        all_leads.extend(leads)
                except:
                    continue
            print(f"⏳ Task complete. Cooling down for 15s to reset Groq limits...")
            time.sleep(15)
        except Exception as e:
            print(f"❌ Task failed: {e}")
            time.sleep(10) # Minimal wait on failure
    
    if all_leads:
        with open("leads.json", "w") as f:
            json.dump(all_leads, f, indent=4)
        print(f"✅ FOUND {len(all_leads)} PROSPECTS. Saved to leads.json")
    else:
        print("🛑 No leads captured in this cycle.")
