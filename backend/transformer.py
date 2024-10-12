import pandas as pd
from bs4 import BeautifulSoup
import json

data = pd.read_csv("emoji.csv", keep_default_na=False)

def transform_row(row):
    soup = BeautifulSoup(row["description"], "html.parser")
    row["cleaned_description"] = soup.get_text()
    all_names = [row["title"], row["currentCldrName"], row["appleName"], *json.loads(row["alsoKnownAs"] or "[]")]
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
data.to_csv("emoji_transformed.csv", index=False)
