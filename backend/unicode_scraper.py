import requests
import emoji
import pandas as pd
import json
from urllib.parse import urlencode, quote_plus
import signal
import sys
from pathlib import Path
from tqdm import tqdm

# Get all emojis
all_emojis = emoji.EMOJI_DATA.keys()

if Path("emojipedia_data.csv").is_file():
    data = pd.read_csv("emojipedia_data.csv")
    existing = data["code"].values
else:
    data = pd.DataFrame()
    existing = []


# Listen for Ctrl+C and save
def signal_handler(sig, frame):
    data.to_csv("emojipedia_data.csv", index=False)
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)

for emj in tqdm(all_emojis):
    if emj in existing:
        continue

    url = "https://emojipedia.org/_next/data/RtZJ6YpCnD_sMD32txwi4/en/search.json"
    payload = {"q": emj}

    try:
        params = urlencode(payload, quote_via=quote_plus)
        response = requests.get(url, params)
        redirect = json.loads(response.text)["pageProps"]["__N_REDIRECT"]

        emoji_page = f"https://emojipedia.org/_next/data/RtZJ6YpCnD_sMD32txwi4/en/{redirect}.json?emoji={redirect}"
        response = requests.get(emoji_page)
        payload = json.loads(response.text)["pageProps"]["dehydratedState"]["queries"][
            3
        ]["state"]["data"]
        payload = {
            k: v
            for k, v in payload.items()
            if k
            in [
                "id",
                "title",
                "code",
                "slug",
                "currentCldrName",
                "codepointsHex",
                "description",
                "appleName",
                "alsoKnownAs",
                "shortcodes",
            ]
        }
        # Add missing fields to the data
        data = data.reindex(
            data.columns.union(payload.keys(), sort=False), axis=1, fill_value=0
        )
        for key in payload.keys():
            if isinstance(payload[key], dict) or isinstance(payload[key], list):
                payload[key] = json.dumps(payload[key])
        data.loc[len(data)] = payload
    except Exception as e:
        tqdm.write(f"failed to get description for {emj} {str(e)}")

data.to_csv("emojipedia_data.csv", index=False)
