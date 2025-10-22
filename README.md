# TSBugsArtifact

## Table of Contents
1. [Dependecies Instal](#dependecies-install )
2. [Project Structure](#project-structure)
3. [Key Scripts Usage ](#key-scripts-usage )
4. [Key Json files and configuration](#key-json-files-and-configuration)


## Dependecies Install 
```bash
pip install requests nltk beautifulsoup4 label-studio-sdk setfit pandas
```

## Project Structure
```bash
TSBugsArtifact/
├── raw_data                           # All raw data we collect
├── Data_Collection                    # Collect bug-fix relative commit and extract the commit URLs from given repository
├── Model_Train_Predict_Setfit         # Training model on label data and use it to predict labels for untrain commit
└── Summarize_and_Verification         # Produce summarization and verification report for model predicted label result        

```

## Key Scripts Usage 

### Data_Collection 

**Script:** `github_commits_collector` <br>
**Description:** extract commits relative to bug fix from given GitHub repository and create a json file under **current directory** to store them

```bash
python github_commits_collector.py <GITHUB_REPOSITORY_URL> [<Collect_Commit_Number>] [<YOUR_GITHUB_TOKEN>]
```
<br>

**Script:** `index.py` <br>
**Description:** collect key information from commit/commits that you given and store them into `/TSBugsArtifact/raw_data/output` (If not have the folder, then script will generate)

For single commit:
```bash
python index.py <GITHUB_COMMIT_URL> [<YOUR_GITHUB_TOKEN>]
```

For multiple commits:

```bash
python index.py <JSON_FILE>
```

**Json File Format**

Reference to `collect_commit_template.json`
```Json
{
    "token": "YOUR_GITHUB_TOKEN" OR null,
    "urls": [
      "GITHUB_COMMIT_URL",
      .........
    ]
}
```
<br>

### Model_Train_Predict_Setfit


**Script:** `index.py` <br>
**Prerequisite:** You should have labe studio person access token and a project with a few label sample <br>
**Description:** fine-tun the model with label simples in your label studio project and upload the predict label for un-label simples into same project

```bash
python index.py <YOUR_LabelStudio_Access_Token> <PROJECT_ID> 
```
<br>

### Summarize_and_Verification

**Script:** `label_studio_extractor.py` <br>
**Prerequisite:** You should have labe studio person access token and a project with a few predict sample <br>
**Description:** get predict/manually label result summarization for then given project

```bash
python label_studio_extractor.py <YOUR_LabelStudio_Access_Token> <PROJECT_ID> [<Is_Manual_Label_Summarize>]
```
<br>

**Script:** `compare_verification_predict.py` <br>
**Prerequisite:** You should have a json file that store the summarize of predict label (run `prediction_extractor.py`) <br>
**Description:** Generate two Excel files: one containing samples the model labeled correctly and another containing samples it mislabeled, based on comparsion between the model’s predicted labels and verification set

```bash
python compare_verification_predict.py [<Verification_Set>] [<Predict_Label_Result>]
```
<br>

**Script:** `predict_summarize_repository.py` <br>
**Prerequisite:** You should have a json file that store the summarize of predict label (run `prediction_extractor.py`) <br>
**Description:** Base on the model’s predicted label result, print out number of commits belong the repository under each bug category  

```bash
python predict_summarize_repository.py [<Predict_Label_Result>] [<GitHub_Repository_Lists>]
```

## Key Json Files and Configuration

### Key Json Files

**Json Files Path:** /TSBugsArtifact/Summarize_and_Verification   <br>

**Name:** `github_repository_name.json` <br>
**Description:** List of all repository name (Should match with repository's URL)

**Name:** `manually_label_collection.json` <br>
**Description:** Training set label result

**Name:** `verification_set.json` <br>
**Description:** Verification set label result


### Key Configuration

**Labeling Interface of Label Studio Project:**
```HTML
<View>
  <Text name="text" value="$commit_index"/>
  <View style="box-shadow: 2px 2px 5px #999;                padding: 20px; margin-top: 2em;                border-radius: 5px;">
    <Header value="Choose bug category"/>
    <Choices name="sentiment" toName="text" choice="single" showInLine="true">
      <Choice value="Test Fault"/>
      <Choice value="Asynchrony / Event Handling Bug"/>
      <Choice value="Tooling / Configuration Issue"/>
      <Choice value="Missing Cases"/>
      <Choice value="Exception Handling"/>
      <Choice value="Missing Features"/>
      <Choice value="Type Error"/>
      <Choice value="UI Behavior Bug"/>
      <Choice value="API Misuse"/>
      <Choice value="Logic Error"/>
      <Choice value="Runtime Exception"/></Choices>
  </View>
</View>
```


