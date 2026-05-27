#!/usr/bin/env python3
"""
HNAG restaurant ingestion — standalone (no Airflow).

Fetch restaurants/cafes for Vietnamese cities and emit SQL that upserts into the
`restaurants` table (matches code/sql/01_schema.sql). Two sources:

  - osm         OpenStreetMap via Overpass API. FREE, no API key, ODbL license.
                (default — works out of the box)
  - foursquare  Foursquare Places API v3. Needs FSQ_API_KEY env var.

The script only FETCHES + writes a .sql file (pure stdlib, no pip install needed).
Apply the SQL wherever the DB lives. For the HNAG self-host server:

    python scrape_restaurants.py --city hcm,hanoi --out out/restaurants_osm.sql
    ssh ServerLinux "docker exec -i hnag-postgres psql -U hnag -d hnag" < out/restaurants_osm.sql

Or insert directly (needs `pip install psycopg2-binary` + a reachable DB):

    python scrape_restaurants.py --city hcm --direct \
        --db-url postgresql://hnag:hnag@localhost:5432/hnag

Rollback (auto-ingested rows are identifiable by their slug suffix `-n123/-w123/-r123`
for OSM, or `-<8charid>` for Foursquare; they are also is_verified = FALSE):

    DELETE FROM restaurants WHERE is_verified = FALSE AND slug ~ '-[nwr][0-9]+$';

Legal note: respects the data-ingestion principles in docs/11-DATA-INGESTION.md —
identifies itself via User-Agent, only fetches public facts (name/address/geo/hours),
no PII, no review text. OSM data is ODbL: attribute "© OpenStreetMap contributors".
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Iterable

USER_AGENT = "HNAGBot/1.0 (+https://tothanhthuy.cloud/bot)"
# override with env OVERPASS_URL to use a mirror (e.g. https://overpass.kumi.systems/api/interpreter)
OVERPASS_URL = os.environ.get("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
FSQ_API = "https://api.foursquare.com/v3/places/search"
FSQ_RESTAURANT_CATEGORY = "13065"  # Foursquare "Dining and Drinking > Restaurant"

# Nationwide coverage: 63 province capitals + key food/tourist cities, all 3 regions.
# center lat/lng + default search radius (meters) covering each city's populated core.
# Overlaps are harmless — rows de-dupe by OSM-id-based slug.
CITY_PRESETS: dict[str, dict[str, Any]] = {
    # ---- Miền Bắc (North) ----
    "hanoi":       {"display": "Hà Nội",        "lat": 21.0278, "lng": 105.8342, "radius": 16000},
    "haiphong":    {"display": "Hải Phòng",     "lat": 20.8449, "lng": 106.6881, "radius": 12000},
    "halong":      {"display": "Quảng Ninh",    "lat": 20.9590, "lng": 107.0428, "radius": 12000},
    "bacninh":     {"display": "Bắc Ninh",      "lat": 21.1861, "lng": 106.0763, "radius": 8000},
    "haiduong":    {"display": "Hải Dương",     "lat": 20.9373, "lng": 106.3146, "radius": 8000},
    "hungyen":     {"display": "Hưng Yên",      "lat": 20.6464, "lng": 106.0512, "radius": 8000},
    "vinhyen":     {"display": "Vĩnh Phúc",     "lat": 21.3089, "lng": 105.6049, "radius": 8000},
    "bacgiang":    {"display": "Bắc Giang",     "lat": 21.2731, "lng": 106.1946, "radius": 8000},
    "viettri":     {"display": "Phú Thọ",       "lat": 21.3227, "lng": 105.4024, "radius": 8000},
    "thainguyen":  {"display": "Thái Nguyên",   "lat": 21.5942, "lng": 105.8480, "radius": 9000},
    "langson":     {"display": "Lạng Sơn",      "lat": 21.8537, "lng": 106.7610, "radius": 7000},
    "caobang":     {"display": "Cao Bằng",      "lat": 22.6657, "lng": 106.2570, "radius": 6000},
    "backan":      {"display": "Bắc Kạn",       "lat": 22.1470, "lng": 105.8348, "radius": 6000},
    "tuyenquang":  {"display": "Tuyên Quang",   "lat": 21.8233, "lng": 105.2140, "radius": 7000},
    "hagiang":     {"display": "Hà Giang",      "lat": 22.8233, "lng": 104.9784, "radius": 7000},
    "laocai":      {"display": "Lào Cai",       "lat": 22.4809, "lng": 103.9755, "radius": 8000},
    "sapa":        {"display": "Lào Cai",       "lat": 22.3360, "lng": 103.8440, "radius": 6000},
    "yenbai":      {"display": "Yên Bái",       "lat": 21.7168, "lng": 104.8986, "radius": 7000},
    "dienbien":    {"display": "Điện Biên",     "lat": 21.3860, "lng": 103.0230, "radius": 7000},
    "laichau":     {"display": "Lai Châu",      "lat": 22.3964, "lng": 103.4590, "radius": 6000},
    "sonla":       {"display": "Sơn La",        "lat": 21.3270, "lng": 103.9140, "radius": 7000},
    "hoabinh":     {"display": "Hòa Bình",      "lat": 20.8133, "lng": 105.3383, "radius": 8000},
    "phuly":       {"display": "Hà Nam",        "lat": 20.5410, "lng": 105.9140, "radius": 7000},
    "namdinh":     {"display": "Nam Định",      "lat": 20.4388, "lng": 106.1621, "radius": 9000},
    "thaibinh":    {"display": "Thái Bình",     "lat": 20.4463, "lng": 106.3366, "radius": 8000},
    "ninhbinh":    {"display": "Ninh Bình",     "lat": 20.2506, "lng": 105.9745, "radius": 9000},
    # ---- Miền Trung + Tây Nguyên (Central + Highlands) ----
    "thanhhoa":    {"display": "Thanh Hóa",     "lat": 19.8067, "lng": 105.7852, "radius": 10000},
    "vinh":        {"display": "Nghệ An",       "lat": 18.6790, "lng": 105.6816, "radius": 10000},
    "hatinh":      {"display": "Hà Tĩnh",       "lat": 18.3559, "lng": 105.8877, "radius": 8000},
    "donghoi":     {"display": "Quảng Bình",    "lat": 17.4689, "lng": 106.6223, "radius": 8000},
    "dongha":      {"display": "Quảng Trị",     "lat": 16.8163, "lng": 107.1003, "radius": 7000},
    "hue":         {"display": "Huế",           "lat": 16.4637, "lng": 107.5909, "radius": 11000},
    "danang":      {"display": "Đà Nẵng",       "lat": 16.0544, "lng": 108.2022, "radius": 14000},
    "hoian":       {"display": "Quảng Nam",     "lat": 15.8801, "lng": 108.3380, "radius": 7000},
    "tamky":       {"display": "Quảng Nam",     "lat": 15.5736, "lng": 108.4740, "radius": 7000},
    "quangngai":   {"display": "Quảng Ngãi",    "lat": 15.1205, "lng": 108.7922, "radius": 8000},
    "quynhon":     {"display": "Bình Định",     "lat": 13.7820, "lng": 109.2190, "radius": 9000},
    "tuyhoa":      {"display": "Phú Yên",       "lat": 13.0882, "lng": 109.0929, "radius": 8000},
    "nhatrang":    {"display": "Khánh Hòa",     "lat": 12.2388, "lng": 109.1899, "radius": 11000},
    "phanrang":    {"display": "Ninh Thuận",    "lat": 11.5645, "lng": 108.9899, "radius": 8000},
    "phanthiet":   {"display": "Bình Thuận",    "lat": 10.9289, "lng": 108.1020, "radius": 9000},
    "kontum":      {"display": "Kon Tum",       "lat": 14.3497, "lng": 108.0005, "radius": 8000},
    "pleiku":      {"display": "Gia Lai",       "lat": 13.9833, "lng": 108.0000, "radius": 9000},
    "buonmathuot": {"display": "Đắk Lắk",       "lat": 12.6667, "lng": 108.0500, "radius": 11000},
    "gianghia":    {"display": "Đắk Nông",      "lat": 12.0044, "lng": 107.6900, "radius": 7000},
    "dalat":       {"display": "Lâm Đồng",      "lat": 11.9404, "lng": 108.4583, "radius": 10000},
    # ---- Miền Nam (South: Đông Nam Bộ + Tây Nam Bộ) ----
    "hcm":         {"display": "TP.HCM",        "lat": 10.7769, "lng": 106.7009, "radius": 18000},
    "thudaumot":   {"display": "Bình Dương",    "lat": 10.9804, "lng": 106.6519, "radius": 11000},
    "bienhoa":     {"display": "Đồng Nai",      "lat": 10.9447, "lng": 106.8243, "radius": 11000},
    "vungtau":     {"display": "Bà Rịa-Vũng Tàu","lat": 10.3460,"lng": 107.0843, "radius": 10000},
    "dongxoai":    {"display": "Bình Phước",    "lat": 11.5345, "lng": 106.8932, "radius": 7000},
    "tayninh":     {"display": "Tây Ninh",      "lat": 11.3100, "lng": 106.0989, "radius": 8000},
    "tanan":       {"display": "Long An",       "lat": 10.5333, "lng": 106.4133, "radius": 8000},
    "mytho":       {"display": "Tiền Giang",    "lat": 10.3600, "lng": 106.3600, "radius": 8000},
    "bentre":      {"display": "Bến Tre",       "lat": 10.2415, "lng": 106.3759, "radius": 8000},
    "travinh":     {"display": "Trà Vinh",      "lat": 9.9347,  "lng": 106.3453, "radius": 7000},
    "vinhlong":    {"display": "Vĩnh Long",     "lat": 10.2538, "lng": 105.9722, "radius": 8000},
    "caolanh":     {"display": "Đồng Tháp",     "lat": 10.4593, "lng": 105.6326, "radius": 8000},
    "longxuyen":   {"display": "An Giang",      "lat": 10.3860, "lng": 105.4380, "radius": 9000},
    "rachgia":     {"display": "Kiên Giang",    "lat": 10.0125, "lng": 105.0808, "radius": 9000},
    "phuquoc":     {"display": "Kiên Giang",    "lat": 10.2270, "lng": 103.9640, "radius": 12000},
    "cantho":      {"display": "Cần Thơ",       "lat": 10.0452, "lng": 105.7469, "radius": 12000},
    "vithanh":     {"display": "Hậu Giang",     "lat": 9.7840,  "lng": 105.4700, "radius": 7000},
    "soctrang":    {"display": "Sóc Trăng",     "lat": 9.6033,  "lng": 105.9800, "radius": 8000},
    "baclieu":     {"display": "Bạc Liêu",      "lat": 9.2940,  "lng": 105.7270, "radius": 8000},
    "camau":       {"display": "Cà Mau",        "lat": 9.1769,  "lng": 105.1524, "radius": 9000},
}

# Region groups so you can run a slice at a time: --city north / central / south / all
REGION_GROUPS: dict[str, list[str]] = {
    "north": ["hanoi", "haiphong", "halong", "bacninh", "haiduong", "hungyen", "vinhyen",
              "bacgiang", "viettri", "thainguyen", "langson", "caobang", "backan", "tuyenquang",
              "hagiang", "laocai", "sapa", "yenbai", "dienbien", "laichau", "sonla", "hoabinh",
              "phuly", "namdinh", "thaibinh", "ninhbinh"],
    "central": ["thanhhoa", "vinh", "hatinh", "donghoi", "dongha", "hue", "danang", "hoian",
                "tamky", "quangngai", "quynhon", "tuyhoa", "nhatrang", "phanrang", "phanthiet",
                "kontum", "pleiku", "buonmathuot", "gianghia", "dalat"],
    "south": ["hcm", "thudaumot", "bienhoa", "vungtau", "dongxoai", "tayninh", "tanan", "mytho",
              "bentre", "travinh", "vinhlong", "caolanh", "longxuyen", "rachgia", "phuquoc",
              "cantho", "vithanh", "soctrang", "baclieu", "camau"],
}

# ---------------------------------------------------------------------------
# Cuisine inference — map source values to HNAG's kebab-case cuisine_tags
# (vocabulary taken from code/sql/02_seed_data.sql).
# ---------------------------------------------------------------------------
OSM_CUISINE_MAP: dict[str, list[str]] = {
    "vietnamese": ["vietnamese"], "pho": ["vietnamese", "pho"], "noodle": ["noodle"],
    "asian": ["asian"], "chinese": ["chinese"], "dim_sum": ["chinese", "dim-sum"],
    "japanese": ["japanese"], "sushi": ["japanese", "sushi"], "ramen": ["japanese", "noodle"],
    "korean": ["korean"], "thai": ["thai"], "indian": ["indian"],
    "italian": ["italian"], "pizza": ["italian", "pizza"], "pasta": ["italian"],
    "french": ["french"], "american": ["western", "american"], "burger": ["western", "burger"],
    "steak_house": ["western", "steak"], "mexican": ["mexican"], "kebab": ["kebab"],
    "seafood": ["seafood"], "fish": ["seafood"], "bbq": ["bbq"], "barbecue": ["bbq"],
    "grill": ["bbq"], "hotpot": ["hot-pot"], "hot_pot": ["hot-pot"],
    "vegetarian": ["healthy", "vegetarian"], "vegan": ["healthy", "vegan"], "salad": ["healthy"],
    "coffee_shop": ["cafe"], "cafe": ["cafe"], "coffee": ["cafe"], "tea": ["drink"],
    "bubble_tea": ["drink", "bubble-tea"], "ice_cream": ["dessert"], "dessert": ["dessert"],
    "cake": ["dessert", "bakery"], "bakery": ["bakery"], "breakfast": ["breakfast"],
    "chicken": ["chicken"], "fried_chicken": ["western", "chicken"], "sandwich": ["western"],
    "fast_food": ["fast-food"], "international": ["western"], "regional": [],
}
AMENITY_BASE: dict[str, list[str]] = {
    "cafe": ["cafe"], "fast_food": ["fast-food"], "food_court": [], "restaurant": [],
}
# Vietnamese name hints (lowercased, diacritics kept) → tags. Order matters: specific first.
VN_NAME_HINTS: list[tuple[str, list[str]]] = [
    ("bún bò", ["vietnamese", "bun-bo-hue", "trung"]), ("bún chả", ["vietnamese", "bun-cha", "bac"]),
    ("cơm tấm", ["vietnamese", "com-tam", "nam"]), ("bánh mì", ["vietnamese", "banh-mi"]),
    ("bánh xèo", ["vietnamese", "banh-xeo"]), ("bánh cuốn", ["vietnamese", "banh-cuon"]),
    ("hủ tiếu", ["vietnamese", "hu-tieu"]), ("phở", ["vietnamese", "pho"]),
    ("trà sữa", ["drink", "bubble-tea"]), ("cà phê", ["cafe"]), ("cafe", ["cafe"]),
    ("coffee", ["cafe"]), ("lẩu", ["vietnamese", "hot-pot"]), ("nướng", ["bbq"]),
    ("hải sản", ["seafood"]), ("ốc", ["vietnamese", "seafood"]), ("chè", ["dessert"]),
    ("bún", ["vietnamese", "noodle"]), ("cơm", ["vietnamese"]), ("gà", ["chicken"]),
    ("pizza", ["italian", "pizza"]), ("sushi", ["japanese", "sushi"]), ("bbq", ["bbq"]),
]

_DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
_OSM_DAY = {"mo": "mon", "tu": "tue", "we": "wed", "th": "thu", "fr": "fri", "sa": "sat", "su": "sun"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def strip_diacritics(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()


def slugify(name: str, suffix: str) -> str:
    base = strip_diacritics(name).lower()
    base = re.sub(r"[^a-z0-9\s-]", "", base)
    base = re.sub(r"[\s-]+", "-", base).strip("-")
    return f"{(base[:80] or 'quan')}-{suffix}"


def dedup(seq: Iterable[str]) -> list[str]:
    seen: dict[str, None] = {}
    for x in seq:
        if x and x not in seen:
            seen[x] = None
    return list(seen.keys())


def fit(s: str | None, n: int) -> str | None:
    """Trim a string to fit a VARCHAR(n) column; None/empty -> None."""
    if not s:
        return None
    s = s.strip()
    return s[:n] or None


def clean_phone(s: str | None) -> str | None:
    """OSM phone fields may list several numbers — keep the first, fit VARCHAR(30)."""
    if not s:
        return None
    s = re.split(r"[;,/]| or | hoặc ", s)[0].strip()
    return s[:30] or None


def build_cuisine_tags(amenity: str, cuisine_str: str | None, name: str) -> list[str]:
    tags: list[str] = list(AMENITY_BASE.get(amenity, []))
    for token in re.split(r"[;,]", (cuisine_str or "").lower()):
        token = token.strip().replace("-", "_")
        tags.extend(OSM_CUISINE_MAP.get(token, []))
    low = name.lower()
    for needle, hint in VN_NAME_HINTS:
        if needle in low:
            tags.extend(hint)
            break  # first matching hint is enough
    return dedup(tags)


def expand_days(spec: str) -> list[str]:
    result: list[str] = []
    for part in spec.strip().lower().split(","):
        part = part.strip()
        if "-" in part:
            a, b = (p.strip()[:2] for p in part.split("-", 1))
            da, db = _OSM_DAY.get(a), _OSM_DAY.get(b)
            if da and db:
                ia, ib = _DAYS.index(da), _DAYS.index(db)
                result += _DAYS[ia:ib + 1] if ia <= ib else _DAYS[ia:] + _DAYS[:ib + 1]
        else:
            d = _OSM_DAY.get(part[:2])
            if d:
                result.append(d)
    return result


def parse_opening_hours(s: str | None) -> dict[str, Any] | None:
    """Best-effort OSM opening_hours → {mon:'6:00-22:00', ..., _raw:'...'}. Always keeps _raw."""
    if not s:
        return None
    s = s.strip()
    out: dict[str, Any] = {"_raw": s}
    if s in ("24/7", "Mo-Su 00:00-24:00"):
        for d in _DAYS:
            out[d] = "0:00-24:00"
        return out
    try:
        for rule in s.split(";"):
            rule = rule.strip()
            if not rule:
                continue
            m = re.match(r"^([A-Za-z][A-Za-z,\- ]*?)\s+(.+)$", rule)
            days_spec, times = (m.group(1), m.group(2)) if m else ("Mo-Su", rule)
            days = expand_days(days_spec)
            if not days:
                continue
            if re.search(r"off|closed", times, re.I):
                tval = "closed"
            else:
                spans = re.findall(r"(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})", times)
                if not spans:
                    continue
                tval = ",".join(f"{a}-{b}" for a, b in spans)
            for d in days:
                out[d] = tval
    except Exception:
        return {"_raw": s}
    return out


def first(tags: dict[str, str], *keys: str) -> str | None:
    for k in keys:
        v = tags.get(k)
        if v and v.strip():
            return v.strip()
    return None


def build_address(tags: dict[str, str], city_display: str) -> tuple[str | None, str | None, str | None]:
    """Return (address, district, ward)."""
    full = first(tags, "addr:full")
    house = first(tags, "addr:housenumber")
    street = first(tags, "addr:street")
    ward = first(tags, "addr:subdistrict", "addr:quarter", "addr:ward", "addr:suburb")
    district = first(tags, "addr:district", "addr:city_district")
    if full:
        address = full
    else:
        line = " ".join(p for p in [house, street] if p)
        address = ", ".join(p for p in [line, ward, district, city_display] if p) or None
    return address, district, ward


# ---------------------------------------------------------------------------
# Fetchers
# ---------------------------------------------------------------------------
def http_post(url: str, data: bytes, headers: dict[str, str], timeout: int = 180) -> bytes:
    req = urllib.request.Request(url, data=data, headers={**headers, "User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def http_get(url: str, headers: dict[str, str], timeout: int = 60) -> tuple[bytes, Any]:
    req = urllib.request.Request(url, headers={**headers, "User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.headers


def overpass_query(query: str, retries: int = 4) -> list[dict[str, Any]]:
    """POST to Overpass with exponential backoff on rate-limit / overload (429/502/503/504)."""
    body = urllib.parse.urlencode({"data": query}).encode()
    delay = 5
    for attempt in range(1, retries + 1):
        try:
            raw = http_post(OVERPASS_URL, body, {"Content-Type": "application/x-www-form-urlencoded"})
            return json.loads(raw.decode("utf-8")).get("elements", [])
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503, 504) and attempt < retries:
                print(f"    overpass {e.code}, retry {attempt}/{retries} in {delay}s", file=sys.stderr)
                time.sleep(delay); delay *= 2; continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt < retries:
                print(f"    overpass error ({e}), retry {attempt}/{retries} in {delay}s", file=sys.stderr)
                time.sleep(delay); delay *= 2; continue
            raise
    return []


def fetch_osm(city_key: str, limit: int, radius: int | None) -> list[dict[str, Any]]:
    c = CITY_PRESETS[city_key]
    r = radius or c["radius"]
    query = (
        f"[out:json][timeout:120];"
        f'(nwr["amenity"~"^(restaurant|cafe|fast_food|food_court)$"]["name"]'
        f'(around:{r},{c["lat"]},{c["lng"]}););'
        f"out center tags {limit};"
    )
    elements = overpass_query(query)

    out: list[dict[str, Any]] = []
    for el in elements:
        tags = el.get("tags", {})
        name = first(tags, "name", "name:vi", "name:en")
        if not name:
            continue
        lat = el.get("lat") or (el.get("center") or {}).get("lat")
        lng = el.get("lon") or (el.get("center") or {}).get("lon")
        if lat is None or lng is None:
            continue
        amenity = tags.get("amenity", "restaurant")
        address, district, ward = build_address(tags, c["display"])
        out.append({
            "name": fit(name, 180),
            "slug": slugify(name, f'{el["type"][0]}{el["id"]}'),
            "lat": float(lat), "lng": float(lng),
            "city": fit(first(tags, "addr:city") or c["display"], 80),
            "district": fit(district, 80), "ward": fit(ward, 80), "address": address,
            "phone": clean_phone(first(tags, "phone", "contact:phone", "phone:VN")),
            "website": first(tags, "website", "contact:website"),
            "cuisine_tags": build_cuisine_tags(amenity, tags.get("cuisine"), name),
            "open_hours": parse_opening_hours(first(tags, "opening_hours")),
        })
    return out


def fetch_foursquare(city_key: str, limit: int, radius: int | None, api_key: str) -> list[dict[str, Any]]:
    c = CITY_PRESETS[city_key]
    r = radius or c["radius"]
    out: list[dict[str, Any]] = []
    cursor: str | None = None
    while len(out) < limit:
        params = {
            "ll": f'{c["lat"]},{c["lng"]}', "radius": min(r, 100000),
            "categories": FSQ_RESTAURANT_CATEGORY, "limit": 50,
            "fields": "fsq_id,name,location,categories,tel,website,hours",
        }
        if cursor:
            params["cursor"] = cursor
        raw, headers = http_get(FSQ_API + "?" + urllib.parse.urlencode(params),
                                {"Authorization": api_key, "accept": "application/json"})
        results = json.loads(raw.decode("utf-8")).get("results", [])
        if not results:
            break
        for p in results:
            loc = p.get("location", {})
            geo = p.get("geocodes", {}).get("main", {}) or {}
            lat = geo.get("latitude") or loc.get("latitude")
            lng = geo.get("longitude") or loc.get("longitude")
            name = p.get("name")
            if not name or lat is None or lng is None:
                continue
            cats = [x.get("name", "") for x in p.get("categories", [])]
            out.append({
                "name": fit(name, 180), "slug": slugify(name, p["fsq_id"][:8]),
                "lat": float(lat), "lng": float(lng),
                "city": fit(loc.get("locality") or c["display"], 80),
                "district": fit(loc.get("region"), 80), "ward": None,
                "address": loc.get("formatted_address") or loc.get("address"),
                "phone": clean_phone(p.get("tel")), "website": p.get("website"),
                "cuisine_tags": build_cuisine_tags("restaurant", ";".join(cats).lower().replace(" ", "_"), name),
                "open_hours": None,
            })
        link = (headers.get("Link") or "")
        cursor = link.split("cursor=")[1].split("&")[0].rstrip(">") if "cursor=" in link else None
        if not cursor:
            break
    return out[:limit]


# ---------------------------------------------------------------------------
# Output: SQL file
# ---------------------------------------------------------------------------
def sql_text(v: str | None) -> str:
    if v is None:
        return "NULL"
    return "'" + v.replace("'", "''") + "'"


def sql_text_array(items: list[str]) -> str:
    if not items:
        return "ARRAY[]::TEXT[]"
    inner = ",".join("'" + s.replace("'", "''") + "'" for s in items)
    return f"ARRAY[{inner}]"


def sql_jsonb(obj: dict[str, Any] | None) -> str:
    if not obj:
        return "NULL"
    return "'" + json.dumps(obj, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def row_to_values(rec: dict[str, Any]) -> str:
    return (
        "("
        f'{sql_text(rec["name"])},{sql_text(rec["slug"])},{sql_text(rec.get("address"))},'
        f'{sql_text(rec.get("city"))},{sql_text(rec.get("district"))},{sql_text(rec.get("ward"))},'
        f"ST_GeogFromText('POINT({rec['lng']:.7f} {rec['lat']:.7f})'),"
        f'{sql_text(rec.get("phone"))},{sql_text(rec.get("website"))},'
        f'{sql_text_array(rec.get("cuisine_tags", []))},{sql_jsonb(rec.get("open_hours"))},'
        "FALSE,'active',NOW(),NOW())"
    )


def fetch_existing_slugs(db_url: str) -> set[str]:
    """Pre-fetch all `restaurants.slug` for the incremental filter.

    With ~14k rows today, this is a sub-second single SELECT and saves us
    from issuing 14k no-op UPDATEs per daily refresh.
    """
    try:
        import psycopg2
    except ImportError:
        sys.exit("ERROR: --incremental needs psycopg2. Run: pip install psycopg2-binary")
    conn = psycopg2.connect(db_url)
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT slug FROM restaurants")
            return {row[0] for row in cur.fetchall()}
    finally:
        conn.close()


def write_sql(records: list[dict[str, Any]], path: str, source: str, incremental: bool = False) -> None:
    cols = ("name, slug, address, city, district, ward, location, phone, website, "
            "cuisine_tags, open_hours, is_verified, status, created_at, updated_at")
    # Incremental mode: never touch existing rows. DO NOTHING preserves
    # any curated data already in DB (verified_at, manually-edited
    # cuisine_tags, etc.) while still letting NEW slugs flow in.
    conflict = "ON CONFLICT (slug) DO NOTHING;" if incremental else (
        "ON CONFLICT (slug) DO UPDATE SET\n"
        "  phone        = COALESCE(EXCLUDED.phone, restaurants.phone),\n"
        "  website      = COALESCE(EXCLUDED.website, restaurants.website),\n"
        "  address      = COALESCE(EXCLUDED.address, restaurants.address),\n"
        "  open_hours   = COALESCE(EXCLUDED.open_hours, restaurants.open_hours),\n"
        "  cuisine_tags = CASE WHEN cardinality(restaurants.cuisine_tags) = 0\n"
        "                      THEN EXCLUDED.cuisine_tags ELSE restaurants.cuisine_tags END,\n"
        "  updated_at   = NOW();"
    )
    import os
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"-- HNAG restaurants ingestion — source: {source}\n")
        if source == "osm":
            f.write("-- Data © OpenStreetMap contributors (ODbL). https://www.openstreetmap.org/copyright\n")
        f.write(f"-- {len(records)} rows. Idempotent (ON CONFLICT slug). Generated by scrape_restaurants.py\n")
        f.write("SET client_encoding = 'UTF8';\nBEGIN;\n")
        for i in range(0, len(records), 500):
            chunk = records[i:i + 500]
            f.write(f"\nINSERT INTO restaurants ({cols}) VALUES\n")
            f.write(",\n".join(row_to_values(r) for r in chunk))
            f.write("\n" + conflict + "\n")
        f.write("\nCOMMIT;\n")


def insert_direct(records: list[dict[str, Any]], db_url: str) -> int:
    try:
        import psycopg2
        from psycopg2.extras import Json
    except ImportError:
        sys.exit("ERROR: --direct needs psycopg2. Run: pip install psycopg2-binary")
    sql = """
        INSERT INTO restaurants
          (name, slug, address, city, district, ward, location, phone, website,
           cuisine_tags, open_hours, is_verified, status, created_at, updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,
                ST_GeogFromText('POINT(' || %s || ' ' || %s || ')'),
                %s,%s,%s,%s, FALSE, 'active', NOW(), NOW())
        ON CONFLICT (slug) DO UPDATE SET
          phone        = COALESCE(EXCLUDED.phone, restaurants.phone),
          website      = COALESCE(EXCLUDED.website, restaurants.website),
          address      = COALESCE(EXCLUDED.address, restaurants.address),
          open_hours   = COALESCE(EXCLUDED.open_hours, restaurants.open_hours),
          cuisine_tags = CASE WHEN cardinality(restaurants.cuisine_tags) = 0
                              THEN EXCLUDED.cuisine_tags ELSE restaurants.cuisine_tags END,
          updated_at   = NOW();
    """
    conn = psycopg2.connect(db_url)
    n = 0
    try:
        with conn, conn.cursor() as cur:
            for r in records:
                cur.execute(sql, (
                    r["name"], r["slug"], r.get("address"), r.get("city"),
                    r.get("district"), r.get("ward"), f"{r['lng']:.7f}", f"{r['lat']:.7f}",
                    r.get("phone"), r.get("website"), r.get("cuisine_tags", []),
                    Json(r["open_hours"]) if r.get("open_hours") else None,
                ))
                n += 1
    finally:
        conn.close()
    return n


# ---------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description="Fetch VN restaurants → SQL/DB for HNAG.")
    ap.add_argument("--source", choices=["osm", "foursquare"], default="osm")
    ap.add_argument("--city", default="all",
                    help="comma list of city keys, or a region: north / central / south / all. "
                         f"city keys: {', '.join(CITY_PRESETS)}")
    ap.add_argument("--limit", type=int, default=6000, help="max rows per city")
    ap.add_argument("--radius", type=int, default=None, help="override search radius (meters)")
    ap.add_argument("--sleep", type=float, default=2.0, help="courtesy pause between cities (seconds)")
    ap.add_argument("--out", default="out/restaurants.sql", help="output .sql path")
    ap.add_argument("--direct", action="store_true", help="insert into DB instead of writing SQL")
    ap.add_argument("--db-url", default=None, help="DATABASE_URL for --direct")
    ap.add_argument("--fsq-key", default=None, help="Foursquare API key (or env FSQ_API_KEY)")
    ap.add_argument(
        "--incremental",
        action="store_true",
        help=(
            "Skip slugs that already exist. With --direct: pre-fetches existing "
            "slugs from DB and filters records BEFORE upsert. With SQL output: "
            "switches ON CONFLICT clause from DO UPDATE → DO NOTHING. Use this "
            "for daily refreshes so existing curated rows aren't churned."
        ),
    )
    args = ap.parse_args()

    cities: list[str] = []
    for tok in args.city.split(","):
        tok = tok.strip().lower()
        if tok == "all":
            cities = list(CITY_PRESETS)
            break
        cities.extend(REGION_GROUPS.get(tok, [tok]))
    cities = list(dict.fromkeys(cities))  # de-dupe, keep order
    bad = [c for c in cities if c not in CITY_PRESETS]
    if bad:
        sys.exit(f"Unknown city/region keys: {bad}\n  cities: {', '.join(CITY_PRESETS)}"
                 f"\n  regions: {', '.join(REGION_GROUPS)}, all")

    fsq_key = args.fsq_key
    if args.source == "foursquare":
        import os
        fsq_key = fsq_key or os.environ.get("FSQ_API_KEY")
        if not fsq_key:
            sys.exit("Foursquare needs a key: --fsq-key XXX or set FSQ_API_KEY")

    all_records: list[dict[str, Any]] = []
    for i, city in enumerate(cities):
        if i:
            time.sleep(args.sleep)  # courtesy pause between cities
        print(f"[{args.source}] fetching {city} ({CITY_PRESETS[city]['display']})...", file=sys.stderr)
        try:
            recs = (fetch_osm(city, args.limit, args.radius) if args.source == "osm"
                    else fetch_foursquare(city, args.limit, args.radius, fsq_key))
        except Exception as e:
            print(f"  ! {city} failed: {e}", file=sys.stderr)
            continue
        print(f"  -> {len(recs)} places", file=sys.stderr)
        all_records.extend(recs)

    # de-duplicate by slug across cities
    by_slug: dict[str, dict[str, Any]] = {}
    for r in all_records:
        by_slug.setdefault(r["slug"], r)
    records = list(by_slug.values())

    with_cuisine = sum(1 for r in records if r["cuisine_tags"])
    with_hours = sum(1 for r in records if r["open_hours"])
    with_phone = sum(1 for r in records if r["phone"])
    print(f"\nTotal unique: {len(records)} | cuisine-tagged: {with_cuisine} | "
          f"hours: {with_hours} | phone: {with_phone}", file=sys.stderr)

    if not records:
        sys.exit("No records fetched — nothing to write.")

    if args.direct:
        db_url = args.db_url
        if not db_url:
            import os
            db_url = os.environ.get("DATABASE_URL")
        if not db_url:
            sys.exit("--direct needs --db-url or env DATABASE_URL")
        if args.incremental:
            existing = fetch_existing_slugs(db_url)
            before = len(records)
            records = [r for r in records if r["slug"] not in existing]
            print(
                f"Incremental: kept {len(records)}/{before} records ({len(existing)} already in DB)",
                file=sys.stderr,
            )
            if not records:
                print("Nothing new to upsert.", file=sys.stderr)
                return
        n = insert_direct(records, db_url)
        print(f"Upserted {n} restaurants into DB.", file=sys.stderr)
    else:
        write_sql(records, args.out, args.source, incremental=args.incremental)
        suffix = " (incremental — ON CONFLICT DO NOTHING)" if args.incremental else ""
        print(f"Wrote {len(records)} rows -> {args.out}{suffix}", file=sys.stderr)


if __name__ == "__main__":
    main()
