-- ============================================================================
-- HNAG — Curated VERIFIED food images (category-based mapping)
-- These Unsplash photo IDs are confirmed food photos with high view counts.
-- ============================================================================

-- 🍜 NOODLES (pho, bun, mi)
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85' WHERE slug IN ('pho-bo', 'pho-cuon');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=1200&q=85' WHERE slug IN ('bun-bo-hue', 'bun-rieu-cua', 'bun-thang', 'bun-mam', 'bun-chay');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85' WHERE slug IN ('mi-quang', 'cao-lau', 'hu-tieu-nam-vang', 'mi-cay-7-cap-do', 'mi-goi-cao-cap', 'ramen-nhat', 'pasta-sot-kem');

-- 🍚 RICE (com)
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85' WHERE slug IN ('com-tam-suon', 'com-van-phong', 'com-ga-hai-nam', 'com-ga-uc-nuong', 'com-hen', 'ca-kho-to', 'bibimbap', 'xoi-xeo', 'xoi-man');

-- 🥖 BÁNH MÌ + STREET
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1539252554935-80ea54bb1da7?w=1200&q=85' WHERE slug IN ('banh-mi-saigon');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=1200&q=85' WHERE slug IN ('banh-cuon', 'banh-xeo', 'banh-khot');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=85' WHERE slug IN ('banh-trang-cuon-thit-heo', 'banh-trang-tron', 'banh-beo', 'banh-gio');

-- 🥘 HOT POT + GRILL (lau, nuong, bbq)
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85' WHERE slug IN ('lau-mam', 'lau-thai', 'lau-thap-cam');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=85' WHERE slug IN ('bbq-han-quoc', 'nem-lui', 'bo-nuong-la-lot', 'ga-nuong-muoi-ot');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1635963662923-50d05e2b3eb1?w=1200&q=85' WHERE slug IN ('tokbokki');

-- 🐟 SEAFOOD
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=1200&q=85' WHERE slug IN ('sushi-combo');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1606756791613-be7f56dfa46e?w=1200&q=85' WHERE slug IN ('cha-ca-la-vong', 'banh-tom-ho-tay', 'oc-luoc');

-- 🍔 FAST FOOD WESTERN
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1200&q=85' WHERE slug IN ('pizza-bo-pho-mai');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=85' WHERE slug IN ('burger-ga');

-- 🥗 HEALTHY
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=85' WHERE slug IN ('salad-ca-hoi', 'oat-banana');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=1200&q=85' WHERE slug IN ('trung-chien-ca-chua');

-- 🥢 DIMSUM + ASIAN SNACK
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=1200&q=85' WHERE slug IN ('dimsum', 'hot-vit-lon', 'bot-chien');

-- 🍰 DESSERT
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=1200&q=85' WHERE slug IN ('che-ba-mau', 'che-khuc-bach', 'sua-chua-mit');

-- 🥤 DRINK
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85' WHERE slug IN ('tra-sua-tran-chau');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85' WHERE slug IN ('ca-phe-sua-da');
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1502740479091-635887520276?w=1200&q=85' WHERE slug IN ('nuoc-mia', 'sinh-to-bo');

-- 🍳 CHÁO (porridge / soup)
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1606471191009-63994c53433b?w=1200&q=85' WHERE slug IN ('chao-ga');

-- ============================================================================
-- Restaurants — use category-matched real photos
-- ============================================================================
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85' WHERE slug IN ('pho-le', 'pho-ly-quoc-su');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85'    WHERE slug IN ('com-tam-ba-ghien', 'quan-bui', 'quan-an-ngon');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=1200&q=85' WHERE slug IN ('bun-bo-ganh', 'bun-cha-huong-lien', 'bun-thang-ba-duc', 'bun-dau-trung-huong');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1200&q=85' WHERE slug IN ('pizza-4ps-le-thanh-ton', 'pizza-4ps-trang-tien');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1539252554935-80ea54bb1da7?w=1200&q=85' WHERE slug = 'banh-mi-huynh-hoa';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85'    WHERE slug IN ('lau-de-truong-dinh', 'lau-phan');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85' WHERE slug IN ('hu-tieu-hong-phat', 'sasin-mi-cay');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=1200&q=85'    WHERE slug IN ('banh-xeo-46a', 'banh-cuon-ba-hoanh');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85' WHERE slug IN ('highlands-coffee-ben-thanh', 'cong-ca-phe-nha-tho', 'highlands-ho-guom');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=85' WHERE slug = 'burger-bros';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=1200&q=85' WHERE slug = 'sushi-tei-vincom';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1606756791613-be7f56dfa46e?w=1200&q=85' WHERE slug IN ('quan-oc-dao', 'cha-ca-la-vong-restaurant');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=85' WHERE slug = 'saladbox';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85'    WHERE slug IN ('bobapop', 'ha-linh-tra-sua');
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=85'    WHERE slug IN ('bbq-garden', 'saigon-ut-ut');

SELECT 'foods updated' AS what, COUNT(*) AS rows FROM foods WHERE primary_image LIKE 'https://images.unsplash.com%';
SELECT 'restaurants updated' AS what, COUNT(*) AS rows FROM restaurants WHERE cover_image LIKE 'https://images.unsplash.com%';
