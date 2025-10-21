from bs4 import BeautifulSoup
import json
import sys
import requests
import clear_string as clear_str

def collect_security_message(html_content):
    security_infor = extract_security_content(html_content)

    if not security_infor:
        print("Could not extract security information, only same the html_content for debug")
        with open('debug_page_security.html', 'w', encoding='utf-8') as f:
            f.write(html_content)
    else:
        return security_infor



def extract_security_content(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    
    extracted_content = {
        'title': None,
        'content': None
    }
    
    # Extract title
    title_element = soup.find('h1', class_='gh-header-title')
    if title_element:
        extracted_content['title'] = clear_str.clearing_string(title_element.get_text(strip=True))
    
    # Extract main description
    body_element = soup.find('div', class_='markdown-body comment-body p-0')
    if body_element:
        extracted_content['content']= clear_str.clearing_string(body_element.get_text(separator='\n', strip=True))
        

    return extracted_content


