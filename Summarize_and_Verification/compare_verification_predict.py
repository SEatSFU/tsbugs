from label_studio_sdk import LabelStudio ,Client
import sys
import json
from collections import defaultdict
import pandas as pd
import os


def read_json_index(filename="verification_set.json"):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
        
        manual_result = []
        
        for key, value in data['index'].items():
            manual_result.append([key,value])

        return manual_result
            
    except FileNotFoundError:
        print(f"File {filename} not found!")
    except json.JSONDecodeError:
        print(f"Invalid JSON in file {filename}")

    return None


def create_prediction_excels(correct_predicts, false_predicts, correct_file='correct_predictions.xlsx', false_file='false_predictions.xlsx'):

    correct_predicts_sorted = sorted(correct_predicts, key=lambda x: x[1])
    false_predicts_sorted = sorted(false_predicts, key=lambda x: x[1])
    
    correct_data = {
        'index': [item[0] for item in correct_predicts_sorted],
        'category': [item[1] for item in correct_predicts_sorted]
    }
    df_correct = pd.DataFrame(correct_data)
    
    false_data = {
        'index': [item[0] for item in false_predicts_sorted],
        'category': [item[1] for item in false_predicts_sorted],
        'predict result': [item[2] for item in false_predicts_sorted]
    }
    df_false = pd.DataFrame(false_data)
    
    df_correct.to_excel(correct_file, index=False)
    df_false.to_excel(false_file, index=False)
    
    print(f"Created {correct_file} with {len(correct_predicts_sorted)} correct predictions")
    print(f"Created {false_file} with {len(false_predicts_sorted)} false predictions")
    
    return df_correct, df_false

def compare_result(manual_result, predict_fileName):
    with open(predict_fileName, 'r') as file:
            data = json.load(file)

    correct_predicts = []
    false_predicts = []
    for category_name, category_data in data['categories'].items():
        index_array = category_data['indices']
        for index in index_array:
            for item in manual_result:
                if item[0] == index:
                    if item[1] == category_name:
                        correct_predicts.append([item[0], category_name])
                    else:
                        false_predicts.append([item[0],item[1],category_name])
                    break
    
    create_prediction_excels(correct_predicts,false_predicts)




if __name__ == "__main__":
    if len(sys.argv) == 3:
        verification_fileName = sys.argv[1]
        predict_fileName = sys.argv[2]
    else:
        verification_fileName = "verification_set.json"
        predict_fileName = "predict_label_collection.json"

    manual_result = read_json_index(verification_fileName)
    if manual_result:
        compare_result(manual_result, predict_fileName)
    else:
        print("Error happen ")