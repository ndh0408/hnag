-- ============================================================================
-- HNAG — Recipes batch 2: remaining 28 foods
-- ============================================================================

UPDATE foods SET ingredients='[{"name":"Bún tươi","qty":"500g"},{"name":"Cá lóc + tôm + mực","qty":"500g"},{"name":"Mắm cá linh/sặc","qty":"200g"},{"name":"Cà tím","qty":"2 quả"},{"name":"Sả, ớt","qty":"vừa đủ"},{"name":"Rau: bông súng, kèo nèo, rau đắng","qty":"1 mớ"}]'::jsonb,
recipe='["Nấu mắm cá với nước, lọc bỏ xương lấy nước mắm trong.","Phi sả băm thơm, cho nước mắm lọc vào đun sôi.","Cho cà tím cắt khúc + sả cây vào nấu mềm.","Thả cá lóc, tôm, mực vào nấu chín tới.","Nêm đường + bột ngọt cân vị mặn ngọt.","Trụng bún, chan nước lèo, ăn kèm rau sống đặc trưng miền Tây."]'::jsonb WHERE slug='bun-mam';

UPDATE foods SET ingredients='[{"name":"Tôm tươi","qty":"300g"},{"name":"Bột mì + bột chiên giòn","qty":"200g"},{"name":"Khoai lang bào sợi","qty":"100g"},{"name":"Rau sống, đu đủ chua","qty":"1 mớ"},{"name":"Nước mắm chua ngọt","qty":"vừa đủ"}]'::jsonb,
recipe='["Pha bột mì + bột chiên giòn + nước + chút bột nghệ thành hỗn hợp sệt.","Trộn khoai lang bào sợi vào bột.","Cho tôm lên muôi, phủ bột khoai, nhúng vào chảo dầu nóng.","Chiên ngập dầu đến khi vàng giòn 2 mặt.","Vớt ra để ráo dầu trên giấy thấm.","Ăn nóng cuốn rau sống, chấm nước mắm chua ngọt + đu đủ."]'::jsonb WHERE slug='banh-tom-ho-tay';

UPDATE foods SET ingredients='[{"name":"Bánh gạo Hàn (tteok)","qty":"300g"},{"name":"Chả cá Hàn","qty":"100g"},{"name":"Sốt gochujang","qty":"3 thìa"},{"name":"Đường, tỏi băm","qty":"vừa đủ"},{"name":"Trứng luộc, hành lá","qty":"2 quả"}]'::jsonb,
recipe='["Ngâm bánh gạo nước ấm 10 phút cho mềm.","Đun nước dùng với gochujang + đường + tỏi.","Cho bánh gạo + chả cá vào, đun đến khi sốt sệt lại.","Thêm trứng luộc bổ đôi.","Rắc hành lá + vừng, ăn nóng."]'::jsonb WHERE slug='tokbokki';

UPDATE foods SET ingredients='[{"name":"Ba chỉ bò Mỹ","qty":"400g"},{"name":"Nấm, hành tây","qty":"200g"},{"name":"Kim chi","qty":"150g"},{"name":"Sốt ướp BBQ Hàn","qty":"4 thìa"},{"name":"Rau xà lách, lá vừng","qty":"1 mớ"},{"name":"Tương ssamjang","qty":"vừa đủ"}]'::jsonb,
recipe='["Ướp ba chỉ bò với sốt BBQ Hàn (xì dầu + đường + tỏi + dầu mè + lê xay) 30 phút.","Làm nóng vỉ nướng, nướng thịt + nấm + hành tây.","Nướng kim chi cho thơm.","Cắt thịt thành miếng vừa ăn bằng kéo.","Cuốn thịt với rau xà lách + lá vừng + tương ssamjang.","Ăn nóng kèm cơm + canh."]'::jsonb WHERE slug='bbq-han-quoc';

UPDATE foods SET ingredients='[{"name":"Cơm trắng","qty":"2 chén"},{"name":"Thịt kho/gà rán/cá","qty":"1 phần"},{"name":"Canh rau","qty":"1 chén"},{"name":"Rau xào","qty":"1 đĩa nhỏ"},{"name":"Đồ chua","qty":"vừa đủ"}]'::jsonb,
recipe='["Nấu cơm trắng tơi xốp.","Chuẩn bị món mặn: thịt kho hoặc gà rán hoặc cá kho.","Nấu một món canh rau (cải, bí, mồng tơi).","Xào một đĩa rau theo mùa.","Bày cơm + món mặn + canh + rau thành suất văn phòng cân bằng.","Thêm đồ chua + trái cây tráng miệng."]'::jsonb WHERE slug='com-van-phong';

UPDATE foods SET ingredients='[{"name":"Pasta (penne/spaghetti)","qty":"200g"},{"name":"Kem tươi (whipping cream)","qty":"150ml"},{"name":"Phô mai parmesan","qty":"50g"},{"name":"Thịt xông khói/gà","qty":"100g"},{"name":"Tỏi, bơ, tiêu đen","qty":"vừa đủ"}]'::jsonb,
recipe='["Luộc pasta trong nước sôi + muối đến al dente (8-10 phút), giữ lại ít nước luộc.","Phi tỏi với bơ, cho thịt xông khói vào xào thơm.","Đổ kem tươi vào, đun lửa nhỏ cho sệt.","Cho phô mai parmesan vào khuấy tan.","Trộn pasta vào sốt, thêm chút nước luộc nếu khô.","Rắc tiêu đen + parmesan, ăn nóng."]'::jsonb WHERE slug='pasta-sot-kem';

UPDATE foods SET ingredients='[{"name":"Bột mì + bột năng","qty":"300g"},{"name":"Tôm, thịt xay","qty":"200g mỗi loại"},{"name":"Nấm hương, mộc nhĩ","qty":"50g"},{"name":"Cà rốt, hành","qty":"vừa đủ"},{"name":"Xì dầu, dầu mè","qty":"vừa ăn"}]'::jsonb,
recipe='["Nhào bột mì + bột năng + nước nóng thành vỏ bánh dẻo.","Trộn nhân: tôm + thịt xay + nấm + cà rốt băm + gia vị.","Cán vỏ mỏng, cho nhân vào, tạo hình há cảo / xíu mại.","Xếp vào xửng có lót giấy nến.","Hấp 12-15 phút đến khi vỏ trong.","Ăn nóng chấm xì dầu + dầu mè + ớt."]'::jsonb WHERE slug='dimsum';

UPDATE foods SET ingredients='[{"name":"Sữa chua","qty":"2 hộp"},{"name":"Mít chín","qty":"200g"},{"name":"Đá bào","qty":"1 cốc"},{"name":"Sữa đặc","qty":"1 thìa"}]'::jsonb,
recipe='["Mít chín tách múi, bỏ hạt, thái sợi.","Cho sữa chua vào ly.","Thêm mít thái sợi.","Phủ đá bào lên trên.","Rưới chút sữa đặc, trộn đều khi ăn."]'::jsonb WHERE slug='sua-chua-mit';

UPDATE foods SET ingredients='[{"name":"Thịt bò thăn","qty":"400g"},{"name":"Lá lốt","qty":"30 lá"},{"name":"Sả, tỏi, hành tím băm","qty":"vừa đủ"},{"name":"Nước mắm, đường, tiêu","qty":"vừa ăn"},{"name":"Bún + rau sống","qty":"500g"}]'::jsonb,
recipe='["Bằm bò với sả + tỏi + hành tím + nước mắm + đường + tiêu.","Ướp 30 phút cho thấm.","Trải lá lốt mặt xanh xuống, cho thịt vào cuốn chặt.","Xiên que hoặc đặt lên vỉ, nướng than đến khi lá hơi cháy thơm.","Ăn kèm bún + rau sống + nước mắm chua ngọt + đậu phộng."]'::jsonb WHERE slug='bo-nuong-la-lot';

UPDATE foods SET ingredients='[{"name":"Bún sợi nhỏ","qty":"500g"},{"name":"Gà ta","qty":"1/2 con"},{"name":"Giò lụa, trứng tráng","qty":"100g + 2 quả"},{"name":"Tôm khô, củ cải khô","qty":"50g"},{"name":"Rau răm, hành phi","qty":"vừa đủ"},{"name":"Mắm tôm (tùy chọn)","qty":"1 thìa"}]'::jsonb,
recipe='["Luộc gà lấy nước dùng ngọt thanh, xé gà thành sợi.","Tráng trứng mỏng, thái sợi chỉ.","Thái giò lụa thành sợi.","Ngâm tôm khô, rang thơm. Củ cải khô ngâm nở.","Trụng bún, xếp gà + giò + trứng + tôm khô thành từng phần riêng đẹp mắt.","Chan nước dùng nóng, rắc rau răm + hành phi. Thêm mắm tôm nếu thích."]'::jsonb WHERE slug='bun-thang';

UPDATE foods SET ingredients='[{"name":"Bột gạo + bột năng","qty":"300g"},{"name":"Thịt heo xay","qty":"150g"},{"name":"Mộc nhĩ, hành khô","qty":"50g"},{"name":"Trứng cút","qty":"5 quả"},{"name":"Lá chuối gói","qty":"vừa đủ"}]'::jsonb,
recipe='["Khuấy bột gạo + bột năng với nước xương nóng thành bột sệt.","Xào nhân: thịt xay + mộc nhĩ + hành khô + tiêu.","Lót lá chuối, múc một lớp bột, cho nhân + trứng cút vào giữa.","Phủ lớp bột lên, gói lá chuối thành hình chóp.","Hấp 30-40 phút đến khi bột chín trong.","Ăn nóng, bóc lá, chấm tương ớt."]'::jsonb WHERE slug='banh-gio';

UPDATE foods SET ingredients='[{"name":"Hủ tiếu khô","qty":"400g"},{"name":"Tôm, thịt nạc, gan heo","qty":"500g"},{"name":"Xương ống heo","qty":"500g"},{"name":"Mực khô, tôm khô","qty":"50g"},{"name":"Hẹ, giá, cần tây","qty":"1 mớ"},{"name":"Tỏi phi, hành phi","qty":"vừa đủ"}]'::jsonb,
recipe='["Hầm xương heo + mực khô + tôm khô 2 tiếng cho nước ngọt trong.","Nêm nước dùng với đường phèn + nước mắm + muối.","Luộc tôm, thịt nạc, gan heo, thái lát.","Trụng hủ tiếu mềm vừa.","Xếp hủ tiếu + tôm + thịt + gan + giá + hẹ.","Chan nước dùng nóng, rắc tỏi phi + hành phi + tiêu."]'::jsonb WHERE slug='hu-tieu-nam-vang';

UPDATE foods SET ingredients='[{"name":"Bột gạo + bột nghệ","qty":"200g"},{"name":"Tôm tươi nhỏ","qty":"200g"},{"name":"Nước cốt dừa","qty":"100ml"},{"name":"Hành lá, đậu xanh","qty":"vừa đủ"},{"name":"Rau sống, nước mắm chua ngọt","qty":"vừa đủ"}]'::jsonb,
recipe='["Pha bột gạo + bột nghệ + nước cốt dừa + nước thành bột loãng.","Đổ bột vào khuôn bánh khọt nóng có tráng dầu.","Cho 1 con tôm + chút đậu xanh hấp lên mỗi khuôn.","Đậy nắp 2-3 phút đến khi rìa bánh giòn, lòng bánh chín.","Rắc mỡ hành lên.","Ăn cuốn rau sống chấm nước mắm chua ngọt."]'::jsonb WHERE slug='banh-khot';

UPDATE foods SET ingredients='[{"name":"Đậu xanh, đậu đỏ, đậu đen","qty":"100g mỗi loại"},{"name":"Bột báng, thạch","qty":"50g"},{"name":"Nước cốt dừa","qty":"150ml"},{"name":"Đường, đá bào","qty":"vừa đủ"}]'::jsonb,
recipe='["Nấu riêng từng loại đậu với đường đến khi mềm.","Nấu bột báng đến khi trong.","Cắt thạch thành sợi.","Xếp 3 loại đậu + thạch + bột báng vào ly thành 3 màu.","Chan nước cốt dừa.","Thêm đá bào, trộn đều khi ăn."]'::jsonb WHERE slug='che-ba-mau';

UPDATE foods SET ingredients='[{"name":"Gà ta","qty":"1 con"},{"name":"Muối hột, ớt, lá chanh","qty":"vừa đủ"},{"name":"Sả, mật ong","qty":"vừa đủ"},{"name":"Dầu điều","qty":"2 thìa"}]'::jsonb,
recipe='["Làm sạch gà, khứa nhẹ thân để thấm gia vị.","Ướp gà với sả + tỏi + ớt + mật ong + dầu điều + muối 1 tiếng.","Nướng gà trên than hoa, trở đều đến khi da vàng giòn.","Quết thêm mật ong lúc gần chín cho bóng đẹp.","Chặt miếng vừa ăn.","Chấm muối ớt lá chanh giã."]'::jsonb WHERE slug='ga-nuong-muoi-ot';

UPDATE foods SET ingredients='[{"name":"Mì ramen tươi","qty":"200g"},{"name":"Nước dùng tonkotsu/shoyu","qty":"500ml"},{"name":"Thịt chashu (ba chỉ)","qty":"100g"},{"name":"Trứng lòng đào","qty":"1 quả"},{"name":"Rong biển, hành lá, măng","qty":"vừa đủ"}]'::jsonb,
recipe='["Hầm xương heo nhiều tiếng cho nước dùng trắng đục (tonkotsu).","Làm chashu: ba chỉ cuộn, kho xì dầu + mirin + đường, thái lát.","Luộc trứng 7 phút lòng đào, ngâm xì dầu.","Trụng mì ramen 2 phút.","Cho mì vào tô, chan nước dùng nóng.","Xếp chashu + trứng + rong biển + măng + hành lá lên trên."]'::jsonb WHERE slug='ramen-nhat';

UPDATE foods SET ingredients='[{"name":"Sợi cao lầu","qty":"400g"},{"name":"Thịt xá xíu","qty":"200g"},{"name":"Tóp mỡ, bánh tráng giòn","qty":"vừa đủ"},{"name":"Rau sống Trà Quế","qty":"1 mớ"},{"name":"Nước nhân thịt cô đặc","qty":"vừa đủ"}]'::jsonb,
recipe='["Ướp thịt heo với ngũ vị hương + xì dầu, làm xá xíu, thái lát.","Trụng sợi cao lầu (sợi dày đặc trưng Hội An).","Xếp sợi + rau sống + thịt xá xíu.","Rưới ít nước nhân thịt cô đặc (không chan ngập).","Thêm tóp mỡ + bánh tráng giòn bẻ vụn.","Trộn đều khi ăn, kèm rau Trà Quế."]'::jsonb WHERE slug='cao-lau';

UPDATE foods SET ingredients='[{"name":"Bột rau câu","qty":"10g"},{"name":"Sữa tươi + nước cốt dừa","qty":"500ml"},{"name":"Hạnh nhân lát","qty":"30g"},{"name":"Đường","qty":"100g"}]'::jsonb,
recipe='["Nấu rau câu với sữa tươi + nước cốt dừa + đường.","Chia 2 phần: 1 phần trắng, 1 phần thêm lá dứa hoặc cà phê tạo màu.","Đổ từng lớp xen kẽ vào khuôn, chờ mỗi lớp se mặt.","Để tủ lạnh 2-3 tiếng cho đông.","Cắt khối vuông.","Dùng lạnh, rắc hạnh nhân lát."]'::jsonb WHERE slug='che-khuc-bach';

UPDATE foods SET ingredients='[{"name":"Bún tươi","qty":"500g"},{"name":"Thịt ba chỉ + thịt vai xay","qty":"500g"},{"name":"Nước mắm, đường, giấm","qty":"vừa đủ"},{"name":"Đu đủ xanh, cà rốt","qty":"100g"},{"name":"Rau sống các loại","qty":"1 mớ"}]'::jsonb,
recipe='["Ướp thịt ba chỉ thái miếng + thịt viên với nước mắm + đường + hành 30 phút.","Nướng thịt trên than đến khi vàng cháy cạnh thơm.","Pha nước chấm: nước mắm + đường + giấm + nước lọc ấm + tỏi ớt.","Cho đu đủ + cà rốt thái lát ngâm chua vào bát nước chấm.","Thả thịt nướng vào bát nước chấm.","Ăn kèm bún + rau sống, chấm ngập."]'::jsonb WHERE slug='bun-cha';

UPDATE foods SET ingredients='[{"name":"Đế pizza","qty":"1 cái"},{"name":"Sốt cà chua","qty":"3 thìa"},{"name":"Phô mai mozzarella","qty":"150g"},{"name":"Thịt bò xay","qty":"100g"},{"name":"Ớt chuông, hành tây","qty":"vừa đủ"}]'::jsonb,
recipe='["Cán đế pizza, phết sốt cà chua đều mặt.","Rải phô mai mozzarella.","Xào sơ thịt bò xay, rải lên cùng ớt chuông + hành tây thái lát.","Phủ thêm lớp phô mai.","Nướng lò 220°C trong 12-15 phút đến khi viền vàng, phô mai chảy.","Cắt miếng, ăn nóng."]'::jsonb WHERE slug='pizza-bo-pho-mai';

UPDATE foods SET ingredients='[{"name":"Cơm sushi (giấm)","qty":"2 chén"},{"name":"Cá hồi, cá ngừ tươi","qty":"200g"},{"name":"Rong biển nori","qty":"5 lá"},{"name":"Dưa leo, bơ","qty":"vừa đủ"},{"name":"Wasabi, gừng ngâm, xì dầu","qty":"vừa đủ"}]'::jsonb,
recipe='["Trộn cơm nóng với giấm sushi (giấm + đường + muối), quạt nguội.","Thái cá hồi, cá ngừ thành lát mỏng cho sashimi/nigiri.","Trải nori trên mành tre, dàn cơm, xếp nhân dưa leo + bơ + cá.","Cuộn chặt tay thành maki, cắt khúc.","Nắm cơm + đặt lát cá lên làm nigiri.","Bày kèm wasabi + gừng ngâm + xì dầu."]'::jsonb WHERE slug='sushi-combo';

UPDATE foods SET ingredients='[{"name":"Cơm trắng nấu nước luộc gà","qty":"2 chén"},{"name":"Gà ta luộc","qty":"1/2 con"},{"name":"Gừng, hành lá","qty":"vừa đủ"},{"name":"Nước tương, dầu mè","qty":"vừa ăn"},{"name":"Dưa leo","qty":"1 quả"}]'::jsonb,
recipe='["Luộc gà với gừng + hành đến chín tới, ngâm nước đá cho da giòn.","Dùng nước luộc gà nấu cơm cho thơm béo.","Pha nước chấm: gừng băm + tỏi + nước tương + dầu mè + nước luộc gà.","Chặt gà thành miếng.","Bày cơm gà + dưa leo + rau thơm.","Chan ít nước luộc, chấm nước gừng."]'::jsonb WHERE slug='com-ga-hai-nam';

UPDATE foods SET ingredients='[{"name":"Thịt heo nạc vai","qty":"400g"},{"name":"Sả cây","qty":"10 cây"},{"name":"Bánh tráng, bún","qty":"vừa đủ"},{"name":"Rau sống, khế, chuối chát","qty":"1 mớ"},{"name":"Tương đậu phộng (nước lèo)","qty":"vừa đủ"}]'::jsonb,
recipe='["Băm/xay thịt heo, ướp sả băm + gia vị.","Quấn thịt quanh cây sả.","Nướng nem trên than đến khi vàng thơm.","Pha nước lèo: gan heo + tương + đậu phộng xay sệt.","Cuốn nem với bánh tráng + bún + rau sống + khế + chuối chát.","Chấm nước lèo đậu phộng."]'::jsonb WHERE slug='nem-lui';

UPDATE foods SET ingredients='[{"name":"Bánh burger","qty":"2 cái"},{"name":"Ức gà phi lê","qty":"2 miếng"},{"name":"Bột chiên giòn","qty":"100g"},{"name":"Xà lách, cà chua, phô mai","qty":"vừa đủ"},{"name":"Sốt mayonnaise","qty":"2 thìa"}]'::jsonb,
recipe='["Ướp ức gà với muối + tiêu + tỏi, lăn bột chiên giòn.","Chiên gà ngập dầu đến vàng giòn.","Nướng sơ 2 mặt bánh burger.","Phết sốt mayonnaise lên bánh.","Xếp xà lách + cà chua + gà chiên + phô mai.","Đậy bánh, ấn nhẹ, ăn nóng."]'::jsonb WHERE slug='burger-ga';

UPDATE foods SET ingredients='[{"name":"Cơm trắng","qty":"2 chén"},{"name":"Hến luộc","qty":"300g"},{"name":"Tóp mỡ, đậu phộng","qty":"vừa đủ"},{"name":"Rau thơm, bắp chuối","qty":"1 mớ"},{"name":"Mắm ruốc Huế, da heo chiên","qty":"vừa đủ"}]'::jsonb,
recipe='["Luộc hến, lấy thịt, giữ nước luộc.","Xào hến với hành phi + gia vị cho thơm.","Bày cơm nguội, cho hến xào lên.","Thêm tóp mỡ + đậu phộng + da heo chiên giòn.","Rắc rau thơm + bắp chuối bào.","Chan nước hến + mắm ruốc, trộn đều khi ăn."]'::jsonb WHERE slug='com-hen';

UPDATE foods SET ingredients='[{"name":"Cơm trắng nóng","qty":"2 chén"},{"name":"Rau củ: cà rốt, rau bina, giá","qty":"200g"},{"name":"Thịt bò xào","qty":"150g"},{"name":"Trứng ốp la","qty":"2 quả"},{"name":"Sốt gochujang, dầu mè","qty":"vừa đủ"}]'::jsonb,
recipe='["Xào riêng từng loại rau củ với chút dầu mè + muối.","Xào thịt bò với xì dầu + tỏi.","Cho cơm nóng vào tô (hoặc thố đá nóng).","Xếp rau củ + thịt bò quanh tô theo màu.","Đặt trứng ốp la lòng đào lên giữa.","Thêm gochujang + dầu mè, trộn đều khi ăn."]'::jsonb WHERE slug='bibimbap';

UPDATE foods SET ingredients='[{"name":"Cây mía tươi","qty":"3 khúc"},{"name":"Tắc/quất","qty":"2 quả"}]'::jsonb,
recipe='["Mía róc vỏ, rửa sạch, cắt khúc vừa máy ép.","Ép mía qua máy 2-3 lần lấy hết nước.","Vắt thêm tắc cho thơm và đỡ gắt.","Lọc bỏ bã.","Rót ra ly đầy đá, dùng ngay khi còn lạnh."]'::jsonb WHERE slug='nuoc-mia';

UPDATE foods SET ingredients='[{"name":"Trứng vịt lộn","qty":"2 quả"},{"name":"Rau răm","qty":"1 mớ"},{"name":"Gừng thái sợi","qty":"vừa đủ"},{"name":"Muối tiêu chanh","qty":"vừa đủ"}]'::jsonb,
recipe='["Rửa sạch trứng vịt lộn.","Luộc trứng trong nước sôi 20-25 phút.","Vớt ra, đập nhẹ đầu to, bóc vỏ.","Pha muối tiêu chanh.","Ăn nóng kèm rau răm + gừng thái sợi, chấm muối tiêu chanh."]'::jsonb WHERE slug='hot-vit-lon';

-- Verification
SELECT COUNT(*) AS total_with_recipes FROM foods WHERE recipe IS NOT NULL AND jsonb_array_length(recipe::jsonb) > 0;
SELECT COUNT(*) AS still_missing FROM foods WHERE recipe IS NULL OR jsonb_array_length(recipe::jsonb) = 0;
