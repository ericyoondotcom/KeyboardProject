import os
from dotenv import load_dotenv
load_dotenv()

from openai import OpenAI

# Create a client instance to interact with the OpenAI API
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

chat_completion = client.chat.completions.create(
    messages=[
        {"role": "user", "content": "Hello, World!"}
    ],
    model="gpt-3.5-turbo"
)

response_text = chat_completion.choices[0].message.content

print(f"Assistant: {response_text}")