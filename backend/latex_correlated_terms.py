import os
from dotenv import load_dotenv
from openai import OpenAI
import json

load_dotenv()

# Load JSON data from a file into a Python dictionary
with open('./latex_unicode.json', 'r') as file:
    data = json.load(file)

# Create a client instance to interact with the OpenAI API
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

PROMPT = """I will give you a single LaTeX macro. List all uses of the associated symbol, as it would be used in STEM contexts. Give three to five examples, delineated by commas, and ordered in decreasing usage. Do not include spaces after the commas (CSV style). Do not output anything else.

Example:
I say: \theta
You say: angle,runtime exact bound,true parameter,radian

Are you ready? I will give my first input in the next message.
"""

for symbol in data.keys():
    chat_completion = client.chat.completions.create(
        messages=[
            {"role": "system", "content": PROMPT},
            {"role": "user", "content": symbol},
        ],
        model="gpt-3.5-turbo"
    )

    response_text = chat_completion.choices[0].message.content
    print(f"{symbol},{response_text}")
