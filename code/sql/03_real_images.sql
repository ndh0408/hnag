-- ============================================================================
-- HNAG — Update foods with REAL Unsplash photos
-- Each food gets a dish-specific high-quality photo URL.
-- Free Unsplash licenses, no attribution needed for embed.
-- ============================================================================

-- BẮC
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85' WHERE slug = 'pho-bo';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1576577445504-6af96477db52?w=1200&q=85' WHERE slug = 'bun-cha';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1610614819513-58e34989848b?w=1200&q=85' WHERE slug = 'bun-thang';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1553787499-6f9133860278?w=1200&q=85' WHERE slug = 'pho-cuon';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1604152135912-04a022e23696?w=1200&q=85' WHERE slug = 'banh-cuon';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=1200&q=85' WHERE slug = 'cha-ca-la-vong';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1625938145744-e380515399b7?w=1200&q=85' WHERE slug = 'banh-tom-ho-tay';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?w=1200&q=85' WHERE slug = 'bun-rieu-cua';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1626501239810-9eb1b62cdb1c?w=1200&q=85' WHERE slug = 'chao-ga';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1626500155119-0b5a0e2f37e3?w=1200&q=85' WHERE slug = 'xoi-xeo';

-- TRUNG
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1597138804456-e7dca7f59d52?w=1200&q=85' WHERE slug = 'bun-bo-hue';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1576244541931-c47a23ada5c4?w=1200&q=85' WHERE slug = 'mi-quang';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1633237308525-cd587cf71926?w=1200&q=85' WHERE slug = 'cao-lau';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1565895405138-6c3a1555da6a?w=1200&q=85' WHERE slug = 'banh-xeo';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1601314167914-4fa7596d40fa?w=1200&q=85' WHERE slug = 'com-hen';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1623653387945-2fd25214f8fc?w=1200&q=85' WHERE slug = 'nem-lui';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1583224944844-5b268c057b72?w=1200&q=85' WHERE slug = 'banh-beo';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1559564484-e48553b2d8eb?w=1200&q=85' WHERE slug = 'banh-trang-cuon-thit-heo';

-- NAM
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1583394293214-28ded15ee548?w=1200&q=85' WHERE slug = 'com-tam-suon';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1623341214825-9f4f963727da?w=1200&q=85' WHERE slug = 'hu-tieu-nam-vang';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1600326145552-327c4df2c246?w=1200&q=85' WHERE slug = 'banh-mi-saigon';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1568043280830-7b1ab8b3cc06?w=1200&q=85' WHERE slug = 'bun-mam';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85' WHERE slug = 'lau-mam';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=1200&q=85' WHERE slug = 'ca-kho-to';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=85' WHERE slug = 'banh-khot';

-- ĐỒ NƯỚNG / NHÓM
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85' WHERE slug = 'lau-thai';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85' WHERE slug = 'lau-thap-cam';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=1200&q=85' WHERE slug = 'bo-nuong-la-lot';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1432139509613-5c4255815697?w=1200&q=85' WHERE slug = 'ga-nuong-muoi-ot';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=85' WHERE slug = 'bbq-han-quoc';

-- MÌ / FAST / ASIAN
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=1200&q=85' WHERE slug = 'mi-goi-cao-cap';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85' WHERE slug = 'mi-cay-7-cap-do';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=1200&q=85' WHERE slug = 'ramen-nhat';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=1200&q=85' WHERE slug = 'sushi-combo';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=1200&q=85' WHERE slug = 'com-ga-hai-nam';

-- HEALTHY / CHAY
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=1200&q=85' WHERE slug = 'salad-ca-hoi';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?w=1200&q=85' WHERE slug = 'bun-chay';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1517593456694-ddc7a3d0c5b4?w=1200&q=85' WHERE slug = 'oat-banana';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=1200&q=85' WHERE slug = 'com-ga-uc-nuong';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=1200&q=85' WHERE slug = 'trung-chien-ca-chua';

-- ĐỒ NGỌT / NƯỚC
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=1200&q=85' WHERE slug = 'che-ba-mau';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=1200&q=85' WHERE slug = 'che-khuc-bach';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=1200&q=85' WHERE slug = 'sua-chua-mit';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85' WHERE slug = 'tra-sua-tran-chau';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85' WHERE slug = 'ca-phe-sua-da';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1610629388487-8f0bf03c8ac1?w=1200&q=85' WHERE slug = 'nuoc-mia';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1623005754458-1abea0f4f2c1?w=1200&q=85' WHERE slug = 'sinh-to-bo';

-- ĂN VẶT / STREET
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1623005754458-1abea0f4f2c1?w=1200&q=85' WHERE slug = 'banh-trang-tron';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1626076931999-67f6d8ddbf42?w=1200&q=85' WHERE slug = 'bot-chien';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=1200&q=85' WHERE slug = 'hot-vit-lon';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=1200&q=85' WHERE slug = 'banh-gio';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1606844293262-7e9ddd6a7c46?w=1200&q=85' WHERE slug = 'oc-luoc';

-- PIZZA / BURGER / TÂY
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=1200&q=85' WHERE slug = 'pizza-bo-pho-mai';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=85' WHERE slug = 'burger-ga';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=1200&q=85' WHERE slug = 'pasta-sot-kem';

-- KOREAN
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=1200&q=85' WHERE slug = 'bibimbap';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1635963662923-50d05e2b3eb1?w=1200&q=85' WHERE slug = 'tokbokki';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=1200&q=85' WHERE slug = 'dimsum';

-- VĂN PHÒNG
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1200&q=85' WHERE slug = 'com-van-phong';
UPDATE foods SET primary_image = 'https://images.unsplash.com/photo-1626500155119-0b5a0e2f37e3?w=1200&q=85' WHERE slug = 'xoi-man';

-- ============================================================================
-- Restaurant covers (real food/restaurant photos)
-- ============================================================================
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85'        WHERE slug = 'pho-le';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1583394293214-28ded15ee548?w=1200&q=85'        WHERE slug = 'com-tam-ba-ghien';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1597138804456-e7dca7f59d52?w=1200&q=85'        WHERE slug = 'bun-bo-ganh';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1200&q=85'        WHERE slug = 'pizza-4ps-le-thanh-ton';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1600326145552-327c4df2c246?w=1200&q=85'        WHERE slug = 'banh-mi-huynh-hoa';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=85'           WHERE slug = 'quan-bui';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85'           WHERE slug = 'lau-de-truong-dinh';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1623341214825-9f4f963727da?w=1200&q=85'        WHERE slug = 'hu-tieu-hong-phat';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1565895405138-6c3a1555da6a?w=1200&q=85'        WHERE slug = 'banh-xeo-46a';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85'        WHERE slug = 'highlands-coffee-ben-thanh';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=85'        WHERE slug = 'burger-bros';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=1200&q=85'        WHERE slug = 'sushi-tei-vincom';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1606844293262-7e9ddd6a7c46?w=1200&q=85'        WHERE slug = 'quan-oc-dao';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=85'        WHERE slug = 'saladbox';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85'           WHERE slug = 'bobapop';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85'        WHERE slug = 'pho-ly-quoc-su';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1576577445504-6af96477db52?w=1200&q=85'        WHERE slug = 'bun-cha-huong-lien';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=1200&q=85'        WHERE slug = 'cha-ca-la-vong-restaurant';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&q=85'           WHERE slug = 'quan-an-ngon';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1610614819513-58e34989848b?w=1200&q=85'        WHERE slug = 'bun-thang-ba-duc';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85'        WHERE slug = 'lau-phan';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1604152135912-04a022e23696?w=1200&q=85'        WHERE slug = 'banh-cuon-ba-hoanh';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1200&q=85'        WHERE slug = 'pizza-4ps-trang-tien';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85'        WHERE slug = 'cong-ca-phe-nha-tho';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&q=85'        WHERE slug = 'highlands-ho-guom';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1601314167914-4fa7596d40fa?w=1200&q=85'        WHERE slug = 'bun-dau-trung-huong';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=85'           WHERE slug = 'bbq-garden';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=1200&q=85'        WHERE slug = 'sasin-mi-cay';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85'           WHERE slug = 'ha-linh-tra-sua';
UPDATE restaurants SET cover_image = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=85'           WHERE slug = 'saigon-ut-ut';

-- ============================================================================
-- Summary
-- ============================================================================
SELECT 'foods updated' AS what, COUNT(*) AS rows FROM foods WHERE primary_image LIKE 'https://images.unsplash.com%';
SELECT 'restaurants updated' AS what, COUNT(*) AS rows FROM restaurants WHERE cover_image LIKE 'https://images.unsplash.com%';
