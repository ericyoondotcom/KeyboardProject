import requests
import emoji
import csv
import unicodedata
from bs4 import BeautifulSoup
import json
from urllib.parse import urlencode, quote_plus

# Get all emojis
all_emojis = emoji.EMOJI_DATA.keys()

DATA = {}
with open('emoji.csv', 'r') as file:
    reader = csv.reader(file)
    for row in reader:
        DATA[row[0]] = row[1]

with open('emoji.csv', 'a') as file:
    for emj in all_emojis:
        if emj in DATA:
            continue

        url = 'https://emojipedia.org/_next/data/RtZJ6YpCnD_sMD32txwi4/en/search.json'
        payload = {'q': emj}

        try:
            params = urlencode(payload, quote_via=quote_plus)
            # Send POST request with payload
            response = requests.get(url, params)

            data = json.loads(response.text)
            redirect = data['pageProps']['__N_REDIRECT']

            emoji_page = f'https://emojipedia.org{redirect}'
            response = requests.get(emoji_page)
            soup = BeautifulSoup(response.content, "html.parser")
            div = soup.find("div", class_='HtmlContent_html-content-container__Ow2Bk')
            file.write(f'{emj},"{div.find('p').get_text(strip=True).replace('\u00A0', ' ')}"\n')
        except Exception as e:
            print('failed to get description for', emj, e)

print("Done!")

