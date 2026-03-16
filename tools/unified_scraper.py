import argparse
import sys
import json
import httpx
import asyncio
from bs4 import BeautifulSoup

async def score_launch(text_content: str, media_count: int, title: str):
    """Uses the local Nexa gateway to score the launch based on scraped content."""
    prompt = f"""
You are an expert product launch evaluator. Please analyze the following landing page content and provide a 'Launch Score' out of 10, along with a brief analysis. 
Consider the clarity of the value proposition, the presence of media (images/videos), and overall copy quality.

Title: {title}
Media Elements Found: {media_count}
Content Snippet:
{text_content[:2000]}  # Truncated for context limits

Provide your analysis and the final score (e.g., 'Score: 8/10').
"""

    # Using the local gateway we just fixed
    url = "http://127.0.0.1:8765/v1/chat/completions"
    payload = {
        "model": "llama3.2", # Defaulting to the local model we configured
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3
    }
    
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(url, json=payload)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"Failed to score launch via Gateway: {e}"

async def main():
    parser = argparse.ArgumentParser(description="Unified Scraper & Launch Scorer")
    parser.add_argument("url", help="The URL to scrape and score")
    args = parser.parse_args()

    print(f"[*] Fetching {args.url}...")
    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(args.url)
            response.raise_for_status()
            html = response.text
    except Exception as e:
        print(f"[!] Error fetching URL: {e}")
        sys.exit(1)

    print("[*] Parsing content...")
    soup = BeautifulSoup(html, 'html.parser')
    
    # Extract Title
    title = soup.title.string if soup.title else "No Title"
    
    # Extract Text (removing scripts and styles)
    for script in soup(["script", "style"]):
        script.extract()
    text = soup.get_text(separator=' ', strip=True)
    
    # Extract Media
    images = [img.get('src') for img in soup.find_all('img') if img.get('src')]
    videos = [vid.get('src') for video in soup.find_all('video') for vid in video.find_all('source') if vid.get('src')]
    media_count = len(images) + len(videos)

    print(f"[*] Found Title: {title}")
    print(f"[*] Found {media_count} media elements.")
    print("[*] Scoring the launch using local AI gateway...")

    score_result = await score_launch(text, media_count, title)
    
    print("\n" + "="*50)
    print("LAUNCH SCORE & ANALYSIS")
    print("="*50)
    print(score_result)
    print("="*50)

if __name__ == "__main__":
    asyncio.run(main())
