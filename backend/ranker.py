from sentence_transformers import SentenceTransformer, util
import pandas as pd
import sys

data = pd.read_csv("emoji_transformed.csv", keep_default_na=False)

texts = list(data["cleaned_description"].values)

model = SentenceTransformer("paraphrase-MiniLM-L6-v2")

text_embeddings = model.encode(texts, convert_to_tensor=True)

print("Model ready")

for input_text in sys.stdin:
    input_embedding = model.encode(input_text, convert_to_tensor=True)
    similarities = util.pytorch_cos_sim(input_embedding, text_embeddings).flatten()
    sorted_indices = similarities.argsort(descending=True)[:5]
    sorted_texts = [data.iloc[i] for i in sorted_indices.cpu().data.numpy()]
    for i, row in enumerate(sorted_texts):
        print(
            f"{i+1}. {row["code"]} ({row["all_names"]}) (Similarity: {similarities[sorted_indices[i]]:.4f})"
        )
