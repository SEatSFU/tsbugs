import requests
from bs4 import BeautifulSoup
import json
import re
import sys
import clear_string as clear_str

def collect_pull_message(html_content):
    pr_title, discussions = extract_pr_discussions(html_content)
    if not discussions:
        print("Could not extract pull information, only store the html content for debug ")
        with open('debug_page_pull.html', 'w', encoding='utf-8') as f:
            f.write(html_content)
    else:
        return save_to_json(pr_title, discussions)

def robot_publish_content(content_parts):
    if "The latest updates on your projects. Learn more" in  content_parts and "for Git ↗︎" in content_parts:
        # vercel robot publish
        return True
    elif "This pull request has been ignored for the connected" in content_parts and "because there are no changes detected" in content_parts:
        # current repostory robot
        return True
    else :
        return False

def extract_pr_discussions(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    discussions = []
    pr_title_text = ""
    
    pr_title = soup.find('h1', class_='gh-header-title')
    if pr_title:
        pr_title_text = pr_title.get_text(strip=True)
    
    main_discussion = {
        'discussion_number': 1,
        'comments': []
    }
    
    # Extract PR first comment
    pr_body = soup.find('div', class_='comment-body')
    if pr_body:
        first_comment = {
            'type': 'pr_description',
            'content': clear_str.clearing_string(pr_body.get_text(strip=True))
        }

        pr_author = soup.find('a', class_='author')
        if pr_author:
            first_comment['author'] = pr_author.get_text(strip=True)
        
        main_discussion['comments'].append(first_comment)
    
    if main_discussion['comments']:
        discussions.append(main_discussion)
    
    discussion_tables = soup.find_all('table', class_='d-block user-select-contain', attrs={'data-paste-markdown-skip': True})
    
    # Extract PR other comments
    discussion_number = 2
    for table in discussion_tables:
        comment_td = table.find('td', class_='d-block comment-body markdown-body js-comment-body')
        if comment_td:
            p_tags = comment_td.find_all('p', dir='auto')
            if p_tags:
                content_parts = []
                for p in p_tags:
                    text = p.get_text(strip=True)
                    if text:
                        content_parts.append(text)
                
                if content_parts and robot_publish_content(content_parts[0]) == False:
                    #TODO correctly extract the author  
                    discussion_data = {
                        'discussion_number': discussion_number,
                        'comments': [
                            {
                                'content': clear_str.clearing_string('\n'.join(content_parts))
                            }
                        ]
                    }
                    discussions.append(discussion_data)
                    discussion_number += 1
    
    return pr_title_text, discussions



def save_to_json(pr_title, discussions):
    output_data = {
        'pr_title': clear_str.clearing_string(pr_title),
        'total_discussions': len(discussions),
        'discussions': discussions
    }

    return output_data
