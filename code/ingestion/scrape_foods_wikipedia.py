#!/usr/bin/env python3
"""
HNAG food catalog ingestion — REAL data only, from Wikidata + Wikipedia + Wikimedia.

Discovery via Wikidata SPARQL: items that are food (P31/P279* food) with
country of origin = Vietnam (P495 = Q881), OR cuisine = Vietnamese cuisine
(P2012 = Q1854639), that have a real photo (P18). Vietnamese names from
Wikidata labels; richer Vietnamese descriptions from vi.wikipedia; photos are
real, freely-licensed Wikimedia Commons images. No LLM, nothing fabricated.

  python scrape_foods_wikipedia.py --out out/foods_wiki.sql
  ssh ServerLinux "docker exec -i hnag-postgres psql -U hnag -d hnag" < out/foods_wiki.sql

Upserts ON CONFLICT (slug) DO NOTHING (keeps the curated seed dishes).
Images © their Wikimedia Commons authors under CC/free licenses.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from typing import Any

UA = "HNAGBot/1.0 (food catalog; +https://tothanhthuy.cloud/bot)"
SPARQL = "https://query.wikidata.org/sparql"
WIKI_VI = "https://vi.wikipedia.org/w/api.php"

VALID_CATEGORY = {"noodle", "rice", "soup", "snack", "dessert", "drink",
                  "grill", "street", "fastfood", "seafood", "vegetarian"}

# Vietnamese foods with a photo: country of origin Vietnam (and is a food), or
# explicitly tagged as Vietnamese cuisine.
QUERY = """
SELECT DISTINCT ?item ?vi ?en ?img ?viDesc WHERE {
  ?item wdt:P18 ?img.
  { ?item wdt:P495 wd:Q881. ?item wdt:P31/wdt:P279* wd:Q2095. }
  UNION
  { ?item wdt:P2012 wd:Q1854639. }
  OPTIONAL { ?item rdfs:label ?vi.   FILTER(LANG(?vi)="vi") }
  OPTIONAL { ?item rdfs:label ?en.   FILTER(LANG(?en)="en") }
  OPTIONAL { ?item schema:description ?viDesc. FILTER(LANG(?viDesc)="vi") }
}
LIMIT 1500
"""

SKIP_RE = re.compile(r"\b(sauce|fish sauce|paste|cuisine|ingredient)\b", re.I)


def http_json(url: str, headers: dict[str, str]) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={**headers, "User-Agent": UA})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            if attempt == 2:
                print(f"  ! error: {e}", file=sys.stderr)
                return {}
            time.sleep(4)
    return {}


def strip_diacritics(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()


def slugify(name: str) -> str:
    s = strip_diacritics(name).lower()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    return re.sub(r"[\s-]+", "-", s).strip("-")[:90] or "mon"


def cat_for(name: str, desc: str) -> str:
    s = (name + " " + (desc or "")).lower()
    if re.search(r"noodle|phở|pho |bún|bun |mì|hủ tiếu|miến|bánh canh|bánh phở", s): return "noodle"
    if re.search(r"soup|canh|cháo|porridge|congee", s): return "soup"
    if re.search(r"rice|cơm|xôi|risotto", s): return "rice"
    if re.search(r"dessert|sweet|chè|pudding|cake|bánh ngọt|kem|ice cream|sâm|thạch", s): return "dessert"
    if re.search(r"beverage|drink|coffee|cà phê|tea|trà|juice|sữa|beer|bia|nước", s): return "drink"
    if re.search(r"seafood|fish|hải sản|ốc|crab|shrimp|mực|cá ", s): return "seafood"
    if re.search(r"grill|nướng|bbq|sausage|chả|nem nướng|barbecue", s): return "grill"
    if re.search(r"vegetarian|chay|salad|gỏi|nộm", s): return "vegetarian"
    return "street"


def meal_types_for(cat: str) -> list[str]:
    return {
        "noodle": ["breakfast", "lunch"], "soup": ["lunch", "dinner"],
        "rice": ["lunch", "dinner"], "grill": ["dinner"], "seafood": ["dinner"],
        "dessert": ["snack"], "drink": ["snack"], "snack": ["snack", "lunch"],
        "street": ["lunch", "snack"], "vegetarian": ["lunch", "dinner"],
    }.get(cat, ["lunch", "dinner"])


def region_from(text: str) -> str:
    t = (text or "").lower()
    if re.search(r"huế|hue|central vietnam|đà nẵng|hội an|quảng nam", t): return "trung"
    if re.search(r"hà nội|hanoi|northern vietnam|miền bắc|bắc bộ", t): return "bac"
    if re.search(r"sài gòn|saigon|hồ chí minh|southern|miền nam|mekong|nam bộ", t): return "nam"
    return "other"


def fetch_vi_extracts(titles: list[str]) -> dict[str, str]:
    """Richer Vietnamese descriptions from vi.wikipedia (2 sentences)."""
    out: dict[str, str] = {}
    for i in range(0, len(titles), 20):
        chunk = titles[i:i + 20]
        params = {
            "action": "query", "format": "json", "formatversion": "2", "redirects": 1,
            "titles": "|".join(chunk), "prop": "extracts",
            "exintro": 1, "explaintext": 1, "exsentences": 2,
        }
        data = http_json(WIKI_VI + "?" + urllib.parse.urlencode(params), {})
        for p in data.get("query", {}).get("pages", []):
            ex = (p.get("extract") or "").strip()
            if ex:
                out[p.get("title")] = ex
        time.sleep(0.3)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Scrape REAL Vietnamese dishes from Wikidata/Wikipedia.")
    ap.add_argument("--out", default="out/foods_wiki.sql")
    args = ap.parse_args()

    print("Querying Wikidata for real Vietnamese dishes with photos...", file=sys.stderr)
    url = SPARQL + "?" + urllib.parse.urlencode({"query": QUERY, "format": "json"})
    data = http_json(url, {"Accept": "application/sparql-results+json"})
    bindings = data.get("results", {}).get("bindings", [])
    print(f"  {len(bindings)} rows from Wikidata", file=sys.stderr)

    items: dict[str, dict[str, Any]] = {}
    for b in bindings:
        qid = b["item"]["value"].rsplit("/", 1)[-1]
        name_vi = b.get("vi", {}).get("value")
        name_en = b.get("en", {}).get("value")
        name = (name_vi or name_en or "").strip()
        if not name or SKIP_RE.search(name):
            continue
        img = b["img"]["value"]
        if "?" not in img:
            img += "?width=900"
        rec = items.setdefault(qid, {
            "name_vi": (name_vi or name_en).strip(),
            "name_en": (name_en or name_vi).strip(),
            "image": img,
            "desc": (b.get("viDesc", {}) or {}).get("value"),
        })

    # richer vi.wikipedia descriptions where the dish has a Vietnamese title
    vi_titles = [r["name_vi"] for r in items.values()
                 if r["name_vi"] and strip_diacritics(r["name_vi"]) != r["name_vi"]]
    print(f"Fetching vi.wikipedia descriptions for {len(vi_titles)} dishes...", file=sys.stderr)
    extracts = fetch_vi_extracts(vi_titles) if vi_titles else {}

    records: list[dict[str, Any]] = []
    seen: set[str] = set()
    for r in items.values():
        slug = slugify(r["name_vi"])
        if slug in seen:
            continue
        seen.add(slug)
        desc = extracts.get(r["name_vi"]) or r["desc"]
        if desc:
            desc = desc[:500]
        cat = cat_for(r["name_vi"] + " " + r["name_en"], desc or "")
        cat = cat if cat in VALID_CATEGORY else "street"
        records.append({
            "name_vi": r["name_vi"][:160], "name_en": r["name_en"][:160], "slug": slug,
            "description": desc, "primary_image": r["image"],
            "category": cat, "origin_region": region_from((desc or "") + " " + r["name_vi"]),
            "meal_types": meal_types_for(cat),
        })

    print(f"\n{len(records)} REAL dishes with REAL photos ready", file=sys.stderr)
    if not records:
        sys.exit("nothing to write")

    import os
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)

    def q(v: str | None) -> str:
        return "NULL" if v is None else "'" + v.replace("'", "''") + "'"

    def meal_arr(items_: list[str]) -> str:
        return "ARRAY[" + ",".join("'" + x + "'" for x in items_) + "]::meal_type[]"

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- HNAG foods — REAL data from Wikidata/Wikipedia; photos © Wikimedia Commons (CC/free)\n")
        f.write(f"-- {len(records)} dishes. Upsert ON CONFLICT (slug) DO NOTHING (keeps curated seed).\n")
        f.write("SET client_encoding='UTF8';\nBEGIN;\n")
        cols = ("name_vi, name_en, slug, description, primary_image, cuisine, "
                "category, origin_region, meal_types, status, created_at, updated_at")
        for i in range(0, len(records), 200):
            f.write(f"\nINSERT INTO foods ({cols}) VALUES\n")
            rows = [
                f"({q(r['name_vi'])},{q(r['name_en'])},{q(r['slug'])},{q(r['description'])},"
                f"{q(r['primary_image'])},'vietnamese',{q(r['category'])}::food_category,"
                f"{q(r['origin_region'])}::origin_region,{meal_arr(r['meal_types'])},"
                f"'active',NOW(),NOW())"
                for r in records[i:i + 200]
            ]
            f.write(",\n".join(rows))
            f.write("\nON CONFLICT (slug) DO NOTHING;\n")
        f.write("\nCOMMIT;\n")
    print(f"Wrote {len(records)} dishes -> {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
