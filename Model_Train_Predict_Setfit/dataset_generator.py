from label_studio_sdk import LabelStudio
from datasets import Dataset

def extract_data_for_training(tasks):
    extracted_data = []
    
    for task in tasks:
        if not task.annotations:
            continue

        label = None
        # get label information
        for annotation in task.annotations:
            if annotation.get('result'):
                for result in annotation['result']:
                    if 'value' in result and 'choices' in result['value']:
                        label = result['value']['choices'][0]
                        break
                if label:
                    break
        
        if not label:
            continue
            
        data_content = extract_body_part(task)

        # Combine all data content into a single text
        if data_content:
            text = " | ".join(data_content)
            extracted_data.append({
                    'text': text,
                    'label': label
            })

    if extracted_data:
        return Dataset.from_list(extracted_data)
    else:
        return None

def extract_data_for_prediction(tasks):
    extracted_data = []

    for task in tasks:
        if task.annotations:
            continue

        data_content = extract_body_part(task)

        if data_content:
            text = " | ".join(data_content)
            extracted_data.append({
                    'text': text,
                    'id': task.id  
                })

    if extracted_data:
        return extracted_data
    else:
        return None

def extract_body_part(task):
    data_content = []
    if hasattr(task, 'data') and task.data:
        data = task.data
            
        # get commit information
        if 'commit' in data and data['commit']:
            commit = data['commit']

            # commit title
            if 'commit_message' in commit and commit['commit_message']:
                data_content.append(" ".join(commit['commit_message']))
            # commit description
            if 'description' in commit and commit['description']:
                data_content.append(" ".join(commit['description']))
            # changed file in commit
            if 'changed_files' in commit and commit['changed_files']:
                data_content.append(" ".join(commit['changed_files']))

            # pull requests 
            if 'pull_requests' in data and data['pull_requests']:
                for pr in data['pull_requests']:
                    if 'pr_title' in pr and pr['pr_title']:
                        data_content.append(" ".join(pr['pr_title']))
                    
                    # Process discussions (excluding author)
                    if 'discussions' in pr and pr['discussions']:
                        for disc in pr['discussions']:
                            if 'comments' in disc and disc['comments']:
                                for comment in disc['comments']:
                                    data_content.append(" ".join(comment['content']))

            # get issues information
            if 'issues' in data and data['issues'] is not None:
                for issue in data['issues']:
                    if 'title' in issue and issue['title'] is not None:
                        data_content.append("Issue title:" + " ".join(issue['title']))
                    if 'comments' in issue and issue['comments'] is not None:
                        for comment in issue['comments']:
                            if 'content' in comment and comment['content'] is not None:
                                data_content.append(" ".join(comment['content']))

            # get security information
            if 'security' in data and data['security'] is not None:
                for security in data['security']:
                    if 'title' in security and security['title'] is not None:
                        data_content.append(" ".join(security['title']))
                    if 'content' in security and security['content'] is not None:
                        data_content.append(" ".join(security['content']))
    
    return data_content
