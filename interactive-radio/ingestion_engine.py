import os
import glob
import json
import logging
import httpx
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "qwen3.5:2b"

class IngestionEngine:
    """
    Sweeps the Aura monorepo for new docs, logs, and PRDs.
    Summarizes them into "radio-friendly" briefing notes.
    """

    def __init__(self, root_dir="/root"):
        self.root_dir = root_dir
        self.briefing_file = os.path.join(root_dir, "interactive-radio/briefing.json")

    async def summarize_text(self, text: str, context: str = "general"):
        """Uses Ollama to summarize text into a punchy radio update."""
        prompt = f"""Summarize the following technical content for a live radio broadcast.
The radio hosts are David, Sarah, and Chloe. 
Make it conversational, slightly urgent, and highlight the key impact.
Keep it under 3 sentences.

CONTENT TYPE: {context}
CONTENT:
{text}
"""
        payload = {
            "model": MODEL,
            "prompt": prompt,
            "stream": False
        }
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(OLLAMA_URL, json=payload)
                if response.status_code == 200:
                    return response.json().get("response", "No summary available.")
        except Exception as e:
            logger.error(f"Summarization error: {e}")
            return f"Error summarizing {context}."

    async def sweep_and_ingest(self):
        """Sweeps key files and updates the briefing."""
        briefings = []

        # 1. Sweep PRD.md
        prd_path = os.path.join(self.root_dir, "PRD.md")
        if os.path.exists(prd_path):
            with open(prd_path, "r") as f:
                content = f.read()[:2000] # Cap for context
                summary = await self.summarize_text(content, "Product Requirement Document")
                briefings.append({"source": "PRD", "update": summary})

        # 2. Sweep Project Summary
        summary_path = os.path.join(self.root_dir, "PROJECT_SUMMARY.md")
        if os.path.exists(summary_path):
            with open(summary_path, "r") as f:
                content = f.read()[:2000]
                summary = await self.summarize_text(content, "Project Summary")
                briefings.append({"source": "Project Summary", "update": summary})

        # 3. Sweep aura-vault-crypto doc (newly created)
        vault_doc = os.path.join(self.root_dir, "llm-port-project/src/aura/docs/aura-vault-crypto.md")
        if os.path.exists(vault_doc):
            with open(vault_doc, "r") as f:
                content = f.read()[:2000]
                summary = await self.summarize_text(content, "Aura Vault & Crypto Architecture")
                briefings.append({"source": "Vault Crypto", "update": summary})

        # 4. Git Log sweep
        try:
            import subprocess
            git_log = subprocess.check_output(
                ["git", "log", "-n", "3", "--pretty=format:%s"],
                cwd=self.root_dir
            ).decode("utf-8")
            summary = await self.summarize_text(git_log, "Recent Commits")
            briefings.append({"source": "Git History", "update": summary})
        except:
            pass

        # Write to briefing file
        with open(self.briefing_file, "w") as f:
            json.dump(briefings, f, indent=4)
        
        logger.info(f"Ingestion complete. {len(briefings)} updates saved to {self.briefing_file}")

if __name__ == "__main__":
    engine = IngestionEngine()
    asyncio.run(engine.sweep_and_ingest())
