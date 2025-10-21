import requests
import json
import sys
from bs4 import BeautifulSoup
import re
import clear_string as clear_str


def collect_issue_message(html_content):
    extracted_info = extract_github_issue_info(html_content)
    if len(extracted_info['comments']) == 0:
        print("Could not extract issue information, only same the html_content for debug")
        with open('debug_page_issue.html', 'w', encoding='utf-8') as f:
            f.write(html_content)
    else:
        return extracted_info


def extract_github_issue_info(html_content):
    """Extract title, comments, and labels from GitHub issue HTML."""
    
    soup = BeautifulSoup(html_content, 'html.parser')
    
    title_element = soup.find('bdi', {'data-testid': 'issue-title'})
    title = title_element.text.strip() if title_element else ""
    
    # Extract Labels
    labels = []
    label_elements = soup.find_all('span', class_=re.compile(r'TokenBase__StyledTokenBase'))
    for label in label_elements:
        label_text = label.find('span', class_='prc-Text-Text-0ima0')
        if label_text:
            labels.append(label_text.text.strip())
    
    labels = list(set(labels))
    
    # Extract Comments/Discussions
    comments = []

    main_author = None
    author_element = soup.find('a', {'data-testid': 'issue-body-header-author'})
    if author_element:
        main_author = author_element.text.strip()
    
    issue_body = soup.find('div', {'data-testid': 'markdown-body'})
    if issue_body:
        main_comment = issue_body.get_text(separator='\n', strip=True)
        comments.append({
            "author": main_author,
            "content": clear_str.clearing_string(main_comment)
        })

    script_tags = soup.find_all('script', {'type': 'application/json'})
    
    for script in script_tags:
        if 'data-target="react-app.embeddedData"' in str(script):
            try:
                data = json.loads(script.string)

                timeline_items = data.get('payload', {}).get('preloadedQueries', [{}])[0].get(
                    'result', {}).get('data', {}).get('repository', {}).get(
                    'issue', {}).get('frontTimelineItems', {}).get('edges', [])
                
                for item in timeline_items:
                    node = item.get('node', {})
                    if node.get('__typename') == 'IssueComment':
                        author = node.get('author', {}).get('login', 'Unknown')
                        body = node.get('body', '')
                        if body and author != main_author:  
                            comments.append({
                                "author": author,
                                "content": clear_str.clearing_string(body)
                            })
                            
            except (json.JSONDecodeError, KeyError, IndexError):
                pass
    
    result = {
        "title": clear_str.clearing_string(title),
        "labels": labels,
        "comments": comments
    }
    
    return result


    