import re
import array
import json
import sys
from pathlib import Path
import os

def process_urls(urls):
    process_url = []
    repository = []
    for url in urls:
        match = re.search(r'https://github\.com/([^/]+)/([^/]+)/commit/([a-f0-9]{7})', url)
        process_url.append(match.group(3))
        repository.append(match.group(2))

    return process_url, repository
    

def execute_json(folder_path):
    json_files = []
    
    for file in os.listdir(folder_path):
        if file.endswith('.json'):
            json_files.append(file)
    
    if len(json_files) == 0:
        return

    commit_info = []
    for json_file in json_files:
        json_path =  os.path.join(folder_path, json_file)
        
        with open(json_path, 'r') as f:
            data = json.load(f)

        commit_info.append(data['commit_url'])
    
    return commit_info

def get_repository_acount(index_array, repository_array,urls):
    num_repos = len(repository_array)
    acount = [0] * num_repos

    match_index, match_repos = process_urls(urls)

    for index in index_array:
            idx = match_index.index(index)
            if idx < 0:
                print("error happen")
                break
            repository = match_repos[idx]
            for i in range(num_repos):
                if repository == repository_array[i]:
                    acount[i] += 1
    
    for i in range(num_repos):
        print(f'{repository_array[i]} : {acount[i]}')

    print("\n-------------\n")



if __name__ == "__main__":
    if len(sys.argv) ==3:
        predict_result_json = sys.argv[1]
        predict_commits_json = sys.argv[2]
    else:
        predict_result_json = 'predict_label_collection.json'
        predict_commits_json = 'github_repository_name.json'

    try:
        with open(predict_commits_json, 'r') as file:
            predict_commit = json.load(file)
        repository_array = predict_commit["repository_name"]

        current_dirctory = Path(__file__).resolve().parent 
        folder_path = current_dirctory.parent / "raw_data" / "predict-sample-collection"
        commit_url = execute_json(folder_path)

        with open(predict_result_json, 'r') as file:
            data = json.load(file)

        for category_name, category_data in data['categories'].items():
            index_array = category_data['indices']
            print(f"Category: {category_name}:\n")
            
            get_repository_acount(index_array,repository_array,commit_url)
   
    except Exception as e:
        print(f"Error reading json file: {e}")

