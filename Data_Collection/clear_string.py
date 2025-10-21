from nltk.tokenize import sent_tokenize, word_tokenize
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer as wnl

import string
import unicodedata

global stopWords
stopWords = set()

def createStopWord():
    global stopWords
    stopWords = set(stopwords.words('english'))
    stopWords.update(["thanks", "thank","lgtm","``","''"])

def string_emoji_or_symbol(strA):
    if len(strA) > 1:
        return False
    elif not unicodedata.category(strA).startswith(('So', 'Sm', 'Sk', 'Sc')):
        return False
    return True

def is_english_word(word): 
	 return all(ord(char) < 128 for char in word)

def clearing_string(strA):
    tokens = word_tokenize(strA)
    if bool(stopWords) == False:
        createStopWord()

    # lowercase 
    tokens = [token.lower() for token in tokens]
    
    # remove punctuation
    tokens = [word for word in tokens if word not in string.punctuation]

    # remove non-english word
    tokens = [word for word in tokens if is_english_word(word)]

    # remove stop word
    wordsFiltered = [w for w in tokens if w not in stopWords]

    # filter unnecessary symbol 
    wordsFiltered = [w for w in wordsFiltered if not string_emoji_or_symbol(w)]

    # lemmatize
    LemmatizeWord =  [wnl().lemmatize(word) for word in wordsFiltered]

    
    return LemmatizeWord
