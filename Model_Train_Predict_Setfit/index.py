from label_studio_sdk import LabelStudio, Client
import sys
from setfit import SetFitModel, Trainer, TrainingArguments

from dataset_generator import extract_data_for_training, extract_data_for_prediction 

def export_from_label_studio(ls,project_id,url="http://localhost:8080"):
    tasks = []
    for task in ls.tasks.list(project=project_id):
        tasks.append(task)
    return tasks
        


def train_model(model_name, dataset, simple_train=True):
    
    model = SetFitModel.from_pretrained(model_name)
    
    texts = dataset['text']
    labels = dataset['label']

    if simple_train:
        args = TrainingArguments(
        batch_size=(8, 2),
        num_epochs=(1, 10),
        num_iterations=10,
        warmup_proportion=0.1
        )
    else:
        args = TrainingArguments(
            batch_size=(8, 16),                    
            num_epochs=(2, 10),                    
            num_iterations=20,                     
            warmup_proportion=0.2,                 
            max_steps=-1,                          
            sampling_strategy="oversampling",      
            body_learning_rate=5e-6,               
            head_learning_rate=5e-4,              
            l2_weight=0.1,                        
            end_to_end=True,                       
            show_progress_bar=True,
        )
    
    # Train the model
    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=dataset 
    )

    trainer.train()
    
    return model

def predict_update_task(ls, project_id, tasks ,model):

    prediction_data = extract_data_for_prediction(tasks)

    if prediction_data is None:
        print("No valid tasks found for prediction")
        return

    texts = [item['text'] for item in prediction_data]
    
    predictions = model.predict(texts)
    probabilities = model.predict_proba(texts)  

    class_labels = model.labels 

    predictions_created = 0
    
    confidence_text = []
    
    for item, prediction, proba in zip(prediction_data, predictions,probabilities):
        task_id = item['id']
        
        max_confidence = float(proba.max())

        # Create prediction result in Label Studio format
        result = [{
            "value": {
                 "choices": [prediction]
                 },
            "from_name": "sentiment",  
            "to_name": "text", 
            "type": "choices", 
            "score": max_confidence
        }]

        class_probs = {label: float(prob) for label, prob in zip(class_labels, proba)}

        confidence_text.append([task_id,prediction, proba.max().round(decimals=3),class_probs])

        try:
            # Create a prediction for this task
            ls.predictions.create(
                task=task_id,
                result=result,
                model_version="setfit-text-classification-v1",
                score= max_confidence
            )
            predictions_created += 1

            
        except Exception as e:
            print(f"Error creating prediction for task {task_id}: {e}")
    
    print(f"\nSuccessfully created {predictions_created} predictions")
    return confidence_text

def main():
    model_name = ""
    if len(sys.argv) != 3 and len(sys.argv) != 4:
        print("Not correctly input key")
        sys.exit(1)
    elif len(sys.argv) == 4:
        model_name = sys.argv[3]
    
    key = sys.argv[1]
    project_id = sys.argv[2]

    try:
        ls = LabelStudio(base_url="http://localhost:8080", api_key=key)
    except Exception as e:
        print(f"Failed to load label Studio: {e}")
        sys.exit(1)

    label_data = export_from_label_studio(ls,project_id)

    if not label_data:
        print("Empty label data, exit")
        sys.exit(1)
    
    dataset = extract_data_for_training(label_data)
    
    if dataset is None: 
        print("Empty dataset, exit")
        sys.exit(1)

    if model_name == "":
        model = train_model(model_name="TaylorAI/bge-micro-v2", dataset=dataset)
        model.save_pretrained("text_classification_model")
    else:
        try:
            model = SetFitModel.from_pretrained(model_name)
        except Exception as e:
            print(f"Failed to load model: {e}")
            sys.exit(1)
    
    confidence_content = predict_update_task(ls, 3, label_data, model)
    with open('prediction_condifence.txt', 'w', encoding='utf-8') as f:
        for data in confidence_content:
            f.write(f"Task {data[0]} \n")
            f.write(f"Predicted: {data[1]} (confidence: {data[2]}) \n")
            f.write(f"All probabilities: {data[3]} \n")
            f.write("\n \n")

    print("condifence of prediction sample is been store")
            

if __name__ == "__main__":
    main()
