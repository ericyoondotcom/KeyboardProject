import pandas as pd
from bs4 import BeautifulSoup
import json
import emoji

data = pd.read_csv("emoji_raw.csv", keep_default_na=False)


def transform_row(row):
    soup = BeautifulSoup(row["description"], "html.parser")
    row["cleaned_description"] = soup.get_text()
    all_names = [
        row["title"],
        row["currentCldrName"],
        row["appleName"],
        *json.loads(row["alsoKnownAs"] or "[]"),
    ]
    row["all_names"] = json.dumps(all_names)
    all_codes = {d["source"]: d["code"] for d in json.loads(row["shortcodes"] or "[]")}
    row["all_codes"] = json.dumps(all_codes)
    del row["title"]
    del row["currentCldrName"]
    del row["appleName"]
    del row["alsoKnownAs"]
    del row["shortcodes"]
    return row


data = data.apply(transform_row, axis=1)

for code in emoji.EMOJI_DATA.keys():
    if code not in data["code"].values:
        all_codes = [
            emoji.EMOJI_DATA[code]["en"],
            *emoji.EMOJI_DATA[code].get("alias", []),
        ]
        data.loc[len(data)] = {
            "code": code,
            "cleaned_description": "; ".join(
                [k.replace(":", "").replace("_", " ") for k in all_codes]
            ),
            "all_codes": json.dumps({
                "cldr": emoji.EMOJI_DATA[code]["en"],
                **{
                    k: v
                    for k, v in enumerate(emoji.EMOJI_DATA[code].get("alias", []))
                },
            }),
        }

data.to_csv("emoji_transformed.csv", index=False)
