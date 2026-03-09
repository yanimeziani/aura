import os
import json
from crewai import Agent, Task, Crew, Process
from langchain_community.tools import DuckDuckGoSearchRun
from dotenv import load_dotenv

load_dotenv()

# --- Agent: The Global Futurist ---
pulse_editor = Agent(
    role='Lead Editor - The Sovereign Pulse',
    goal='Write a disruptive, technical newsletter about AI sovereignty, global yields, and automation arbitrage.',
    backstory='You are a high-level strategist. You see the world as a series of automation opportunities. You write for digital nomads, SMB owners, and sovereign individuals.',
    verbose=True,
    allow_delegation=False,
    llm=f"groq/{os.getenv('OPENAI_MODEL_NAME')}"
)

# --- Task: Create Newsletter ---
newsletter_task = Task(
    description="""
    Analyze current 2026 trends in:
    1. Local AI (Ollama/Groq) vs Cloud.
    2. Global USD Yields.
    3. The rise of automation in emerging markets like Algeria.
    
    Write a 500-word disruptive newsletter. 
    Style: Technical, blunt, and forward-looking.
    Include a link to the Meziani AI Audit: https://meziani.org/
    """,
    expected_output='A markdown-formatted newsletter ready for email distribution.',
    agent=pulse_editor
)

newsletter_crew = Crew(
    agents=[pulse_editor],
    tasks=[newsletter_task],
    process=Process.sequential
)

if __name__ == "__main__":
    print("📰 GENERATING THE SOVEREIGN PULSE...")
    result = newsletter_crew.kickoff()
    with open("latest_newsletter.md", "w") as f:
        f.write(str(result))
    print("✅ Newsletter generated: latest_newsletter.md")
