#!/usr/bin/env python3
"""Rebuild the bundled CC BY-SA 4.0 dictionary from current EDRDG source files.

Download JMdict_e.gz and kanjidic2.xml.gz from https://www.edrdg.org/pub/Nihongo/
into .cache first. Run this script for each release to refresh the dictionary.
Only Japanese readings and English glosses are included; identifiers and reading
restrictions are preserved. The resulting dictionary data remains CC BY-SA 4.0.
"""
import datetime
import gzip
import json
from pathlib import Path
import sqlite3
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "Sources/YomuCore/Resources/Dictionary.sqlite"
TEMP = DEST.with_suffix(".building")
if TEMP.exists():
    TEMP.unlink()
db = sqlite3.connect(TEMP)
db.executescript("""
CREATE TABLE entries(id INTEGER PRIMARY KEY, source_id TEXT, word TEXT NOT NULL, reading TEXT NOT NULL,
 meanings TEXT NOT NULL, pos TEXT NOT NULL, common INTEGER NOT NULL);
CREATE TABLE forms(form TEXT NOT NULL, entry_id INTEGER NOT NULL);
CREATE TABLE kanji(character TEXT PRIMARY KEY, onyomi TEXT, kunyomi TEXT, meanings TEXT);
CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT);
""")
identifier = 0
with gzip.open(ROOT / ".cache/JMdict_e.gz", "rb") as source:
    for event, element in ET.iterparse(source, events=("end",)):
        if element.tag != "entry":
            continue
        writings = [k.findtext("keb") for k in element.findall("k_ele")]
        for reading_element in element.findall("r_ele"):
            reading = reading_element.findtext("reb")
            restricted = [r.text for r in reading_element.findall("re_restr")]
            words = restricted or writings or [reading]
            if reading_element.find("re_nokanji") is not None:
                words = [reading]
            for word in words:
                meanings = []
                parts = []
                for sense in element.findall("sense"):
                    stagk = [x.text for x in sense.findall("stagk")]
                    stagr = [x.text for x in sense.findall("stagr")]
                    if (stagk and word not in stagk) or (stagr and reading not in stagr):
                        continue
                    for gloss in sense.findall("gloss"):
                        if gloss.attrib.get("{http://www.w3.org/XML/1998/namespace}lang", "eng") == "eng" and gloss.text:
                            meanings.append(gloss.text)
                    parts.extend(x.text for x in sense.findall("pos") if x.text)
                if not meanings:
                    continue
                common = bool(reading_element.findall("re_pri")) or any(
                    k.findtext("keb") == word and k.findall("ke_pri") for k in element.findall("k_ele"))
                identifier += 1
                db.execute("INSERT INTO entries VALUES(?,?,?,?,?,?,?)", (
                    identifier, element.findtext("ent_seq"), word, reading,
                    json.dumps(list(dict.fromkeys(meanings)), ensure_ascii=False),
                    "; ".join(dict.fromkeys(parts)), int(common)))
                for form in set([word, reading]):
                    db.execute("INSERT INTO forms VALUES(?,?)", (form, identifier))
        element.clear()
with gzip.open(ROOT / ".cache/kanjidic2.xml.gz", "rb") as source:
    for event, element in ET.iterparse(source, events=("end",)):
        if element.tag != "character":
            continue
        readings = element.findall("reading_meaning/rmgroup/reading")
        on = [x.text for x in readings if x.attrib.get("r_type") == "ja_on"]
        kun = [x.text for x in readings if x.attrib.get("r_type") == "ja_kun"]
        meanings = [x.text for x in element.findall("reading_meaning/rmgroup/meaning") if "m_lang" not in x.attrib]
        db.execute("INSERT INTO kanji VALUES(?,?,?,?)", (element.findtext("literal"), *[
            json.dumps(x, ensure_ascii=False) for x in [on, kun, meanings]]))
        element.clear()
db.executescript("CREATE INDEX forms_lookup ON forms(form); CREATE INDEX entries_common ON entries(common);")
db.execute("INSERT INTO metadata VALUES('built', ?)", (datetime.date.today().isoformat(),))
db.execute("INSERT INTO metadata VALUES('license', 'CC BY-SA 4.0')")
db.commit()
counts = [db.execute(f"SELECT count(*) FROM {table}").fetchone()[0] for table in ["entries", "kanji"]]
db.execute("VACUUM")
db.close()
TEMP.replace(DEST)
print(f"Built {DEST}: {counts[0]:,} word/reading pairs, {counts[1]:,} kanji; {DEST.stat().st_size / 1024**2:.1f} MB")
