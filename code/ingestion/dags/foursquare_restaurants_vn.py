"""
Foursquare → HNAG restaurants ingestion.
Weekly full refresh of POIs (restaurants) for major VN cities.
"""
from __future__ import annotations
import os
from datetime import datetime, timedelta
from typing import Any

import httpx
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

CITIES = [
    {'name': 'TP.HCM',     'lat': 10.7626, 'lng': 106.6602},
    {'name': 'Hà Nội',     'lat': 21.0285, 'lng': 105.8542},
    {'name': 'Đà Nẵng',    'lat': 16.0544, 'lng': 108.2022},
    {'name': 'Hải Phòng',  'lat': 20.8449, 'lng': 106.6881},
    {'name': 'Cần Thơ',    'lat': 10.0452, 'lng': 105.7469},
    {'name': 'Nha Trang',  'lat': 12.2388, 'lng': 109.1967},
    {'name': 'Vũng Tàu',   'lat': 10.4114, 'lng': 107.1364},
]

FSQ_API = 'https://api.foursquare.com/v3/places/search'
RESTAURANT_CATEGORIES = '13065'  # Foursquare restaurants

default_args = {'owner': 'hnag-data', 'retries': 1, 'retry_delay': timedelta(minutes=10)}

with DAG(
    dag_id='foursquare_restaurants_vn',
    description='Sync Vietnamese restaurants from Foursquare weekly',
    schedule='0 3 * * 0',  # weekly Sunday 3am
    start_date=datetime(2026, 5, 1),
    catchup=False,
    default_args=default_args,
    tags=['ingestion', 'restaurants', 'foursquare'],
) as dag:

    def fetch_and_upsert(**ctx) -> int:
        api_key = os.environ['FSQ_API_KEY']
        hook = PostgresHook(postgres_conn_id='hnag_postgres')
        total = 0
        with httpx.Client(timeout=15) as client:
            for city in CITIES:
                next_cursor = None
                for _ in range(20):  # max 1000 results per city
                    params: dict[str, Any] = {
                        'll': f"{city['lat']},{city['lng']}",
                        'radius': 50000,
                        'categories': RESTAURANT_CATEGORIES,
                        'limit': 50,
                        'fields': 'fsq_id,name,location,categories,tel,hours,rating,photos,website',
                    }
                    if next_cursor: params['cursor'] = next_cursor

                    try:
                        r = client.get(FSQ_API,
                            headers={'Authorization': api_key},
                            params=params)
                        r.raise_for_status()
                    except Exception as e:
                        print(f'[{city["name"]}] error: {e}'); break

                    results = r.json().get('results', [])
                    if not results: break

                    for p in results:
                        loc = p.get('location', {})
                        lat = loc.get('latitude'); lng = loc.get('longitude')
                        if not lat or not lng: continue
                        hook.run("""
                            INSERT INTO restaurants (
                              id, name, slug, address, city, district,
                              location, phone, website, status,
                              created_at, updated_at
                            ) VALUES (
                              gen_random_uuid(), %s, %s, %s, %s, %s,
                              ST_GeogFromText('POINT(' || %s || ' ' || %s || ')'),
                              %s, %s, 'active', NOW(), NOW()
                            )
                            ON CONFLICT (slug) DO UPDATE SET
                              phone = COALESCE(EXCLUDED.phone, restaurants.phone),
                              website = COALESCE(EXCLUDED.website, restaurants.website),
                              updated_at = NOW();
                        """, parameters=(
                            p['name'],
                            _slugify(p['name'], p['fsq_id']),
                            loc.get('formatted_address') or loc.get('address'),
                            city['name'],
                            loc.get('region') or loc.get('locality'),
                            lng, lat,
                            p.get('tel'),
                            p.get('website'),
                        ))
                        total += 1

                    # Pagination
                    link = r.headers.get('link', '')
                    if 'cursor=' in link:
                        next_cursor = link.split('cursor=')[1].split('&')[0].rstrip('>')
                    else: break
        print(f'Upserted {total} restaurants from Foursquare')
        return total

    def _slugify(name: str, fsq_id: str) -> str:
        import re, unicodedata
        s = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower()
        s = re.sub(r'[^\w\s-]', '', s).strip().replace(' ', '-')
        return f'{s[:80]}-{fsq_id[:8]}'

    PythonOperator(task_id='fetch_upsert', python_callable=fetch_and_upsert)
