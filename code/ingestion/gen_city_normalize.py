"""Generate SQL to normalize restaurants.city to the canonical province name of the
nearest CITY_PRESETS center (fixes OSM addr:city variants like 'Ho Chi Minh City',
'Ha Noi', ward/district names). Only touches OSM-ingested rows (slug ~ -[nwr]<id>)."""
from scrape_restaurants import CITY_PRESETS

rows = ",\n".join(f"('{v['display']}',{v['lng']},{v['lat']})" for v in CITY_PRESETS.values())
sql = f"""SET client_encoding='UTF8';
BEGIN;
WITH presets(display,lng,lat) AS (VALUES
{rows}
)
UPDATE restaurants r
SET city = (
  SELECT p.display FROM presets p
  ORDER BY r.location::geography <-> ST_SetSRID(ST_MakePoint(p.lng,p.lat),4326)::geography
  LIMIT 1
)
WHERE r.location IS NOT NULL AND r.slug ~ '-[nwr][0-9]+$';
COMMIT;
"""
with open("out/normalize_city.sql", "w", encoding="utf-8", newline="\n") as f:
    f.write(sql)
print(f"wrote out/normalize_city.sql with {len(CITY_PRESETS)} presets")
