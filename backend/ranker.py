from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import pandas as pd

data = pd.read_csv("emoji_transformed.csv", keep_default_na=False)

input_text = "crying"

vectorizer = TfidfVectorizer()
vectors = vectorizer.fit_transform(list(data["cleaned_description"].values) + [input_text]) 

input_vector = vectors[-1]
similarities = cosine_similarity(input_vector, vectors[:-1]).flatten()

sorted_indices = np.argsort(similarities)[::-1]
sorted_texts = [data.iloc[i] for i in sorted_indices]

for i, row in enumerate(sorted_texts):
    if similarities[sorted_indices[i]] == 0 or i > 5:
        break
    print(f"{i+1}. {row["code"]} ({row["all_names"]}) (Similarity: {similarities[sorted_indices[i]]:.4f})")
