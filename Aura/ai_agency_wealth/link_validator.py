import requests
import re

def validate_links_in_text(text):
    """
    Extracts all URLs from text and verifies they return a 200 OK status.
    Returns (is_valid, failing_urls)
    """
    # Regex to find URLs
    url_pattern = r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[/\w\.-]*'
    urls = re.findall(url_pattern, text)
    
    if not urls:
        return True, [] # No links to fail

    failing_urls = []
    for url in urls:
        try:
            # Use a short timeout to prevent hanging the engine
            response = requests.head(url, timeout=5, allow_redirects=True)
            if response.status_code != 200:
                failing_urls.append(f"{url} (Status: {response.status_code})")
        except Exception as e:
            failing_urls.append(f"{url} (Error: {str(e)})")
            
    return len(failing_urls) == 0, failing_urls

if __name__ == "__main__":
    # Test with our core domain
    test_text = "Check out our audit at https://meziani.org/"
    is_ok, fails = validate_links_in_text(test_text)
    if is_ok:
        print("✅ Links Verified: 200 OK")
    else:
        print(f"❌ Link Validation Failed: {fails}")
