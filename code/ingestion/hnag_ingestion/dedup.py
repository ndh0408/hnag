"""
Multi-signal restaurant deduplication (see docs/11-DATA-INGESTION.md §5).
"""
from __future__ import annotations
import unicodedata, re, math
from typing import Iterable

from rapidfuzz import fuzz


def normalize_vi(s: str) -> str:
    s = unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()
    s = re.sub(r'[^\w\s]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl   = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dl / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def match_score(a: dict, b: dict) -> float:
    """Return 0..1 likelihood that a and b are the same restaurant."""
    score = 0.0

    if a.get('phone') and b.get('phone') and a['phone'].replace(' ', '') == b['phone'].replace(' ', ''):
        score += 0.5

    if a.get('lat') and b.get('lat'):
        d = haversine_m(a['lat'], a['lng'], b['lat'], b['lng'])
        if d < 50: score += 0.3
        elif d < 200: score += 0.15

    n_a = normalize_vi(a.get('name', ''))
    n_b = normalize_vi(b.get('name', ''))
    if n_a and n_b:
        sim = fuzz.token_set_ratio(n_a, n_b) / 100.0
        score += sim * 0.3

    if a.get('address') and b.get('address'):
        addr_sim = fuzz.partial_ratio(normalize_vi(a['address']), normalize_vi(b['address'])) / 100.0
        score += addr_sim * 0.2

    return min(score, 1.0)


def cluster_duplicates(rows: Iterable[dict], threshold: float = 0.75) -> list[list[dict]]:
    """Cluster restaurants by pairwise match_score >= threshold."""
    rows = list(rows)
    clusters: list[list[dict]] = []
    used = set()
    for i, r in enumerate(rows):
        if i in used: continue
        cluster = [r]; used.add(i)
        for j in range(i + 1, len(rows)):
            if j in used: continue
            if match_score(r, rows[j]) >= threshold:
                cluster.append(rows[j]); used.add(j)
        clusters.append(cluster)
    return clusters
