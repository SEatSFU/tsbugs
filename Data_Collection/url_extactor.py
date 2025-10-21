import re
import sys


def extract_urls_from_page(html_content, base_url,onlyIssue=False):
    if not html_content:
        return []
    
    urls = set()
    url_pattern = r'href="([^"]+)"'
    matches = re.findall(url_pattern, html_content)

    url_boolean_exp = None
    for url in matches:
        url = url.replace('\n', '')
        if correct_github_url(url) == False:
                continue

        if onlyIssue :
            url_boolean_exp = "/issues/" in url
        else:
            url_boolean_exp = "/issues/" in url or "/pull/" in url 

        if (url_boolean_exp or ("/security/" in url and url != "https://github.com/security/advanced-security")) and base_url not in url:
            urls.add(url)
        
    return sorted(urls)

def correct_github_url(url):
    if ("https://github.com/" not in url and "http://github.com/" not in url ) or "tree/HEAD/" in url:
        return False
    else:
        return True