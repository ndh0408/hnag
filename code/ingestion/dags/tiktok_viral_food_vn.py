"""
TikTok viral food ingestion — runs hourly, detects emerging viral dishes in VN,
matches them to local restaurants, publishes to viral_dishes table.

See docs/07-AI-ENGINES.md §3 + docs/11-DATA-INGESTION.md §8.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Any

import httpx
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

WATCHLIST_HASHTAGS = [
    'monan', 'anuong', 'foodtour', 'saigonfood', 'hanoifood',
    'reviewquan', 'vietnamesefood', 'banhmiviet', 'phohanoi',
    'taynguyenfood', 'andong', 'streetfood', 'foodporn',
    'foodvietnam', 'cafesaigon', 'foodtok', 'foodietiktok',
]

TIKTOK_RESEARCH_API = 'https://open.tiktokapis.com/v2/research/video/query/'

default_args = {
    'owner': 'hnag-data',
    'depends_on_past': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='tiktok_viral_food_vn',
    description='Detect viral Vietnamese food trends from TikTok hourly',
    schedule='0 * * * *',
    start_date=datetime(2026, 5, 1),
    catchup=False,
    default_args=default_args,
    tags=['ingestion', 'viral', 'tiktok'],
) as dag:

    def fetch_food_hashtag_videos(**ctx) -> int:
        """Fetch latest videos for VN food hashtags via TikTok Research API."""
        token = os.environ['TIKTOK_ACCESS_TOKEN']
        since = int((datetime.utcnow() - timedelta(hours=2)).timestamp())
        until = int(datetime.utcnow().timestamp())

        hook = PostgresHook(postgres_conn_id='hnag_postgres')
        total_inserted = 0

        for hashtag in WATCHLIST_HASHTAGS:
            body = {
                'query': {
                    'and': [
                        {'operation': 'IN',  'field_name': 'hashtag_name', 'field_values': [hashtag]},
                        {'operation': 'GTE', 'field_name': 'create_date',  'field_values': [str(since)]},
                        {'operation': 'LTE', 'field_name': 'create_date',  'field_values': [str(until)]},
                    ]
                },
                'fields': ['id', 'video_description', 'create_time', 'username', 'view_count', 'like_count', 'share_count'],
                'max_count': 100,
            }
            try:
                with httpx.Client(timeout=10) as client:
                    r = client.post(
                        TIKTOK_RESEARCH_API,
                        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
                        json=body,
                    )
                    r.raise_for_status()
                    data = r.json().get('data', {}).get('videos', [])
            except Exception as e:
                print(f'[{hashtag}] fetch failed: {e}')
                continue

            for v in data:
                hook.run("""
                    INSERT INTO viral_videos_raw (platform, external_id, creator_handle, caption, views, likes, shares, posted_at, ingested_at)
                    VALUES ('tiktok', %s, %s, %s, %s, %s, %s, to_timestamp(%s), NOW())
                    ON CONFLICT (platform, external_id) DO UPDATE SET
                      views = EXCLUDED.views, likes = EXCLUDED.likes, shares = EXCLUDED.shares;
                """, parameters=(
                    v['id'], v.get('username'), v.get('video_description'),
                    v.get('view_count', 0), v.get('like_count', 0), v.get('share_count', 0),
                    v.get('create_time', until),
                ))
                total_inserted += 1
        print(f'Ingested {total_inserted} videos across {len(WATCHLIST_HASHTAGS)} hashtags')
        return total_inserted

    def analyze_videos(**ctx) -> int:
        """Run AI vision + NLU on new videos to extract dishes mentioned."""
        from hnag_ingestion.video_analysis import analyze_video
        hook = PostgresHook(postgres_conn_id='hnag_postgres')
        rows = hook.get_records("""
            SELECT id, caption, external_id FROM viral_videos_raw
            WHERE analyzed_at IS NULL
            ORDER BY ingested_at DESC LIMIT 200;
        """)
        for vid_id, caption, ext_id in rows:
            try:
                result = analyze_video(caption=caption, external_id=ext_id)
                hook.run("""
                    UPDATE viral_videos_raw
                    SET analyzed_at = NOW(),
                        detected_dish = %s,
                        confidence = %s,
                        cuisine = %s,
                        region_hint = %s,
                        restaurant_mentioned = %s
                    WHERE id = %s;
                """, parameters=(
                    result['dish'], result['confidence'], result['cuisine'],
                    result['region'], result.get('restaurant'), vid_id,
                ))
            except Exception as e:
                print(f'analyze {ext_id} failed: {e}')
        return len(rows)

    def cluster_trending_dishes(**ctx) -> int:
        """Group analyzed videos by detected dish, compute virality score."""
        hook = PostgresHook(postgres_conn_id='hnag_postgres')
        hook.run("""
            WITH clusters AS (
              SELECT detected_dish,
                     SUM(views) AS total_views,
                     COUNT(*)   AS video_count,
                     COUNT(DISTINCT creator_handle) AS creators,
                     MAX(ingested_at) AS last_seen
              FROM viral_videos_raw
              WHERE analyzed_at IS NOT NULL
                AND ingested_at >= NOW() - INTERVAL '72 hours'
                AND detected_dish IS NOT NULL
              GROUP BY detected_dish
              HAVING SUM(views) > 100000
            )
            INSERT INTO viral_dishes (food_id, dish_label, velocity_score, diversity_score, total_views, status, detected_at)
            SELECT
              (SELECT id FROM foods WHERE name_vi ILIKE c.detected_dish || '%' LIMIT 1),
              c.detected_dish,
              LOG(GREATEST(c.total_views, 1)) * 0.4
                + (c.creators::float / NULLIF(c.video_count, 0)) * 0.3
                + EXP(-EXTRACT(EPOCH FROM (NOW() - c.last_seen)) / 86400.0) * 0.3,
              c.creators::float / NULLIF(c.video_count, 0),
              c.total_views,
              CASE WHEN c.total_views > 1000000 THEN 'peak' ELSE 'rising' END,
              NOW()
            FROM clusters c
            ON CONFLICT (dish_label) DO UPDATE
            SET velocity_score = EXCLUDED.velocity_score,
                total_views    = EXCLUDED.total_views,
                status         = EXCLUDED.status;
        """)
        count = hook.get_first('SELECT COUNT(*) FROM viral_dishes WHERE detected_at >= NOW() - INTERVAL \'1 hour\'')[0]
        print(f'Updated {count} viral clusters')
        return count

    def publish_to_viral_engine(**ctx) -> int:
        """Push top viral dishes to Redis for Viral Engine to surface in feed."""
        import redis, json
        r = redis.from_url(os.environ['REDIS_URL'])
        hook = PostgresHook(postgres_conn_id='hnag_postgres')
        rows = hook.get_records("""
            SELECT id, food_id, dish_label, velocity_score, total_views
            FROM viral_dishes
            WHERE velocity_score > 0.65
              AND detected_at >= NOW() - INTERVAL '24 hours'
            ORDER BY velocity_score DESC LIMIT 50;
        """)
        payload = [
            {'id': str(r[0]), 'food_id': str(r[1]) if r[1] else None,
             'dish': r[2], 'velocity': float(r[3]), 'views': r[4]}
            for r in rows
        ]
        r.setex('viral:dishes:24h', 3600, json.dumps(payload))
        print(f'Published {len(payload)} viral dishes to Redis')
        return len(payload)

    fetch  = PythonOperator(task_id='fetch_videos',     python_callable=fetch_food_hashtag_videos)
    analyze = PythonOperator(task_id='analyze_videos',  python_callable=analyze_videos)
    cluster = PythonOperator(task_id='cluster_dishes',  python_callable=cluster_trending_dishes)
    publish = PythonOperator(task_id='publish',         python_callable=publish_to_viral_engine)

    fetch >> analyze >> cluster >> publish
