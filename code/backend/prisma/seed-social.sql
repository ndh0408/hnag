-- Seed real posts + reviews so social/feed/comments are not fake.
-- Idempotent: deletes prior seed rows by sentinel tag before re-inserting.

BEGIN;

-- Clean any previous seed rows (tagged by `is_seed_marker` in tags array).
DELETE FROM post_likes WHERE post_id IN (SELECT id FROM posts WHERE 'seeded' = ANY(tags));
DELETE FROM post_comments WHERE post_id IN (SELECT id FROM posts WHERE 'seeded' = ANY(tags));
DELETE FROM posts WHERE 'seeded' = ANY(tags);
DELETE FROM reviews WHERE 'seeded' = ANY(COALESCE(images, ARRAY[]::text[]));

-- 8 posts referencing real foods + real users. Captions are Vietnamese.
INSERT INTO posts (id, user_id, type, caption, media_url, media_poster, food_id, tags, like_count, comment_count, view_count, save_count, created_at)
VALUES
  (gen_random_uuid(), 'adae9f87-3dc7-448d-a922-f3b271f1687c', 'photo',
   'Bánh bèo Huế nhỏ xíu mà ngon dã man 😍',
   'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=85',
   'https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&q=70',
   'f0000000-0000-0000-0000-000000000017',
   ARRAY['seeded','banhbeo','hue'], 4621, 89, 18432, 234, NOW() - INTERVAL '2 hours'),

  (gen_random_uuid(), '1435ea7c-b4f2-495f-b1db-ba698ecc79dd', 'photo',
   'Cơm tấm sườn cháy cạnh + chả + bì + nước mắm. Trưa nay là phải vầy ✨',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=70',
   'f0000000-0000-0000-0000-000000000019',
   ARRAY['seeded','comtam','luu'], 8234, 156, 32104, 412, NOW() - INTERVAL '4 hours'),

  (gen_random_uuid(), '570f5b77-391c-475b-9a50-cbcc58cfcbb2', 'video',
   'Cách pha cà phê sữa đá đỉnh — phin nóng 4 phút 🇻🇳',
   'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85',
   'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&q=70',
   'f0000000-0000-0000-0000-000000000045',
   ARRAY['seeded','caphe','hot'], 5102, 234, 28910, 678, NOW() - INTERVAL '6 hours'),

  (gen_random_uuid(), 'df2bd3cd-fe51-4683-b0ef-5adb639f7479', 'photo',
   'Chè ba màu sài gòn — mát lạnh cho ngày nóng 🌈',
   'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=1200&q=85',
   'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&q=70',
   'f0000000-0000-0000-0000-000000000041',
   ARRAY['seeded','che','dessert'], 3287, 67, 12048, 189, NOW() - INTERVAL '8 hours'),

  (gen_random_uuid(), 'a4ad3df1-f095-495a-b945-5bc3088116e3', 'photo',
   'Xôi mặn sáng nay — trứng, lạp xưởng, hành phi. Năng lượng full bình 💪',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=70',
   'f0000000-0000-0000-0000-000000000060',
   ARRAY['seeded','xoi','sang'], 2156, 43, 8901, 98, NOW() - INTERVAL '12 hours'),

  (gen_random_uuid(), 'adae9f87-3dc7-448d-a922-f3b271f1687c', 'photo',
   'Cơm trộn Hàn — phiên bản Việt hoá với rau muống + tóp mỡ. Worth try!',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85',
   'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=70',
   'f0000000-0000-0000-0000-000000000056',
   ARRAY['seeded','bibimbap','fusion'], 1892, 35, 6543, 87, NOW() - INTERVAL '14 hours'),

  (gen_random_uuid(), '1435ea7c-b4f2-495f-b1db-ba698ecc79dd', 'review',
   '⭐⭐⭐⭐⭐ Phở bò Lý Quốc Sư Q.3 — nước dùng đậm đà, bánh phở mềm vừa',
   'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=1200&q=85',
   'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=70',
   NULL,
   ARRAY['seeded','review','pho'], 1432, 21, 4521, 52, NOW() - INTERVAL '1 day'),

  (gen_random_uuid(), '570f5b77-391c-475b-9a50-cbcc58cfcbb2', 'photo',
   'Bún chả Hà Nội — chấm nước mắm chua ngọt là chân ái 🍜',
   'https://images.unsplash.com/photo-1564671165093-20688ff1fffa?w=1200&q=85',
   'https://images.unsplash.com/photo-1564671165093-20688ff1fffa?w=600&q=70',
   NULL,
   ARRAY['seeded','buncha','hanoi'], 3543, 78, 11203, 167, NOW() - INTERVAL '1 day 6 hours');

-- Real food reviews on Bánh bèo + Cơm tấm sườn
INSERT INTO reviews (id, user_id, food_id, rating, content, images, created_at)
VALUES
  (gen_random_uuid(), 'adae9f87-3dc7-448d-a922-f3b271f1687c',
   'f0000000-0000-0000-0000-000000000017', 5,
   'Bánh bèo nhỏ xinh, nhân tôm khô thơm, mắm nêm đậm vị. Một trong những món vặt yêu thích.',
   ARRAY['seeded','https://images.unsplash.com/photo-1559847844-5315695dadae?w=600'],
   NOW() - INTERVAL '3 days'),

  (gen_random_uuid(), '1435ea7c-b4f2-495f-b1db-ba698ecc79dd',
   'f0000000-0000-0000-0000-000000000017', 4,
   'Ngon, hợp khẩu vị người miền Bắc. Mắm nêm có thể bớt mặn hơn chút.',
   ARRAY['seeded'],
   NOW() - INTERVAL '5 days'),

  (gen_random_uuid(), '570f5b77-391c-475b-9a50-cbcc58cfcbb2',
   'f0000000-0000-0000-0000-000000000019', 5,
   'Cơm tấm sườn cháy cạnh, ăn kèm bì heo + chả trứng. Đỉnh cao món Sài Gòn.',
   ARRAY['seeded'],
   NOW() - INTERVAL '2 days'),

  (gen_random_uuid(), 'df2bd3cd-fe51-4683-b0ef-5adb639f7479',
   'f0000000-0000-0000-0000-000000000019', 5,
   'Phải có tóp mỡ giòn rụm + dưa chua + nước mắm chua ngọt. Đầy đủ topping mới đúng vị.',
   ARRAY['seeded'],
   NOW() - INTERVAL '4 days'),

  (gen_random_uuid(), 'a4ad3df1-f095-495a-b945-5bc3088116e3',
   'f0000000-0000-0000-0000-000000000045', 5,
   'Cà phê sữa đá quán Việt — vị đậm đặc, sữa đặc Vinamilk béo ngậy. Cứ sáng là phải có.',
   ARRAY['seeded'],
   NOW() - INTERVAL '1 day'),

  (gen_random_uuid(), 'adae9f87-3dc7-448d-a922-f3b271f1687c',
   'f0000000-0000-0000-0000-000000000060', 4,
   'Xôi mặn nóng dẻo, ăn 1 phần là no đến trưa. Giá hợp lý, đầy đủ topping.',
   ARRAY['seeded'],
   NOW() - INTERVAL '6 days');

COMMIT;

SELECT 'Seeded ' || COUNT(*) || ' posts' FROM posts WHERE 'seeded' = ANY(tags);
SELECT 'Seeded ' || COUNT(*) || ' reviews' FROM reviews WHERE 'seeded' = ANY(COALESCE(images, ARRAY[]::text[]));
