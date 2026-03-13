import os
import json
import litellm
from duckduckgo_search import DDGS
from dotenv import load_dotenv

load_dotenv()


def generate_dynamic_offer():
    print("🔍 Analyzing autonomous systems market...")

    # 1. Search for trends
    results = DDGS().text("autonomous infrastructure systems 2024", max_results=3)
    context = "\n".join([f"- {r['title']}: {r['body']}" for r in results])

    print("🧠 Crafting infrastructure offer...")
    # 2. Use LLM to generate an offer
    prompt = f"""
    Based on the following autonomous systems trends:
    {context}
    
    Create a professional infrastructure system offer targeted at the Canadian SMB and Enterprise market.
    Respond ONLY with a valid JSON object in the following format:
    {{
        "title": "Sovereign Canadian Infrastructure System",
        "description": "Deploy autonomous infrastructure for continuous operation and systematic execution within Canada.",
        "price_cad": 9900,
        "features": ["Feature 1", "Feature 2", "Feature 3"]
    }}
    Make the price between 9900 and 49900 (in cents, so $99 to $499 CAD).
    Focus on operational efficiency, systematic execution, infrastructure reliability, and Canadian data sovereignty.
    Use Canadian English spelling (e.g., digitalisation, optimisation).
    """

    # Dual-Model Strategy: Qwen primary, Gemma fallback
    models = [os.getenv("OPENAI_MODEL_NAME", "ollama/qwen2.5:3b"), "ollama/gemma2:2b"]
    api_base = os.getenv("OPENAI_API_BASE", "http://localhost:11434")

    success = False
    for model in models:
        try:
            print(f"🚀 Attempting generation with {model}...")
            response = litellm.completion(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                api_base=api_base,
                api_key=os.getenv("OPENAI_API_KEY", "ollama"),
                response_format={"type": "json_object"},
                timeout=60,
            )

            offer_content = response.choices[0].message.content
            offer_json = json.loads(offer_content)

            # 3. Save to file
            with open("current_offer.json", "w") as f:
                json.dump(offer_json, f, indent=4)

            print(
                f"✅ Infrastructure offer generated using {model}: {offer_json['title']} at ${offer_json['price_usd'] / 100}"
            )
            success = True
            break

        except Exception as e:
            print(f"⚠️ Model {model} failed: {e}")
            continue

    if not success:
        print("❌ All models failed. Using hardcoded fallback.")
        # Fallback offer
        fallback = {
            "title": "AI Agency Infrastructure",
            "description": "Deploy autonomous multi-agent systems for systematic operation and infrastructure management.",
            "price_usd": 9900,
            "features": [
                "Multi-Agent Orchestration",
                "Real-time System Monitoring",
                "Automated Strategy Execution",
            ],
        }
        with open("current_offer.json", "w") as f:
            json.dump(fallback, f, indent=4)


if __name__ == "__main__":
    generate_dynamic_offer()
