import requests
from bs4 import BeautifulSoup
from pandas import DataFrame

URL = 'https://help.keyman.com/keyboard/sil_ipa/1.8.7/sil_ipa'
page = requests.get(URL)

soup = BeautifulSoup(page.content, "html.parser")
title = soup.find('h1')
table = title.find_next('table')

glyphs = []
keystrokes = []
descs = []
for tr in table.find_all('tr')[1:]:
    tds = tr.find_all('td')
    glyphs.append(tds[1].find_next('span').text)
    keystrokes.append(tds[2].find_next('span').text)
    descs.append(tds[-1].find_next('span').text.replace('\n', ''))

data = DataFrame({
    'glyph': glyphs,
    'keystroke': keystrokes,
    'description': descs
})

data.to_csv('phonetics.csv', index=False)