from bs4 import BeautifulSoup
import json
import re
import sys
import clear_string as clear_str

def collect_commit_message(html_content):
    commit_info = extract_commit_info(html_content)

    if not commit_info['commit_message'] and not commit_info['changed_files']:
        print("Could not extract commit information, only same the html_content for debug")
        with open('debug_page_commit.html', 'w', encoding='utf-8') as f:
            f.write(html_content)
    else:
        return save_to_json(commit_info)


def extract_commit_info(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    
    commit_info = {
        'commit_message': '',
        'description': '',
        'changed_files': [],
        'parent_id': ''
    }

    # Extract Commit title
    title_tag = soup.find('title')
    if title_tag:
        title_text = title_tag.get_text(strip=True)
        # Extract commit message before the · character
        if '·' in title_text:
            commit_info['commit_message'] = title_text.split('·')[0].strip()
    
    
    # Extract Commit message
    twitter_description = soup.find('span', {
    'class': 
    'ws-pre-wrap extended-commit-description-container f6 wb-break-word text-mono mt-2 prc-Text-Text-0ima0'
    })
    if twitter_description:
        commit_info['description'] = twitter_description.get_text(separator='\n', strip=True)
    
    # Extract changed files
    script_tag = soup.find('script', {'type': 'application/json', 'data-target': 'react-app.embeddedData'})
    
    if not script_tag:
        return commit_info
    
    all_script_name= []
    data = json.loads(script_tag.string)
    for entry in data['payload']['diffEntryData']:
        all_script_name.append(entry['path'])
        
                    
    # Remove duplicates
    commit_info['changed_files'] = list(all_script_name)
    commit_info['parent_id'] = data['payload']['commit']['parents'][0]
    
    return commit_info

def save_to_json(commit_info):
    """
    Save extracted commit information to a JSON file
    """
    output_data = {
        'commit_message': clear_str.clearing_string(commit_info['commit_message']),
        'description': clear_str.clearing_string(commit_info['description']),
        'changed_files_count': len(commit_info['changed_files']),
        'changed_files': commit_info['changed_files'],
        'changed_files_content': [],
        'parent': commit_info['parent_id']
    }
    
    return output_data

