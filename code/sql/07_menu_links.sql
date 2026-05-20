-- ============================================================================
-- HNAG — Link iconic foods to their signature restaurants (menu_items)
-- ============================================================================

INSERT INTO menu_items (restaurant_id, food_id, name, price_vnd, is_signature)
SELECT r.id, f.id, f.name_vi, f.avg_price_vnd, true
FROM foods f, restaurants r
WHERE (f.slug, r.slug) IN (
  ('pho-bo', 'pho-le'),
  ('pho-bo', 'pho-ly-quoc-su'),
  ('com-tam-suon', 'com-tam-ba-ghien'),
  ('com-tam-suon', 'quan-bui'),
  ('banh-mi-saigon', 'banh-mi-huynh-hoa'),
  ('bun-bo-hue', 'bun-bo-ganh'),
  ('bun-cha', 'bun-cha-huong-lien'),
  ('bun-thang', 'bun-thang-ba-duc'),
  ('hu-tieu-nam-vang', 'hu-tieu-hong-phat'),
  ('banh-xeo', 'banh-xeo-46a'),
  ('banh-cuon', 'banh-cuon-ba-hoanh'),
  ('ca-phe-sua-da', 'highlands-coffee-ben-thanh'),
  ('ca-phe-sua-da', 'cong-ca-phe-nha-tho'),
  ('ca-phe-sua-da', 'highlands-ho-guom'),
  ('oc-luoc', 'quan-oc-dao'),
  ('cha-ca-la-vong', 'cha-ca-la-vong-restaurant'),
  ('tra-sua-tran-chau', 'bobapop'),
  ('tra-sua-tran-chau', 'ha-linh-tra-sua'),
  ('lau-thap-cam', 'lau-de-truong-dinh'),
  ('lau-thap-cam', 'lau-phan'),
  ('sushi-combo', 'sushi-tei-vincom'),
  ('burger-ga', 'burger-bros'),
  ('salad-ca-hoi', 'saladbox'),
  ('bbq-han-quoc', 'bbq-garden'),
  ('mi-cay-7-cap-do', 'sasin-mi-cay'),
  ('pizza-bo-pho-mai', 'pizza-4ps-le-thanh-ton'),
  ('pizza-bo-pho-mai', 'pizza-4ps-trang-tien')
)
AND NOT EXISTS (
  SELECT 1 FROM menu_items m WHERE m.restaurant_id = r.id AND m.food_id = f.id
);

SELECT COUNT(*) AS total_menu_items FROM menu_items;
SELECT COUNT(DISTINCT food_id) AS distinct_foods_on_menus FROM menu_items;
