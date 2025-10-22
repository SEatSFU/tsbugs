import requests
import json
import sys
from urllib.parse import urlparse
import time

from nltk.stem import WordNetLemmatizer as wnl
from nltk.tokenize import word_tokenize


def parse_github_url(url):
    url = url.strip().rstrip('/')
    
    parsed = urlparse(url)
    path_parts = parsed.path.strip('/').split('/')
    
    if len(path_parts) >= 2:
        owner = path_parts[0]
        repo = path_parts[1]
        return owner, repo
    else:
        raise ValueError("Invalid GitHub repository URL")


def fetch_commits(owner, repo, token=None, max_commits=1000, until_date=None, since_date=None):
    commits = []
    page = 1
    per_page = 100
    
    headers = {
        'Accept': 'application/vnd.github.v3+json'
    }
    
    if token:
        headers['Authorization'] = f'token {token}'
    
    print(f"Fetching commits from {owner}/{repo}...")
    
    while len(commits) < max_commits:
        try:
            url = f"https://api.github.com/repos/{owner}/{repo}/commits"
            params = {
                'per_page': per_page,
                'page': page
            }

            if until_date:
                params['until'] = until_date

            if since_date:
                params['since'] = since_date
                if until_date and until_date < since_date:
                    print("Not vaild date input")
                    return
            
            response = requests.get(url, headers=headers, params=params)
            
            # Check rate limiting
            if response.status_code == 403:
                rate_limit = response.headers.get('X-RateLimit-Remaining', '0')
                if rate_limit == '0':
                    print("GitHub API rate limit reached. Consider using a personal access token.")
                    break
            
            response.raise_for_status()
            
            page_commits = response.json()
            
            if not page_commits:
                break
            
            for commit in page_commits:
                commit_info = {
                    'sha': commit['sha'],
                    'title': commit['commit']['message'].split('\n')[0],
                    'url': commit['html_url']
                }
                commits.append(commit_info)
                
                if len(commits) >= max_commits:
                    break
            
            print(f"Fetched {len(commits)} commits so far...")
            page += 1
            
            time.sleep(0.1)
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching commits: {e}")
            break
    
    return commits[:max_commits]


def filter_bug_fix_commits(commits):
    filter_keywords = ['typo']
    filtered_commits = []
    
    for commit in commits:
        tokens = word_tokenize(commit['title'].lower())
        clear_title = [wnl().lemmatize(word) for word in tokens]
        if 'fix' in clear_title and not any(keyword in clear_title for keyword in filter_keywords):
            filtered_commits.append(commit['url'])
    
    return filtered_commits


def save_to_json(urls, repo, user_token, filename='possible_bug_list.json'):
    data = {
        'token': user_token,
        'urls': urls
    }

    complete_filename = f"{repo}_{filename}"
    
    with open(complete_filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    
    print(f"Saved {len(urls)} bug-fix commit URLs to {complete_filename}")


def main():
    repo_url = ""
    token = None
    collect_size = 1200
    argument_len = len(sys.argv)

    if argument_len != 2 and argument_len != 3 and argument_len != 4:
        print("Error input length")
        sys.exit(1)
    elif argument_len > 2:
        collect_size = int(sys.argv[2])
        if argument_len == 4:
            token = sys.argv[3]
    
    repo_url = sys.argv[1]
    
    try:
        owner, repo = parse_github_url(repo_url)
        print(f"Repository: {owner}/{repo}")
        
        # Fetch commits
        commits = fetch_commits(owner, repo, token, collect_size,'2024-02-28T00:00:00Z', '2023-03-01T00:00:00Z')
        print(f"Total commits fetched: {len(commits)}")
        
        # Filter bug-fix commits
        bug_fix_urls = filter_bug_fix_commits(commits)
        print(f"Found {len(bug_fix_urls)} commits with fix-related keywords")
        
        save_to_json(bug_fix_urls, repo, token)
        
    except ValueError as e:
        print(f"Github URL Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()
