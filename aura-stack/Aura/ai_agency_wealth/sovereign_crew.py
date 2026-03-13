"""
sovereign_crew.py — Drop-in replacement for crewai + langchain_community.tools.

Deps: httpx (already required), ddgs (duckduckgo-search, already required).
No external orchestration framework. No supply chain risk.

Drop-in usage:
    from sovereign_crew import Agent, Task, Crew, Process, web_snippet
"""

from __future__ import annotations

import os
import signal
import re
import httpx
from typing import Optional


# ── LLM ──────────────────────────────────────────────────────────────────────

_GROQ_BASE = "https://api.groq.com/openai/v1"
_DEFAULT_MODEL = os.getenv("OPENAI_MODEL_NAME", "llama3-70b-8192")
_GROQ_KEY = os.getenv("GROQ_API_KEY", "")


def _call_llm(system: str, user: str, model: str) -> str:
    """Direct Groq API call (OpenAI-compatible)."""
    # Accept "groq/model-name" or bare "model-name"
    if "/" in model:
        model = model.split("/", 1)[1]

    response = httpx.post(
        f"{_GROQ_BASE}/chat/completions",
        headers={
            "Authorization": f"Bearer {_GROQ_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.7,
            "max_tokens": 4096,
        },
        timeout=120.0,
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


# ── Web Search ────────────────────────────────────────────────────────────────

_INJECTION_PATTERNS = re.compile(
    r"(ignore previous|disregard|act as|jailbreak|system prompt|"
    r"new instructions|override|forget|pretend you are|you are now|"
    r"DAN|do anything now)",
    re.IGNORECASE,
)


def _sanitize(text: str) -> str:
    text = _INJECTION_PATTERNS.sub("[REDACTED]", text)
    return text[:2000]


def web_snippet(query: str, timeout_sec: int = 15) -> str:
    """
    Run a DuckDuckGo search with timeout and injection sanitisation.
    Returns a plain-text snippet suitable for injecting into a task description.
    Drop-in replacement for DuckDuckGoSearchRun().run(query).
    """
    from ddgs import DDGS

    def _timeout_handler(signum, frame):
        raise TimeoutError(f"web search timed out after {timeout_sec}s")

    old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
    signal.alarm(timeout_sec)
    try:
        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=6))
        lines = [f"- {r['title']}: {r['body']}" for r in results if r.get("body")]
        raw = "\n".join(lines)
    except Exception as exc:
        raw = f"[search unavailable: {exc}]"
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old_handler)

    return _sanitize(raw)


# ── Agent ─────────────────────────────────────────────────────────────────────

class Agent:
    def __init__(
        self,
        *,
        role: str,
        goal: str,
        backstory: str,
        llm: Optional[str] = None,
        verbose: bool = True,
        allow_delegation: bool = False,
        **_kwargs,
    ):
        self.role = role
        self.goal = goal
        self.backstory = backstory
        self.llm = llm or f"groq/{_DEFAULT_MODEL}"
        self.verbose = verbose

    def system_prompt(self) -> str:
        return (
            f"You are {self.role}.\n\n"
            f"Goal: {self.goal}\n\n"
            f"Background: {self.backstory}\n\n"
            "Be precise, professional, and output exactly what is requested."
        )


# ── Task ──────────────────────────────────────────────────────────────────────

class Task:
    def __init__(
        self,
        *,
        description: str,
        expected_output: str,
        agent: Agent,
        context: Optional[list[Task]] = None,
        **_kwargs,
    ):
        self.description = description
        self.expected_output = expected_output
        self.agent = agent
        self.context: list[Task] = context or []
        self.output: Optional[str] = None


# ── Crew ──────────────────────────────────────────────────────────────────────

class Crew:
    def __init__(
        self,
        *,
        agents: list[Agent],
        tasks: list[Task],
        process: str = "sequential",
        verbose: bool = True,
        **_kwargs,
    ):
        self.agents = agents
        self.tasks = tasks
        self.verbose = verbose

    def kickoff(self) -> CrewResult:
        for task in self.tasks:
            # Prepend outputs from context tasks (task dependencies)
            context_block = ""
            for dep in task.context:
                if dep.output:
                    context_block += f"\n\nContext from previous task:\n{dep.output}\n"

            user_msg = task.description
            if context_block:
                user_msg = context_block.strip() + "\n\n" + user_msg
            user_msg += f"\n\nExpected output: {task.expected_output}"

            output = _call_llm(
                system=task.agent.system_prompt(),
                user=user_msg,
                model=task.agent.llm,
            )
            task.output = output

            if self.verbose:
                print(f"\n[{task.agent.role}]\n{'─' * 60}\n{output}\n")

        return CrewResult(self.tasks)


class TaskOutput:
    """Mirrors crewai's TaskOutput for result.tasks_output compatibility."""

    def __init__(self, raw: str):
        self.raw = raw

    def __str__(self) -> str:
        return self.raw


class CrewResult:
    """Mirrors crewai's CrewOutput."""

    def __init__(self, tasks: list[Task]):
        self.tasks_output = [TaskOutput(t.output or "") for t in tasks]

    def __str__(self) -> str:
        return "\n\n---\n\n".join(str(t) for t in self.tasks_output)


# ── Process compat shim ───────────────────────────────────────────────────────

class Process:
    sequential = "sequential"
    hierarchical = "hierarchical"
