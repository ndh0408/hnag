-- ============================================================================
-- HNAG — SEED DATA
-- 60 Vietnamese foods, 30 restaurants (HCM + Hà Nội), achievements, quests
-- Idempotent — uses INSERT ... ON CONFLICT DO NOTHING
-- ============================================================================

-- ============================================================================
-- ACHIEVEMENTS
-- ============================================================================
INSERT INTO achievements (id, code, name_vi, name_en, description, tier, xp_reward, criteria) VALUES
('a1000000-0000-0000-0000-000000000001','first_review',         'Lần đầu review',       'First Review',        'Đăng review đầu tiên của bạn',                'common',   50,  '{"reviews": 1}'),
('a1000000-0000-0000-0000-000000000002','ten_dishes',           '10 món đã thử',        '10 Dishes Tried',     'Thử 10 món khác nhau',                        'common',   100, '{"unique_foods": 10}'),
('a1000000-0000-0000-0000-000000000003','first_cook',           'Đầu bếp tập sự',       'First Cook',          'Nấu món đầu tiên với HNAG',                   'common',   80,  '{"cooked": 1}'),
('a1000000-0000-0000-0000-000000000004','first_friend',         'Có bạn ăn cùng',       'First Friend',        'Kết bạn với 1 foodie',                        'common',   60,  '{"friends": 1}'),
('a1000000-0000-0000-0000-000000000005','first_group_vote',     'Quyết định nhóm',      'First Group Vote',    'Tham gia 1 nhóm vote',                        'common',   70,  '{"group_votes": 1}'),
('a1000000-0000-0000-0000-000000000006','vua_pho',              'Vua Phở',              'Phở King',            'Review 30 quán phở',                          'rare',     500, '{"reviews_cuisine": {"pho": 30}}'),
('a1000000-0000-0000-0000-000000000007','dem_khuya',            'Cú đêm',               'Night Owl',           'Đặt món sau 11h × 10 lần',                    'rare',     400, '{"late_orders": 10}'),
('a1000000-0000-0000-0000-000000000008','tham_hiem_q1',         'Thám hiểm Quận 1',     'Q1 Explorer',         'Check-in 25 quán tại Q1 TP.HCM',              'rare',     350, '{"checkins_district": {"Quận 1": 25}}'),
('a1000000-0000-0000-0000-000000000009','three_regions',        'Đi 3 miền',            '3 Regions Tour',      'Thử món Bắc + Trung + Nam',                   'epic',     600, '{"regions": ["bac","trung","nam"]}'),
('a1000000-0000-0000-0000-000000000010','centurion',            'Foodie Centurion',     'Foodie Centurion',    '100 ngày streak liên tục',                    'legendary',2000,'{"streak_decide": 100}'),
('a1000000-0000-0000-0000-000000000011','couple_one_year',      'Couple 1 năm',         '1-Year Couple',       'Couple gắn bó 1 năm trên app',                'epic',     800, '{"couple_days": 365}'),
('a1000000-0000-0000-0000-000000000012','tastemaker',           'Tastemaker',           'Tastemaker',          'Đạt 100K followers',                          'legendary',5000,'{"followers": 100000}'),
('a1000000-0000-0000-0000-000000000013','trusted_reviewer',     'Reviewer tin cậy',     'Trusted Reviewer',    '95% review verified, 4.5+ trung bình',        'epic',     1000,'{"verified_pct": 0.95, "avg_rating": 4.5}'),
('a1000000-0000-0000-0000-000000000014','fifty_restaurants',    '50 quán khám phá',     '50 Restaurants',      'Check-in 50 quán khác nhau',                  'rare',     500, '{"unique_restaurants": 50}'),
('a1000000-0000-0000-0000-000000000015','cook_week',            'Tuần đầu bếp',         'Cook Week',           'Nấu 7 ngày liên tục',                         'rare',     400, '{"cook_streak": 7}')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- DAILY QUESTS (template — runtime creates per-day instances)
-- ============================================================================
INSERT INTO daily_quests (id, code, name_vi, description, xp_reward, criteria, active_date) VALUES
('11111111-0000-0000-0000-000000000001', 'save_new',           'Lưu 1 món mới',                  'Lưu 1 món bạn chưa từng lưu',                                 10, '{"action":"save","unique":true,"count":1}',           CURRENT_DATE),
('11111111-0000-0000-0000-000000000002', 'review_today',       'Review 1 quán',                  'Đăng 1 review hôm nay',                                       25, '{"action":"review","count":1}',                       CURRENT_DATE),
('11111111-0000-0000-0000-000000000003', 'explore_near',       'Khám phá 1 quán gần bạn',        'Check-in tại 1 quán mới trong khu vực',                       25, '{"action":"checkin","new_to_user":true,"count":1}',   CURRENT_DATE),
('11111111-0000-0000-0000-000000000004', 'comment_review',     'Bình luận 1 review',             'Tương tác social',                                            15, '{"action":"comment","count":1}',                      CURRENT_DATE),
('11111111-0000-0000-0000-000000000005', 'group_vote',         'Vote trong nhóm',                'Tham gia 1 cuộc vote nhóm',                                   20, '{"action":"poll_vote","count":1}',                    CURRENT_DATE),
('11111111-0000-0000-0000-000000000006', 'healthy_today',      'Ăn 1 món healthy',               'Chọn món có tag healthy hôm nay',                             20, '{"action":"order","tag":"healthy","count":1}',        CURRENT_DATE),
('11111111-0000-0000-0000-000000000007', 'cook_at_home',       'Nấu ăn ở nhà',                   'Hoàn thành 1 công thức',                                      30, '{"action":"cooked","count":1}',                       CURRENT_DATE)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- FOODS — 60 món Việt phổ biến
-- ============================================================================
INSERT INTO foods (id, name_vi, name_en, slug, description, primary_image, origin_region, cuisine, category, meal_types, diet_tags, flavor_tags, mood_tags, vibe_tags, avg_calories, avg_price_vnd, cook_time_min, difficulty, spicy_level, sweet_level, allergens) VALUES
-- BẮC
('f0000000-0000-0000-0000-000000000001','Phở bò',                          'Pho Bo',                'pho-bo',                          'Phở truyền thống Hà Nội với nước dùng đậm đà',           '/img/food/pho-bo.jpg',                'bac','vietnamese','noodle',ARRAY['breakfast','lunch']::meal_type[],ARRAY['gluten'],ARRAY['umami','warm'],ARRAY['comfort','sad','rainy'],ARRAY['truyền thống'],450,55000,30,3,1,0,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000002','Bún chả',                         'Bun Cha',               'bun-cha',                         'Thịt nướng + bún + nước chấm chua ngọt',                  '/img/food/bun-cha.jpg',               'bac','vietnamese','grill',ARRAY['lunch']::meal_type[],ARRAY[]::TEXT[],ARRAY['sweet','salty','umami'],ARRAY['chill','vui'],ARRAY['truyền thống','đông khách'],520,55000,25,3,1,2,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000003','Bún thang',                       'Bun Thang',             'bun-thang',                       'Bún tinh tế của Hà Nội với 10+ topping',                  '/img/food/bun-thang.jpg',             'bac','vietnamese','noodle',ARRAY['breakfast','lunch']::meal_type[],ARRAY['gluten'],ARRAY['umami'],ARRAY['chill'],ARRAY['tinh tế'],380,65000,40,4,0,0,ARRAY['gluten','egg']),
('f0000000-0000-0000-0000-000000000004','Phở cuốn',                        'Pho Cuon',              'pho-cuon',                        'Bánh phở cuốn thịt bò',                                   '/img/food/pho-cuon.jpg',              'bac','vietnamese','street',ARRAY['snack','lunch']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','umami'],ARRAY['chill','vui'],ARRAY['ăn vặt'],280,50000,20,2,0,1,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000005','Bánh cuốn',                       'Banh Cuon',             'banh-cuon',                       'Bánh tráng mỏng cuốn thịt heo nấm',                       '/img/food/banh-cuon.jpg',             'bac','vietnamese','street',ARRAY['breakfast']::meal_type[],ARRAY['gluten'],ARRAY['umami','salty'],ARRAY['chill'],ARRAY['truyền thống'],320,45000,30,4,0,1,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000006','Chả cá Lã Vọng',                  'Cha Ca La Vong',        'cha-ca-la-vong',                  'Cá lăng tẩm nghệ + thì là, đặc sản HN',                  '/img/food/cha-ca.jpg',                'bac','vietnamese','seafood',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami','tinh tế'],ARRAY['vui','đi date'],ARRAY['sang chảnh','date'],480,180000,40,3,1,0,ARRAY['fish']),
('f0000000-0000-0000-0000-000000000007','Bánh tôm Hồ Tây',                 'Banh Tom Ho Tay',       'banh-tom-ho-tay',                 'Tôm chiên giòn + bánh xốp',                              '/img/food/banh-tom.jpg',              'bac','vietnamese','street',ARRAY['snack']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','crispy'],ARRAY['chill','vui'],ARRAY['ăn vặt'],380,60000,25,3,0,0,ARRAY['shellfish']),
('f0000000-0000-0000-0000-000000000008','Bún riêu cua',                    'Bun Rieu',              'bun-rieu-cua',                    'Bún + riêu cua + cà chua chua ngọt',                     '/img/food/bun-rieu.jpg',              'bac','vietnamese','noodle',ARRAY['lunch']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['sour','umami'],ARRAY['comfort','sad'],ARRAY['truyền thống'],420,50000,35,3,1,1,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000009','Cháo gà',                         'Cháo gà',               'chao-ga',                         'Cháo gà ấm bụng cho ngày mưa',                           '/img/food/chao-ga.jpg',               'bac','vietnamese','soup',ARRAY['breakfast','latenight']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami','warm'],ARRAY['sad','sick','rainy','latenight'],ARRAY['comfort'],380,40000,40,2,0,0,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000010','Xôi xéo',                         'Xoi Xeo',               'xoi-xeo',                         'Xôi đậu xanh + hành phi giòn',                           '/img/food/xoi-xeo.jpg',               'bac','vietnamese','rice',ARRAY['breakfast']::meal_type[],ARRAY['vegetarian'],ARRAY['salty','umami'],ARRAY['chill','rush'],ARRAY['truyền thống','nhanh'],520,25000,15,2,0,0,ARRAY[]::TEXT[]),

-- TRUNG
('f0000000-0000-0000-0000-000000000011','Bún bò Huế',                      'Bun Bo Hue',            'bun-bo-hue',                      'Đậm đà, cay nồng, đặc trưng Huế',                        '/img/food/bun-bo-hue.jpg',            'trung','vietnamese','noodle',ARRAY['breakfast','lunch']::meal_type[],ARRAY['gluten'],ARRAY['spicy','umami'],ARRAY['comfort','rainy'],ARRAY['truyền thống','đông khách'],480,55000,40,3,4,0,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000012','Mì Quảng',                        'Mi Quang',              'mi-quang',                        'Mì Quảng tôm thịt nước lèo cô đặc',                       '/img/food/mi-quang.jpg',              'trung','vietnamese','noodle',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['umami','salty'],ARRAY['chill','vui'],ARRAY['truyền thống'],460,50000,40,3,2,0,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000013','Cao lầu',                         'Cao Lau',               'cao-lau',                         'Đặc sản Hội An',                                          '/img/food/cao-lau.jpg',               'trung','vietnamese','noodle',ARRAY['lunch']::meal_type[],ARRAY['gluten'],ARRAY['umami','crispy'],ARRAY['vui','khám phá'],ARRAY['truyền thống'],440,60000,40,4,1,0,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000014','Bánh xèo',                        'Banh Xeo',              'banh-xeo',                        'Bánh xèo giòn rụm cuốn rau sống',                         '/img/food/banh-xeo.jpg',              'trung','vietnamese','street',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['crispy','salty'],ARRAY['chill','vui'],ARRAY['truyền thống','đông khách'],520,55000,30,3,0,1,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000015','Cơm hến',                         'Com Hen',               'com-hen',                         'Đặc sản Huế bình dân',                                    '/img/food/com-hen.jpg',               'trung','vietnamese','rice',ARRAY['lunch','dinner']::meal_type[],ARRAY['shellfish'],ARRAY['umami','spicy'],ARRAY['chill','rush'],ARRAY['truyền thống','bình dân'],380,30000,25,3,3,0,ARRAY['shellfish']),
('f0000000-0000-0000-0000-000000000016','Nem lụi',                         'Nem Lui',               'nem-lui',                         'Thịt nướng xiên que cuốn bánh tráng',                     '/img/food/nem-lui.jpg',               'trung','vietnamese','grill',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','crispy'],ARRAY['chill','vui'],ARRAY['đông khách'],460,60000,30,3,0,1,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000017','Bánh bèo',                        'Banh Beo',              'banh-beo',                        'Bánh nhỏ tinh tế của Huế',                                '/img/food/banh-beo.jpg',              'trung','vietnamese','snack',ARRAY['snack']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['umami'],ARRAY['chill','tinh tế'],ARRAY['tinh tế'],240,40000,30,3,0,0,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000018','Bánh tráng cuốn thịt heo',        'Banh Trang Cuon',       'banh-trang-cuon-thit-heo',        'Thịt heo cuốn bánh tráng Đà Nẵng',                        '/img/food/btct.jpg',                  'trung','vietnamese','street',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten'],ARRAY['salty','fresh'],ARRAY['chill','vui'],ARRAY['truyền thống'],380,65000,15,2,0,0,ARRAY['gluten']),

-- NAM
('f0000000-0000-0000-0000-000000000019','Cơm tấm sườn',                    'Com Tam Suon',          'com-tam-suon',                    'Cơm tấm sườn nướng + bì + chả',                           '/img/food/com-tam.jpg',               'nam','vietnamese','rice',ARRAY['lunch','dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','sweet'],ARRAY['comfort','lonely'],ARRAY['bình dân','truyền thống'],680,55000,25,2,0,2,ARRAY['egg']),
('f0000000-0000-0000-0000-000000000020','Hủ tiếu Nam Vang',                'Hu Tieu Nam Vang',      'hu-tieu-nam-vang',                'Sợi hủ tiếu + tôm thịt + nước dùng trong',                '/img/food/hu-tieu.jpg',               'nam','vietnamese','noodle',ARRAY['breakfast','lunch']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['umami'],ARRAY['comfort'],ARRAY['truyền thống'],440,55000,30,3,0,0,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000021','Bánh mì Sài Gòn',                 'Banh Mi Saigon',        'banh-mi-saigon',                  'Bánh mì giòn thịt nguội pate',                            '/img/food/banh-mi.jpg',               'nam','vietnamese','street',ARRAY['breakfast','snack','lunch','latenight']::meal_type[],ARRAY['gluten'],ARRAY['salty','crispy'],ARRAY['rush','latenight'],ARRAY['nhanh','bình dân'],500,30000,5,1,0,1,ARRAY['gluten','egg']),
('f0000000-0000-0000-0000-000000000022','Bún mắm',                         'Bun Mam',               'bun-mam',                         'Bún mắm cá miền Tây',                                     '/img/food/bun-mam.jpg',               'nam','vietnamese','noodle',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','fish'],ARRAY['umami','strong'],ARRAY['chill','khám phá'],ARRAY['truyền thống'],500,55000,40,3,2,0,ARRAY['gluten','fish']),
('f0000000-0000-0000-0000-000000000023','Lẩu mắm',                         'Lau Mam',               'lau-mam',                         'Lẩu mắm cá rau ngon',                                     '/img/food/lau-mam.jpg',               'nam','vietnamese','soup',ARRAY['dinner']::meal_type[],ARRAY['fish'],ARRAY['umami','strong'],ARRAY['vui','chill'],ARRAY['đông khách','gia đình'],520,180000,60,3,2,0,ARRAY['fish']),
('f0000000-0000-0000-0000-000000000024','Cá kho tộ',                       'Ca Kho To',             'ca-kho-to',                       'Cá kho mặn ngọt ăn với cơm',                              '/img/food/ca-kho-to.jpg',             'nam','vietnamese','rice',ARRAY['lunch','dinner']::meal_type[],ARRAY['fish'],ARRAY['salty','sweet'],ARRAY['comfort','family'],ARRAY['gia đình'],400,80000,45,3,1,2,ARRAY['fish']),
('f0000000-0000-0000-0000-000000000025','Bánh khọt',                       'Banh Khot',             'banh-khot',                       'Bánh khọt Vũng Tàu',                                      '/img/food/banh-khot.jpg',             'nam','vietnamese','street',ARRAY['lunch','snack']::meal_type[],ARRAY['shellfish'],ARRAY['crispy','salty'],ARRAY['chill','vui'],ARRAY['truyền thống'],360,50000,30,3,0,0,ARRAY['shellfish']),

-- ĐỒ NƯỚNG / NHẬU / NHÓM
('f0000000-0000-0000-0000-000000000026','Lẩu Thái',                        'Lau Thai',              'lau-thai',                        'Lẩu Thái chua cay đặc trưng',                             '/img/food/lau-thai.jpg',              'other','thai','soup',ARRAY['dinner']::meal_type[],ARRAY['shellfish'],ARRAY['spicy','sour'],ARRAY['vui','stress','group'],ARRAY['nhóm','đông khách'],580,120000,60,2,4,1,ARRAY['shellfish']),
('f0000000-0000-0000-0000-000000000027','Lẩu thập cẩm',                    'Lau Thap Cam',          'lau-thap-cam',                    'Lẩu nhiều loại cho cả nhóm',                              '/img/food/lau-thap-cam.jpg',          'other','vietnamese','soup',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami','warm'],ARRAY['vui','group','rainy'],ARRAY['nhóm','gia đình'],600,180000,60,2,2,1,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000028','Bò nướng lá lốt',                 'Bo Nuong La Lot',       'bo-nuong-la-lot',                 'Bò gói lá lốt nướng thơm',                                '/img/food/bo-la-lot.jpg',             'nam','vietnamese','grill',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','umami'],ARRAY['vui','group'],ARRAY['nhóm'],460,90000,30,2,0,1,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000029','Gà nướng muối ớt',                'Ga Nuoi Muoi Ot',       'ga-nuong-muoi-ot',                'Gà nướng cay tê',                                         '/img/food/ga-nuong-muoi-ot.jpg',      'other','vietnamese','grill',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['spicy','salty'],ARRAY['vui','stress'],ARRAY['nhậu','nhóm'],580,180000,45,2,4,0,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000030','BBQ Hàn Quốc',                    'Korean BBQ',            'bbq-han-quoc',                    'Thịt nướng kiểu Hàn',                                     '/img/food/bbq-han.jpg',               'intl','korean','grill',ARRAY['dinner']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','umami'],ARRAY['vui','date','group'],ARRAY['date','nhóm','sang chảnh'],720,250000,60,2,1,2,ARRAY[]::TEXT[]),

-- MÌ / FAST / RUSH
('f0000000-0000-0000-0000-000000000031','Mì gói cao cấp',                  'Premium Instant Noodle','mi-goi-cao-cap',                  'Mì gói nâng cấp ngon hơn',                                '/img/food/mi-goi.jpg',                'other','vietnamese','noodle',ARRAY['latenight','snack']::meal_type[],ARRAY['gluten'],ARRAY['umami'],ARRAY['latenight','lonely','lazy'],ARRAY['nhanh'],420,15000,5,1,1,0,ARRAY['gluten','egg']),
('f0000000-0000-0000-0000-000000000032','Mì cay 7 cấp độ',                 'Spicy Ramen 7 Levels',  'mi-cay-7-cap-do',                 'Mì cay thử thách',                                        '/img/food/mi-cay.jpg',                'intl','korean','noodle',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['spicy'],ARRAY['stress','vui','group'],ARRAY['nhóm','thử thách'],560,90000,25,2,5,0,ARRAY['gluten','shellfish']),
('f0000000-0000-0000-0000-000000000033','Ramen Nhật',                      'Ramen',                 'ramen-nhat',                      'Ramen miso thịt heo',                                     '/img/food/ramen.jpg',                 'intl','japanese','noodle',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','egg'],ARRAY['umami','salty'],ARRAY['comfort','rainy'],ARRAY['date'],540,150000,40,3,1,0,ARRAY['gluten','egg']),
('f0000000-0000-0000-0000-000000000034','Sushi combo',                     'Sushi Combo',           'sushi-combo',                     'Combo sushi 16 miếng',                                    '/img/food/sushi.jpg',                 'intl','japanese','seafood',ARRAY['lunch','dinner']::meal_type[],ARRAY['fish'],ARRAY['umami','fresh'],ARRAY['date','vui'],ARRAY['date','sang chảnh'],560,250000,30,3,0,0,ARRAY['fish']),
('f0000000-0000-0000-0000-000000000035','Cơm gà Hải Nam',                  'Hainanese Chicken Rice','com-ga-hai-nam',                  'Cơm gà luộc nước dùng',                                   '/img/food/com-ga.jpg',                'intl','chinese','rice',ARRAY['lunch']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami'],ARRAY['comfort','rush'],ARRAY['bình dân','nhanh'],580,55000,30,2,0,0,ARRAY[]::TEXT[]),

-- HEALTHY / CHAY
('f0000000-0000-0000-0000-000000000036','Salad cá hồi',                    'Salmon Salad',          'salad-ca-hoi',                    'Salad rau + cá hồi nướng',                                '/img/food/salmon-salad.jpg',          'intl','western','vegetarian',ARRAY['lunch']::meal_type[],ARRAY['fish'],ARRAY['fresh','umami'],ARRAY['healthy','clean'],ARRAY['healthy','sang chảnh'],380,120000,15,2,0,0,ARRAY['fish']),
('f0000000-0000-0000-0000-000000000037','Bún chay',                        'Vegan Noodle',          'bun-chay',                        'Bún chay rau củ',                                         '/img/food/bun-chay.jpg',              'nam','vietnamese','noodle',ARRAY['lunch']::meal_type[],ARRAY['vegetarian','vegan','gluten'],ARRAY['umami','fresh'],ARRAY['clean','peaceful'],ARRAY['healthy'],360,40000,30,2,0,0,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000038','Yến mạch chuối hạnh nhân',        'Banana Oat',            'oat-banana',                      'Bữa sáng healthy 5 phút',                                 '/img/food/oat-banana.jpg',            'intl','western','snack',ARRAY['breakfast']::meal_type[],ARRAY['vegetarian','gluten'],ARRAY['sweet','umami'],ARRAY['clean','rush'],ARRAY['healthy','nhanh'],320,45000,5,1,0,3,ARRAY['gluten','nut']),
('f0000000-0000-0000-0000-000000000039','Cơm gà ức nướng',                 'Grilled Chicken Rice',  'com-ga-uc-nuong',                 'Cơm ức gà nướng salad — eat clean',                       '/img/food/com-ga-uc.jpg',             'other','vietnamese','rice',ARRAY['lunch','dinner']::meal_type[],ARRAY['high_protein'],ARRAY['salty','umami'],ARRAY['clean'],ARRAY['healthy','gym'],520,70000,25,2,0,0,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000040','Trứng chiên cà chua',             'Egg Tomato',            'trung-chien-ca-chua',             'Món nấu nhanh tại nhà',                                   '/img/food/trung-ca-chua.jpg',         'nam','vietnamese','rice',ARRAY['lunch','dinner']::meal_type[],ARRAY['vegetarian'],ARRAY['umami','sweet'],ARRAY['comfort','rush'],ARRAY['gia đình','nhanh'],320,15000,15,1,0,1,ARRAY['egg']),

-- ĐỒ NGỌT / TRÁNG MIỆNG / NƯỚC UỐNG
('f0000000-0000-0000-0000-000000000041','Chè ba màu',                      'Three-color Sweet Soup','che-ba-mau',                      'Chè đậu xanh đậu đỏ thạch',                               '/img/food/che-ba-mau.jpg',            'nam','vietnamese','dessert',ARRAY['snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet'],ARRAY['comfort','sad'],ARRAY['ăn vặt'],280,25000,15,2,0,5,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000042','Chè khúc bạch',                   'Chè Khúc Bạch',         'che-khuc-bach',                   'Chè khúc bạch mát lạnh',                                  '/img/food/che-khuc-bach.jpg',         'bac','vietnamese','dessert',ARRAY['snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet','cool'],ARRAY['chill','vui'],ARRAY['ăn vặt','hè'],240,30000,20,2,0,4,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000043','Sữa chua mít',                    'Yogurt Jackfruit',      'sua-chua-mit',                    'Sữa chua + mít + đậu phộng',                              '/img/food/sua-chua-mit.jpg',          'bac','vietnamese','dessert',ARRAY['snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet','cool'],ARRAY['chill','hot'],ARRAY['ăn vặt'],260,30000,5,1,0,4,ARRAY['dairy','nut']),
('f0000000-0000-0000-0000-000000000044','Trà sữa trân châu',               'Bubble Tea',            'tra-sua-tran-chau',               'Trà sữa truyền thống',                                    '/img/food/tra-sua.jpg',               'intl','taiwanese','drink',ARRAY['snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet'],ARRAY['stress','chill','vui'],ARRAY['Gen Z'],340,55000,10,1,0,5,ARRAY['dairy','gluten']),
('f0000000-0000-0000-0000-000000000045','Cà phê sữa đá',                   'Vietnamese Iced Coffee','ca-phe-sua-da',                   'Cà phê đặc trưng Việt',                                   '/img/food/ca-phe-sua-da.jpg',         'nam','vietnamese','drink',ARRAY['breakfast','snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet','strong'],ARRAY['rush','chill'],ARRAY['truyền thống'],180,25000,5,1,0,4,ARRAY['dairy']),
('f0000000-0000-0000-0000-000000000046','Nước mía',                        'Sugarcane Juice',       'nuoc-mia',                        'Nước mía mát lạnh',                                       '/img/food/nuoc-mia.jpg',              'nam','vietnamese','drink',ARRAY['snack']::meal_type[],ARRAY['vegetarian','vegan'],ARRAY['sweet'],ARRAY['hot','chill'],ARRAY['bình dân'],180,15000,3,1,0,5,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000047','Sinh tố bơ',                      'Avocado Smoothie',      'sinh-to-bo',                      'Sinh tố bơ sữa đặc',                                      '/img/food/sinh-to-bo.jpg',            'nam','vietnamese','drink',ARRAY['snack']::meal_type[],ARRAY['vegetarian'],ARRAY['sweet','creamy'],ARRAY['chill','hot'],ARRAY['truyền thống'],320,30000,5,1,0,4,ARRAY['dairy']),

-- ĂN VẶT / STREET
('f0000000-0000-0000-0000-000000000048','Bánh tráng trộn',                 'Banh Trang Tron',       'banh-trang-tron',                 'Bánh tráng trộn Sài Gòn',                                 '/img/food/banh-trang-tron.jpg',       'nam','vietnamese','snack',ARRAY['snack','latenight']::meal_type[],ARRAY[]::TEXT[],ARRAY['salty','sour','spicy'],ARRAY['Gen Z','chill','latenight'],ARRAY['ăn vặt','Gen Z'],280,25000,10,1,3,1,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000049','Bột chiên',                       'Bot Chien',             'bot-chien',                       'Bột gạo chiên trứng',                                     '/img/food/bot-chien.jpg',             'nam','vietnamese','snack',ARRAY['snack','latenight']::meal_type[],ARRAY['gluten','egg'],ARRAY['crispy','salty'],ARRAY['latenight','chill'],ARRAY['ăn vặt','đêm khuya'],380,30000,15,2,0,0,ARRAY['gluten','egg']),
('f0000000-0000-0000-0000-000000000050','Hột vịt lộn',                     'Balut Egg',             'hot-vit-lon',                     'Trứng vịt lộn',                                           '/img/food/hot-vit-lon.jpg',           'nam','vietnamese','snack',ARRAY['snack','latenight']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami','salty'],ARRAY['latenight','khám phá'],ARRAY['ăn vặt','đêm khuya'],180,15000,10,1,0,0,ARRAY['egg']),
('f0000000-0000-0000-0000-000000000051','Bánh giò',                        'Banh Gio',              'banh-gio',                        'Bánh giò Hà Nội',                                         '/img/food/banh-gio.jpg',              'bac','vietnamese','street',ARRAY['breakfast','snack']::meal_type[],ARRAY['gluten'],ARRAY['salty'],ARRAY['rush','chill'],ARRAY['bình dân','nhanh'],260,20000,30,3,0,0,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000052','Ốc luộc',                         'Boiled Snails',         'oc-luoc',                         'Ốc luộc chấm mắm gừng',                                   '/img/food/oc-luoc.jpg',               'bac','vietnamese','seafood',ARRAY['snack','dinner']::meal_type[],ARRAY['shellfish'],ARRAY['umami','spicy'],ARRAY['vui','group','nhậu'],ARRAY['nhóm','nhậu'],260,80000,30,2,2,0,ARRAY['shellfish']),

-- PIZZA / BURGER / TÂY
('f0000000-0000-0000-0000-000000000053','Pizza bò phô mai',                'Beef Cheese Pizza',     'pizza-bo-pho-mai',                'Pizza đế giòn bò phô mai',                                '/img/food/pizza.jpg',                 'intl','western','fastfood',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','dairy'],ARRAY['salty','crispy'],ARRAY['vui','date','lazy'],ARRAY['date','Gen Z'],680,180000,30,2,0,2,ARRAY['gluten','dairy']),
('f0000000-0000-0000-0000-000000000054','Burger gà',                       'Chicken Burger',        'burger-ga',                       'Burger gà giòn',                                          '/img/food/burger.jpg',                'intl','western','fastfood',ARRAY['lunch','snack']::meal_type[],ARRAY['gluten'],ARRAY['salty','crispy'],ARRAY['rush','chill'],ARRAY['nhanh'],620,75000,15,1,0,1,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000055','Pasta sốt kem',                   'Creamy Pasta',          'pasta-sot-kem',                   'Pasta sốt kem nấm',                                       '/img/food/pasta.jpg',                 'intl','western','noodle',ARRAY['lunch','dinner']::meal_type[],ARRAY['gluten','dairy'],ARRAY['creamy','salty'],ARRAY['date','chill'],ARRAY['date'],720,120000,25,2,0,1,ARRAY['gluten','dairy']),

-- ASIAN
('f0000000-0000-0000-0000-000000000056','Cơm trộn Hàn Bibimbap',           'Bibimbap',              'bibimbap',                        'Cơm trộn rau thịt + trứng',                               '/img/food/bibimbap.jpg',              'intl','korean','rice',ARRAY['lunch']::meal_type[],ARRAY['egg'],ARRAY['umami','spicy'],ARRAY['clean','chill'],ARRAY['Gen Z','date'],560,90000,20,2,2,0,ARRAY['egg']),
('f0000000-0000-0000-0000-000000000057','Tokbokki',                        'Tteokbokki',            'tokbokki',                        'Bánh gạo Hàn cay ngọt',                                   '/img/food/tokbokki.jpg',              'intl','korean','snack',ARRAY['snack','dinner']::meal_type[],ARRAY['gluten'],ARRAY['spicy','sweet'],ARRAY['Gen Z','stress','vui'],ARRAY['Gen Z','date'],460,85000,20,2,4,3,ARRAY['gluten']),
('f0000000-0000-0000-0000-000000000058','Dimsum tổng hợp',                 'Dimsum',                'dimsum',                          'Combo dimsum 6 món',                                      '/img/food/dimsum.jpg',                'intl','chinese','snack',ARRAY['brunch']::meal_type[],ARRAY['gluten','shellfish'],ARRAY['umami','salty'],ARRAY['date','vui','family'],ARRAY['date','gia đình'],520,150000,30,3,0,0,ARRAY['gluten','shellfish']),

-- CƠM VĂN PHÒNG / NHANH
('f0000000-0000-0000-0000-000000000059','Cơm văn phòng',                   'Office Lunch Combo',    'com-van-phong',                   'Cơm trưa văn phòng đầy đủ',                               '/img/food/com-vp.jpg',                'nam','vietnamese','rice',ARRAY['lunch']::meal_type[],ARRAY[]::TEXT[],ARRAY['umami','salty'],ARRAY['rush','clean'],ARRAY['nhanh','bình dân'],680,45000,5,1,0,1,ARRAY[]::TEXT[]),
('f0000000-0000-0000-0000-000000000060','Xôi mặn',                         'Savory Sticky Rice',    'xoi-man',                         'Xôi pate trứng chà bông',                                 '/img/food/xoi-man.jpg',               'nam','vietnamese','rice',ARRAY['breakfast','snack','latenight']::meal_type[],ARRAY['egg'],ARRAY['salty','umami'],ARRAY['rush','latenight'],ARRAY['bình dân','nhanh','đêm khuya'],560,30000,10,2,0,1,ARRAY['egg'])
ON CONFLICT (slug) DO NOTHING;

-- Update popularity (Bayesian smoothing)
UPDATE foods SET
  popularity = (RANDOM() * 9000)::INT + 1000,
  trending_score = (RANDOM() * 100)::NUMERIC(6,2),
  rating_avg = (4.0 + RANDOM() * 0.9)::NUMERIC(3,2),
  rating_count = (50 + RANDOM() * 2000)::INT
WHERE rating_count = 0;

-- ============================================================================
-- RESTAURANTS — 30 quán (15 HCM, 15 Hà Nội)
-- ============================================================================
INSERT INTO restaurants (id, name, slug, description, city, district, ward, location, phone, price_level, cuisine_tags, feature_tags, vibe_tags, open_hours, is_verified, delivery_links) VALUES
-- HCM
('b0000000-0000-0000-0000-000000000001','Phở Lệ',                      'pho-le',                      'Phở Bắc nổi tiếng Q5',                       'TP.HCM','Quận 5','Phường 13', ST_GeogFromText('POINT(106.6645 10.7553)'),'02838550025',2,ARRAY['vietnamese','pho','bac'],ARRAY['ac','parking'],ARRAY['truyền thống','đông khách'], '{"mon":"6:00-22:00","tue":"6:00-22:00","wed":"6:00-22:00","thu":"6:00-22:00","fri":"6:00-22:00","sat":"6:00-22:00","sun":"6:00-22:00"}'::jsonb, TRUE,'{"grabfood":"https://food.grab.com/vn/pho-le","shopeefood":"https://shopee.vn/food/pho-le"}'::jsonb),
('b0000000-0000-0000-0000-000000000002','Cơm Tấm Ba Ghiền',            'com-tam-ba-ghien',            'Cơm tấm sườn nướng truyền thống',            'TP.HCM','Quận Phú Nhuận','Phường 4', ST_GeogFromText('POINT(106.6781 10.7977)'),'02839911211',1,ARRAY['vietnamese','com-tam','nam'],ARRAY['parking'],ARRAY['bình dân','đông khách'], '{"mon":"6:00-21:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000003','Bún Bò Gánh',                 'bun-bo-ganh',                 'Bún bò Huế nồng nàn',                        'TP.HCM','Quận 1','Phường Bến Thành', ST_GeogFromText('POINT(106.6940 10.7740)'),'02838223333',2,ARRAY['vietnamese','bun-bo-hue','trung'],ARRAY['ac'],ARRAY['truyền thống'], '{"mon":"7:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000004','Pizza 4P''s Lê Thánh Tôn',    'pizza-4ps-le-thanh-ton',      'Pizza Nhật–Ý cao cấp',                       'TP.HCM','Quận 1','Phường Bến Nghé', ST_GeogFromText('POINT(106.7000 10.7770)'),'02838222444',3,ARRAY['italian','japanese','pizza'],ARRAY['ac','wifi','parking','family'],ARRAY['date','sang chảnh'], '{"mon":"10:00-22:30"}'::jsonb, TRUE,'{"grabfood":"https://food.grab.com/vn/pizza-4ps"}'::jsonb),
('b0000000-0000-0000-0000-000000000005','Bánh Mì Huỳnh Hoa',           'banh-mi-huynh-hoa',           'Bánh mì biểu tượng Sài Gòn',                 'TP.HCM','Quận 1','Phường Đa Kao', ST_GeogFromText('POINT(106.6993 10.7868)'),'02838254388',2,ARRAY['vietnamese','banh-mi'],ARRAY[]::TEXT[],ARRAY['bình dân','nhanh','đông khách'], '{"mon":"6:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000006','Quán Bụi',                    'quan-bui',                    'Cơm gia đình Việt sang chảnh',               'TP.HCM','Quận 1','Phường Bến Nghé', ST_GeogFromText('POINT(106.7029 10.7791)'),'02838248729',3,ARRAY['vietnamese'],ARRAY['ac','wifi','parking'],ARRAY['date','sang chảnh','gia đình'], '{"mon":"10:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000007','Lẩu Dê Trương Định',          'lau-de-truong-dinh',          'Lẩu dê đặc sản đêm khuya',                   'TP.HCM','Quận 3','Phường 8', ST_GeogFromText('POINT(106.6843 10.7733)'),'02839306066',2,ARRAY['vietnamese','hot-pot'],ARRAY['parking'],ARRAY['nhóm','nhậu'], '{"mon":"17:00-2:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000008','Hủ Tiếu Hồng Phát',           'hu-tieu-hong-phat',           'Hủ tiếu Nam Vang chính gốc',                 'TP.HCM','Quận 3','Phường 9', ST_GeogFromText('POINT(106.6816 10.7775)'),'02839306121',2,ARRAY['vietnamese','hu-tieu'],ARRAY['ac'],ARRAY['truyền thống'], '{"mon":"6:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000009','Bánh Xèo 46A',                'banh-xeo-46a',                'Bánh xèo Đinh Công Tráng',                   'TP.HCM','Quận 1','Phường Tân Định', ST_GeogFromText('POINT(106.6900 10.7866)'),'02838241110',2,ARRAY['vietnamese','banh-xeo','trung'],ARRAY[]::TEXT[],ARRAY['truyền thống','đông khách'], '{"mon":"10:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000010','Highlands Coffee Bến Thành',  'highlands-coffee-ben-thanh',  'Cà phê chain Việt Nam',                      'TP.HCM','Quận 1','Phường Bến Thành', ST_GeogFromText('POINT(106.6975 10.7728)'),'02838999999',2,ARRAY['cafe','western'],ARRAY['ac','wifi'],ARRAY['chill','work'], '{"mon":"6:30-23:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000011','Burger Bros',                 'burger-bros',                 'Burger thủ công',                            'TP.HCM','Quận 1','Phường Bến Nghé', ST_GeogFromText('POINT(106.7011 10.7793)'),'02839102099',3,ARRAY['western','burger'],ARRAY['ac'],ARRAY['Gen Z','nhanh'], '{"mon":"10:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000012','Sushi Tei Vincom',            'sushi-tei-vincom',            'Sushi Nhật chuỗi cao cấp',                   'TP.HCM','Quận 1','Phường Bến Nghé', ST_GeogFromText('POINT(106.7022 10.7806)'),'02838219020',4,ARRAY['japanese','sushi'],ARRAY['ac','parking'],ARRAY['date','sang chảnh','gia đình'], '{"mon":"10:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000013','Quán Ốc Đào',                 'quan-oc-dao',                 'Ốc đặc sản nhậu Sài Gòn',                    'TP.HCM','Quận 4','Phường 8', ST_GeogFromText('POINT(106.7081 10.7589)'),'02838268269',2,ARRAY['vietnamese','seafood'],ARRAY[]::TEXT[],ARRAY['nhóm','nhậu','đêm khuya'], '{"mon":"15:00-2:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000014','Saladbox',                    'saladbox',                    'Salad healthy chain',                        'TP.HCM','Quận 1','Phường Bến Nghé', ST_GeogFromText('POINT(106.7027 10.7805)'),'02838221122',2,ARRAY['western','healthy'],ARRAY['ac','wifi'],ARRAY['healthy','clean','rush'], '{"mon":"7:00-22:00"}'::jsonb, TRUE,'{"grabfood":"#"}'::jsonb),
('b0000000-0000-0000-0000-000000000015','Tiệm Trà Sữa Bobapop',        'bobapop',                     'Trà sữa Gen Z',                              'TP.HCM','Quận 3','Phường 8', ST_GeogFromText('POINT(106.6842 10.7791)'),'02838225959',1,ARRAY['drink','bubble-tea'],ARRAY['ac'],ARRAY['Gen Z','chill'], '{"mon":"9:00-23:00"}'::jsonb, FALSE,'{}'::jsonb),
-- HÀ NỘI
('b0000000-0000-0000-0000-000000000016','Phở Lý Quốc Sư',              'pho-ly-quoc-su',              'Phở truyền thống Hà Nội',                    'Hà Nội','Hoàn Kiếm','Lý Quốc Sư', ST_GeogFromText('POINT(105.8504 21.0306)'),'02438252338',2,ARRAY['vietnamese','pho','bac'],ARRAY[]::TEXT[],ARRAY['truyền thống','đông khách'], '{"mon":"6:00-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000017','Bún Chả Hương Liên',          'bun-cha-huong-lien',          'Bún chả Obama HN',                           'Hà Nội','Hai Bà Trưng','Lê Văn Hưu', ST_GeogFromText('POINT(105.8528 21.0156)'),'02439431949',2,ARRAY['vietnamese','bun-cha','bac'],ARRAY[]::TEXT[],ARRAY['truyền thống','viral'], '{"mon":"9:00-21:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000018','Chả Cá Lã Vọng',              'cha-ca-la-vong-restaurant',   'Chả cá đặc sản',                             'Hà Nội','Hoàn Kiếm','Chả Cá', ST_GeogFromText('POINT(105.8493 21.0341)'),'02438253929',3,ARRAY['vietnamese','seafood'],ARRAY['ac'],ARRAY['date','sang chảnh','truyền thống'], '{"mon":"11:00-21:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000019','Quán Ăn Ngon Phan Đình Phùng','quan-an-ngon',                'Tinh hoa ẩm thực Việt',                      'Hà Nội','Ba Đình','Phan Đình Phùng', ST_GeogFromText('POINT(105.8390 21.0364)'),'02437342288',3,ARRAY['vietnamese'],ARRAY['ac','parking','family'],ARRAY['gia đình','sang chảnh'], '{"mon":"6:30-22:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000020','Bún Thang Bà Đức',            'bun-thang-ba-duc',            'Bún thang Cầu Gỗ',                           'Hà Nội','Hoàn Kiếm','Cầu Gỗ', ST_GeogFromText('POINT(105.8527 21.0322)'),'02438282288',2,ARRAY['vietnamese','noodle','bac'],ARRAY[]::TEXT[],ARRAY['truyền thống','tinh tế'], '{"mon":"7:00-14:00"}'::jsonb, FALSE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000021','Lẩu Phan',                    'lau-phan',                    'Lẩu hơi nồi đất nướng',                      'Hà Nội','Đống Đa','Tây Sơn', ST_GeogFromText('POINT(105.8224 21.0050)'),'02436421616',2,ARRAY['vietnamese','hot-pot'],ARRAY['ac','parking'],ARRAY['nhóm','gia đình'], '{"mon":"10:00-23:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000022','Bánh Cuốn Bà Hoành',          'banh-cuon-ba-hoanh',          'Bánh cuốn Tô Hiến Thành',                    'Hà Nội','Hai Bà Trưng','Tô Hiến Thành', ST_GeogFromText('POINT(105.8499 21.0190)'),'02439780202',1,ARRAY['vietnamese','banh-cuon','bac'],ARRAY[]::TEXT[],ARRAY['truyền thống','bình dân'], '{"mon":"6:00-12:00"}'::jsonb, FALSE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000023','Pizza 4P''s Tràng Tiền',      'pizza-4ps-trang-tien',        'Pizza Nhật–Ý',                               'Hà Nội','Hoàn Kiếm','Tràng Tiền', ST_GeogFromText('POINT(105.8546 21.0244)'),'02439393939',3,ARRAY['italian','japanese','pizza'],ARRAY['ac','wifi','parking'],ARRAY['date','sang chảnh'], '{"mon":"10:00-22:30"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000024','Cộng Cà Phê Nhà Thờ',         'cong-ca-phe-nha-tho',         'Cà phê retro Việt Nam',                      'Hà Nội','Hoàn Kiếm','Nhà Thờ', ST_GeogFromText('POINT(105.8493 21.0290)'),'0',1,ARRAY['cafe','vietnamese'],ARRAY['ac','wifi'],ARRAY['chill','date'], '{"mon":"7:00-23:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000025','Highlands Hồ Gươm',           'highlands-ho-guom',           'Highlands view hồ',                          'Hà Nội','Hoàn Kiếm','Lê Thái Tổ', ST_GeogFromText('POINT(105.8528 21.0285)'),'02438223344',2,ARRAY['cafe'],ARRAY['ac','wifi'],ARRAY['chill','work','view'], '{"mon":"6:30-23:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000026','Bún Đậu Mắm Tôm Trung Hương', 'bun-dau-trung-huong',         'Bún đậu mắm tôm cô Hương',                   'Hà Nội','Đống Đa','Phương Mai', ST_GeogFromText('POINT(105.8423 20.9947)'),'02438523252',1,ARRAY['vietnamese','street'],ARRAY[]::TEXT[],ARRAY['truyền thống','bình dân','viral'], '{"mon":"10:00-21:30"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000027','BBQ Garden',                  'bbq-garden',                  'BBQ Hàn rooftop',                            'Hà Nội','Cầu Giấy','Trần Duy Hưng', ST_GeogFromText('POINT(105.7986 21.0067)'),'02436368368',3,ARRAY['korean','bbq'],ARRAY['ac','parking','view'],ARRAY['date','nhóm','sang chảnh'], '{"mon":"11:00-23:00"}'::jsonb, TRUE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000028','Tiệm Mì Cay Sasin',           'sasin-mi-cay',                'Mì cay Hàn 7 cấp',                           'Hà Nội','Đống Đa','Chùa Bộc', ST_GeogFromText('POINT(105.8281 21.0067)'),'02436668800',1,ARRAY['korean','noodle'],ARRAY['ac'],ARRAY['Gen Z','nhóm','thử thách'], '{"mon":"10:00-22:00"}'::jsonb, FALSE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000029','Hà Linh Trà Sữa',             'ha-linh-tra-sua',             'Trà sữa local Hà Nội',                       'Hà Nội','Hai Bà Trưng','Đại Cồ Việt', ST_GeogFromText('POINT(105.8424 21.0050)'),'02439448844',1,ARRAY['drink','bubble-tea'],ARRAY['ac'],ARRAY['Gen Z'], '{"mon":"8:00-22:30"}'::jsonb, FALSE,'{}'::jsonb),
('b0000000-0000-0000-0000-000000000030','Saigon Ụt Ụt Hà Nội',         'saigon-ut-ut',                'BBQ sườn heo phong cách Mỹ',                 'Hà Nội','Hoàn Kiếm','Tràng Tiền', ST_GeogFromText('POINT(105.8556 21.0238)'),'02439351234',3,ARRAY['western','bbq'],ARRAY['ac','wifi','parking'],ARRAY['date','nhóm'], '{"mon":"11:00-22:00"}'::jsonb, TRUE,'{}'::jsonb)
ON CONFLICT (slug) DO NOTHING;

-- Restaurant live status defaults
INSERT INTO restaurant_live (restaurant_id, is_open, crowdedness, wait_minutes, recent_orders_24h)
SELECT id, TRUE, (RANDOM() * 0.7 + 0.1)::NUMERIC(3,2), (RANDOM() * 20)::INT, (50 + RANDOM() * 400)::INT
FROM restaurants
ON CONFLICT (restaurant_id) DO NOTHING;

-- Update aggregates
UPDATE restaurants SET
  popularity     = (RANDOM() * 9000)::INT + 1000,
  trending_score = (RANDOM() * 100)::NUMERIC(6,2),
  rating_avg     = (4.0 + RANDOM() * 0.9)::NUMERIC(3,2),
  rating_count   = (20 + RANDOM() * 1500)::INT
WHERE rating_count = 0;

-- ============================================================================
-- Sample menu_items: connect each restaurant to 3 signature foods (best-effort)
-- ============================================================================
INSERT INTO menu_items (restaurant_id, food_id, name, price_vnd, is_signature, position)
SELECT r.id, f.id, f.name_vi, f.avg_price_vnd, TRUE, ROW_NUMBER() OVER (PARTITION BY r.id)
FROM restaurants r
CROSS JOIN LATERAL (
  SELECT * FROM foods
  WHERE
    (r.cuisine_tags && foods.diet_tags)
    OR foods.cuisine = ANY(r.cuisine_tags)
    OR foods.category::text = ANY(r.cuisine_tags)
  ORDER BY foods.popularity DESC
  LIMIT 3
) f
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VIRAL DISHES (seed example: 3 trending now)
-- ============================================================================
INSERT INTO viral_dishes (id, food_id, dish_label, velocity_score, diversity_score, total_views, status) VALUES
('c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000018', 'Bánh tráng cuốn thịt heo Đà Nẵng', 92.5, 0.85, 2400000, 'rising'),
('c0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000057', 'Tokbokki Hàn ngon nhất', 86.2, 0.72, 1800000, 'rising'),
('c0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000048', 'Bánh tráng trộn streetfood', 78.0, 0.91, 1500000, 'rising')
ON CONFLICT DO NOTHING;

INSERT INTO viral_videos (viral_dish_id, platform, external_url, creator_handle, views, likes, posted_at) VALUES
('c0000000-0000-0000-0000-000000000001', 'tiktok', 'https://www.tiktok.com/@khoailangthang/video/x1', '@khoailangthang', 1200000, 85000, NOW() - INTERVAL '2 days'),
('c0000000-0000-0000-0000-000000000001', 'tiktok', 'https://www.tiktok.com/@anhsapchet/video/x2',    '@anhsapchet',    750000,  52000, NOW() - INTERVAL '3 days'),
('c0000000-0000-0000-0000-000000000002', 'tiktok', 'https://www.tiktok.com/@hanlinh/video/x3',       '@hanlinh',       900000,  68000, NOW() - INTERVAL '1 day')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- DEMO USERS (3 personas for testing)
-- ============================================================================
INSERT INTO users (id, phone, username, display_name, city, district, level, xp, is_premium, foodie_class) VALUES
('d0000000-0000-0000-0000-000000000001','+84901234567','thaole',     'Thảo Lê',        'TP.HCM','Quận 1', 12, 45231, TRUE,  'muc'),
('d0000000-0000-0000-0000-000000000002','+84909876543','minhfoodie', 'Minh Nguyễn',    'TP.HCM','Quận 7', 8,  9820,  FALSE, 'cua'),
('d0000000-0000-0000-0000-000000000003','+84911223344','khoadang',   'Khoa Đặng',      'Hà Nội','Hai Bà Trưng', 18, 122000, TRUE, 'camap')
ON CONFLICT DO NOTHING;

INSERT INTO user_preferences (user_id, allergies, diet_type, cuisines_love, spicy_tolerance, budget_min, budget_max, cook_skill, health_goal, daily_calorie) VALUES
('d0000000-0000-0000-0000-000000000001', ARRAY['peanut'],          'none',        ARRAY['vietnamese','japanese'],           4, 30000, 100000, 'intermediate', 'maintain', 1800),
('d0000000-0000-0000-0000-000000000002', ARRAY[]::TEXT[],          'pescatarian', ARRAY['vietnamese','korean','japanese'], 3, 30000, 80000,  'basic',        'lose',     1600),
('d0000000-0000-0000-0000-000000000003', ARRAY[]::TEXT[],          'none',        ARRAY['vietnamese','western'],            2, 50000, 250000, 'pro',          'gain',     2400)
ON CONFLICT DO NOTHING;

INSERT INTO streaks (user_id, daily_decide, last_decide, cook_streak, last_cook) VALUES
('d0000000-0000-0000-0000-000000000001', 12, CURRENT_DATE, 4, CURRENT_DATE),
('d0000000-0000-0000-0000-000000000002', 3,  CURRENT_DATE, 0, NULL),
('d0000000-0000-0000-0000-000000000003', 47, CURRENT_DATE, 12, CURRENT_DATE)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Refresh materialized views
-- ============================================================================
REFRESH MATERIALIZED VIEW mv_restaurant_stats;

-- ============================================================================
-- DONE — seed completed
-- ============================================================================
SELECT 'Seed complete: ' ||
  (SELECT COUNT(*) FROM foods)::text || ' foods, ' ||
  (SELECT COUNT(*) FROM restaurants)::text || ' restaurants, ' ||
  (SELECT COUNT(*) FROM achievements)::text || ' achievements';
