import requests
import sys
from pathlib import Path
import re
import json

from url_extactor import extract_urls_from_page
from github_commit_extractor import collect_commit_message
from github_PR_extractor import collect_pull_message
from github_issue_extractor import collect_issue_message
from github_security_extractor import collect_security_message

global urls, global_data
urls = []

global_data = {
    'commit': None,
    'pull_requests': [],
    'issues': [],
    'security': []
}

def fetch_page_content(url, token, pageStr):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    if token:
        headers['Authorization'] = f'token {token}'
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error fetching page: {e}")
        print(f"Failed to fetch {pageStr} page content")
        return None

def save_combined_json(commit_url):
    # Extract commit hash from URL
    match = re.search(r'https://github\.com/([^/]+)/([^/]+)/commit/([a-f0-9]{7})', commit_url)
    name = f"{match.group(1)}_{match.group(2)}"
    if match:
        filename = f"output-{match.group(3)}_{name}.json"
    else:
        filename = "output-unknown.json"
    
    current_dirctory = Path(__file__).resolve().parent 
    output_path = current_dirctory.parent / "raw_data" / "output"
    output_path.mkdir(exist_ok=True)
    output_file = output_path / filename
    
    # Ensure all sections have null if no data was collected
    final_data = {
        'commit_index': match.group(3),
        'commit_url': commit_url,
        'commit': global_data['commit'],
        'pull_requests': global_data['pull_requests'] if global_data['pull_requests'] else None,
        'issues': global_data['issues'] if global_data['issues'] else None,
        'security': global_data['security'] if global_data['security'] else None
    }
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(final_data, f, indent=2, ensure_ascii=False)
        print(f"All data saved to {output_file}")
    except Exception as e:
        print(f"Error saving combined file: {e}")

def reset_globals():
    global urls, global_data
    urls = []
    global_data = {
        'commit': None,
        'pull_requests': [],
        'issues': [],
        'security': []
    }

def extract_commit_page(base_url, get_script_content= False ,token=None):
    global urls, global_data

    html_content = fetch_page_content(base_url,token,"commit")

    if html_content is None:
        return False
    
    urls =  extract_urls_from_page(html_content,base_url)
    commit_message = collect_commit_message(html_content)
    
    if get_script_content:
        commit_message['changed_files_content'] = extract_script_content(base_url,commit_message['parent'],commit_message['changed_files'])

    global_data['commit'] = commit_message

    for url in urls:
        if "/pull/" in url:
            extract_pull_page(url,token)

    for url in urls:
        if "/issues/" in url:
            extract_issue_page(url,token)
        elif "/security/" in url:
            extract_security_page(url,token)

    return True
    

def extract_pull_page(base_url, token=None):
    global urls, global_data
    html_content = fetch_page_content(base_url,token,"pull")

    if html_content is None:
        return

    issue_url = extract_urls_from_page(html_content,base_url, True)
    urls = list(set(issue_url + urls))

    pull_data = collect_pull_message(html_content)
    if pull_data:
        global_data['pull_requests'].append(pull_data)


def extract_issue_page(base_url, token=None):
    global global_data
    html_content = fetch_page_content(base_url,token, "issue")

    if html_content is None:
        return

    issue_data = collect_issue_message(html_content)
    if issue_data:
        global_data['issues'].append(issue_data)

def extract_security_page(base_url, token=None):
    global global_data
    html_content = fetch_page_content(base_url,token, "security")

    if html_content is None:
        return

    security_data = collect_security_message(html_content)
    if security_data:
        global_data['security'].append(security_data)

def extract_script_content(base_url,parent_id,file_names,token=None):
    pattern = r'https://github\.com/([^/]+/[^/]+)/commit/([a-f0-9]+)'
    match = re.match(pattern, base_url)
   
    if not match:
        return []
    
    all_script = []
    repository_name = match.group(1)
    current_id = match.group(2)
    

    for name in file_names:
        script_content_format = {
            'before' : '',
            'after' : ''
        }

        script_content_format['before'] = fetch_page_content(
            f"https://raw.githubusercontent.com/{repository_name}/{parent_id}/{name}",
            token,
            "script")
        script_content_format['after'] = fetch_page_content(
            f"https://raw.githubusercontent.com/{repository_name}/{current_id}/{name}",
             token,
            "script"
        )
        all_script.append(script_content_format)
    
    return all_script

def load_json_from_file(filename):
    try:
        with open(filename, 'r') as file:
            data = json.load(file)
        return data
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        return None
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in file '{filename}': {e}")
        return None
    except Exception as e:
        print(f"Error reading file: {e}")
        return None

def process_single_url(commit_url, get_script_content=False ,token=None):
    reset_globals()
    try:
        success_collect = extract_commit_page(commit_url, get_script_content, token)
        if success_collect:
            save_combined_json(commit_url)
        else:
            print(f"Fail to collect content form {commit_url}, not data to saved")
    except Exception as e:
        print(f"Error processing {commit_url}: {e}")

def main():
    token = None
    urls= []
    argument_len = len(sys.argv)

    if argument_len == 2:
        input_variable = sys.argv[1]

        if '.json' in input_variable:
            data = load_json_from_file(input_variable)
            
            if data is None:
                print("No invalid value in Json file, exit")
                sys.exit(1)
            
            token =  data.get("token")
            urls = data.get("urls", [])
        else:
            urls.append(input_variable)
    elif argument_len == 3 and '.json' not in sys.argv[1]:
        urls.append(sys.argv[1])
        token = sys.argv[2]
    else:
        print("Error input length")
        sys.exit(1)
    
    for url in urls:
        process_single_url(url,False,token)




    

if __name__ == "__main__":
    main()