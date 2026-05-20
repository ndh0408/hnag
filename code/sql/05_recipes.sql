-- ============================================================================
-- HNAG — Real ingredients + cooking steps for 30 core Vietnamese foods
-- Schema: ingredients (jsonb array of {name, qty}), recipe (jsonb array of steps)
-- ============================================================================

UPDATE foods SET
  ingredients = '[{"name":"Bún sợi nhỏ","qty":"500g"},{"name":"Thịt nạm bò","qty":"400g"},{"name":"Xương bò","qty":"800g"},{"name":"Gừng nướng","qty":"1 củ"},{"name":"Hành tây nướng","qty":"1 củ"},{"name":"Hoa hồi, quế, thảo quả","qty":"vừa đủ"},{"name":"Hành lá, ngò gai, rau quế","qty":"1 mớ"},{"name":"Chanh, ớt","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Rửa sạch xương bò, chần sơ nước sôi để loại bọt.","Hầm xương với gừng+hành nướng và bó gia vị (hồi, quế, thảo quả) 3-4 tiếng lửa nhỏ.","Nêm nước mắm, muối, đường phèn vừa miệng. Lọc nước dùng trong.","Thái nạm bò mỏng, trụng tái trước khi cho vào tô.","Trụng bún nóng, xếp nạm bò + hành lá thái nhỏ, chan nước dùng nóng.","Ăn kèm rau quế, ngò gai, chanh, ớt tươi."]'::jsonb
WHERE slug = 'pho-bo';

UPDATE foods SET
  ingredients = '[{"name":"Bún sợi nhỏ","qty":"400g"},{"name":"Thịt ba chỉ","qty":"300g"},{"name":"Thịt vai xay","qty":"200g"},{"name":"Nước mắm, đường, tỏi, ớt","qty":"vừa đủ"},{"name":"Đu đủ xanh","qty":"100g"},{"name":"Rau sống các loại","qty":"1 mớ"}]'::jsonb,
  recipe = '["Ướp thịt ba chỉ với nước mắm, đường, tỏi băm, tiêu 30 phút.","Viên thịt xay thành viên nhỏ, ướp tương tự.","Nướng thịt trên than hồng đến khi vàng đều 2 mặt.","Pha nước chấm: nước mắm + đường + nước lọc + chanh + tỏi ớt băm + đu đủ xanh thái lát.","Bày bún + thịt nướng + rau sống, chấm nước mắm chua ngọt."]'::jsonb
WHERE slug = 'bun-bo-hue' OR slug = 'pho-cuon';

UPDATE foods SET
  ingredients = '[{"name":"Cơm tấm","qty":"2 chén"},{"name":"Sườn cốt lết","qty":"2 miếng"},{"name":"Bì heo trộn thính","qty":"100g"},{"name":"Chả trứng hấp","qty":"1 lát"},{"name":"Mỡ hành","qty":"2 thìa"},{"name":"Nước mắm chua ngọt","qty":"vừa đủ"},{"name":"Dưa leo, cà chua, đồ chua","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Ướp sườn với mật ong + nước mắm + tỏi băm + sả + dầu hào ít nhất 2 tiếng.","Nướng sườn trên than hoặc áp chảo lửa vừa, đến khi vàng đều 2 mặt, thấm đẫm gia vị.","Hấp chả trứng với mộc nhĩ + miến + thịt xay khoảng 25 phút.","Pha nước mắm chua ngọt: 3 đường + 2 nước mắm + 1 chanh + 4 nước lọc + tỏi ớt.","Bày cơm tấm + sườn + bì + chả, rưới mỡ hành, ăn kèm đồ chua + nước mắm."]'::jsonb
WHERE slug = 'com-tam-suon';

UPDATE foods SET
  ingredients = '[{"name":"Bánh mì baguette","qty":"1 ổ"},{"name":"Pate gan","qty":"50g"},{"name":"Bơ","qty":"15g"},{"name":"Chả lụa","qty":"2 lát"},{"name":"Thịt nguội","qty":"2 lát"},{"name":"Dưa chuột, đồ chua","qty":"vừa đủ"},{"name":"Ngò, ớt","qty":"vừa ăn"},{"name":"Nước tương Maggi","qty":"1 thìa"}]'::jsonb,
  recipe = '["Cắt dọc bánh mì, không cắt rời. Nướng giòn 2 phút.","Quết bơ + pate lên hai mặt bánh.","Xếp chả lụa, thịt nguội, đồ chua, dưa chuột thái sợi.","Rắc ngò, ớt thái lát, vài giọt Maggi.","Bóp nhẹ bánh mì, gói giấy báo và ăn ngay khi còn nóng."]'::jsonb
WHERE slug = 'banh-mi-saigon';

UPDATE foods SET
  ingredients = '[{"name":"Trứng gà","qty":"3 quả"},{"name":"Cà chua","qty":"2 quả"},{"name":"Hành lá","qty":"2 nhánh"},{"name":"Hành tím","qty":"1 củ"},{"name":"Nước mắm, đường, tiêu","qty":"vừa đủ"},{"name":"Dầu ăn","qty":"2 thìa"}]'::jsonb,
  recipe = '["Đập 3 trứng vào tô, đánh tan, nêm chút nước mắm + tiêu.","Cà chua thái múi cau, hành tím băm.","Phi thơm hành tím với dầu, cho cà chua vào xào mềm.","Nêm chút đường + nước mắm để cà chua đậm vị.","Đổ trứng vào, đảo nhanh tay đến khi trứng chín tới (không chín cháy).","Tắt bếp, rắc hành lá thái nhỏ. Ăn với cơm nóng."]'::jsonb
WHERE slug = 'trung-chien-ca-chua';

UPDATE foods SET
  ingredients = '[{"name":"Gạo tẻ","qty":"1 lon"},{"name":"Gà ta","qty":"1/2 con"},{"name":"Gừng tươi","qty":"1 củ nhỏ"},{"name":"Hành lá, ngò rí","qty":"1 mớ"},{"name":"Hành phi, tiêu","qty":"vừa đủ"},{"name":"Nước mắm, muối","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Vo gạo, rang sơ với chút dầu cho hạt gạo nở đều khi nấu.","Luộc gà với gừng đập dập + hành tím + muối, vớt gà ra để nguội xé sợi.","Lấy nước luộc gà nấu cháo, cho gạo vào nấu 45-60 phút lửa nhỏ.","Khi cháo nhừ, nêm nước mắm + muối + bột ngọt vừa ăn.","Múc cháo ra tô, thêm gà xé, hành lá, gừng thái sợi, hành phi, tiêu xay."]'::jsonb
WHERE slug = 'chao-ga';

UPDATE foods SET
  ingredients = '[{"name":"Bún sợi to","qty":"500g"},{"name":"Thịt bò bắp + giò heo","qty":"800g"},{"name":"Sả","qty":"5 cây"},{"name":"Ớt sa tế Huế","qty":"3 thìa"},{"name":"Mắm ruốc Huế","qty":"2 thìa"},{"name":"Chả Huế, huyết heo","qty":"200g + 1 miếng"},{"name":"Rau quế, giá, chuối chát","qty":"1 mớ"}]'::jsonb,
  recipe = '["Hầm xương bò + giò heo với sả đập dập 2 tiếng.","Vớt thịt bò ra thái lát, giò heo để nguyên khúc.","Hòa mắm ruốc với nước hầm, lọc sạch, đổ trở lại nồi nước dùng.","Phi sả băm với ớt + dầu điều + sa tế cho dầu đỏ thơm, đổ vào nồi.","Trụng bún, xếp thịt bò + giò + huyết + chả Huế.","Chan nước dùng nóng, ăn kèm rau quế, giá, chuối chát thái lát."]'::jsonb
WHERE slug = 'bun-bo-hue';

UPDATE foods SET
  ingredients = '[{"name":"Bún sợi","qty":"500g"},{"name":"Riêu cua đồng","qty":"300g"},{"name":"Đậu hũ chiên","qty":"200g"},{"name":"Cà chua chín","qty":"4 quả"},{"name":"Hành tím, mỡ heo, dầu điều","qty":"vừa đủ"},{"name":"Mắm tôm, giấm bỗng","qty":"2 thìa mỗi loại"},{"name":"Rau sống","qty":"1 mớ"}]'::jsonb,
  recipe = '["Lọc riêu cua: giã cua, hòa nước, lọc lấy nước cốt.","Đun sôi nước cua, riêu sẽ kết thành tảng — vớt riêu ra để riêng.","Phi hành tím với dầu điều, thêm cà chua múi cau xào mềm.","Đổ hỗn hợp cà chua vào nồi nước cua, nêm giấm bỗng + mắm tôm + muối.","Cho đậu chiên + huyết (nếu thích) vào đun thêm 5 phút.","Trụng bún, xếp riêu + đậu, chan nước dùng, ăn kèm rau sống."]'::jsonb
WHERE slug = 'bun-rieu-cua';

UPDATE foods SET
  ingredients = '[{"name":"Sợi mì Quảng","qty":"500g"},{"name":"Tôm tươi","qty":"200g"},{"name":"Thịt heo ba chỉ","qty":"200g"},{"name":"Trứng cút luộc","qty":"5 quả"},{"name":"Hạt đậu phộng rang","qty":"50g"},{"name":"Bánh tráng nướng","qty":"3 cái"},{"name":"Rau sống các loại","qty":"1 mớ"}]'::jsonb,
  recipe = '["Ướp tôm + thịt với hành tím + nước mắm + nghệ + tiêu 20 phút.","Xào thịt + tôm với dầu điều cho nước sốt sệt, có màu đỏ vàng đẹp mắt.","Hầm nước dùng từ xương tôm + xương heo, nêm nhạt vì nước sốt đã đậm.","Trụng mì Quảng, xếp tôm + thịt + trứng cút + đậu phộng.","Chan ít nước dùng (không ngập như phở), bẻ bánh tráng nướng vào.","Ăn kèm rau sống, chanh, ớt."]'::jsonb
WHERE slug = 'mi-quang';

UPDATE foods SET
  ingredients = '[{"name":"Bánh phở tươi","qty":"3 lá"},{"name":"Tôm tươi bóc vỏ","qty":"150g"},{"name":"Thịt heo luộc thái mỏng","qty":"100g"},{"name":"Xà lách, rau thơm, giá","qty":"1 mớ"},{"name":"Tương đậu phộng + tương đen","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Trải bánh phở phẳng trên đĩa.","Xếp xà lách + rau thơm + giá ở giữa, thêm tôm + thịt heo.","Cuộn chặt tay, gập 2 đầu, cuộn tròn.","Pha tương: 3 thìa tương đậu phộng + 1 thìa tương đen + chút nước + đường + tỏi ớt băm.","Cắt cuốn thành khúc 4cm, chấm tương ăn ngay."]'::jsonb
WHERE slug = 'pho-cuon';

UPDATE foods SET
  ingredients = '[{"name":"Bột gạo","qty":"200g"},{"name":"Bột năng","qty":"50g"},{"name":"Nước cốt dừa","qty":"100ml"},{"name":"Tôm khô","qty":"30g"},{"name":"Hành lá","qty":"3 nhánh"},{"name":"Nước mắm chua ngọt","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Pha bột gạo + bột năng + nước + chút muối thành hỗn hợp lỏng vừa.","Đổ bột vào khuôn bánh bèo nhỏ, hấp 7-10 phút đến khi bánh trong.","Tôm khô giã nhỏ, phi vàng với chút dầu điều.","Phi hành lá thái nhỏ với mỡ hoặc dầu thực vật.","Bày bánh ra đĩa, rắc tôm chấy + mỡ hành lên trên.","Chấm nước mắm chua ngọt pha loãng."]'::jsonb
WHERE slug = 'banh-beo';

UPDATE foods SET
  ingredients = '[{"name":"Bột gạo","qty":"200g"},{"name":"Bột nghệ","qty":"1 thìa"},{"name":"Tôm tươi","qty":"200g"},{"name":"Thịt ba chỉ","qty":"150g"},{"name":"Giá sống","qty":"200g"},{"name":"Hành lá, nước mắm chua ngọt","qty":"vừa đủ"},{"name":"Rau sống: xà lách, cải xanh","qty":"1 mớ"}]'::jsonb,
  recipe = '["Pha bột gạo với nước + bột nghệ + chút muối + nước cốt dừa + hành lá thái nhỏ.","Ướp tôm và thịt ba chỉ thái mỏng với muối + tiêu.","Đun chảo nóng già, tráng dầu, đổ một vá bột mỏng láng đều đáy chảo.","Xếp tôm + thịt + giá lên một nửa, đậy nắp 1-2 phút.","Mở nắp, gập đôi bánh lại, chiên giòn thêm 30 giây.","Ăn cuốn rau sống chấm nước mắm chua ngọt."]'::jsonb
WHERE slug = 'banh-xeo';

UPDATE foods SET
  ingredients = '[{"name":"Bột gạo","qty":"500g"},{"name":"Thịt heo xay","qty":"200g"},{"name":"Mộc nhĩ","qty":"30g"},{"name":"Hành tím phi","qty":"3 thìa"},{"name":"Chả lụa","qty":"100g"},{"name":"Rau mùi, giá","qty":"vừa đủ"},{"name":"Nước mắm chua ngọt","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Khuấy bột gạo với nước thành hỗn hợp lỏng, để nghỉ 30 phút.","Xào nhân: thịt xay + mộc nhĩ ngâm thái nhỏ + hành tím + tiêu + nước mắm.","Đun nồi nước sôi, đặt khăn vải căng trên miệng nồi.","Múc một vá bột láng đều trên khăn, đậy nắp 30 giây cho bánh chín.","Dùng que cạy bánh ra, đặt nhân vào giữa, cuộn tròn.","Bày bánh cuốn + chả lụa + hành phi + rau mùi, chấm nước mắm."]'::jsonb
WHERE slug = 'banh-cuon';

UPDATE foods SET
  ingredients = '[{"name":"Bánh tráng cuốn","qty":"10 cái"},{"name":"Thịt ba chỉ luộc","qty":"300g"},{"name":"Bún tươi","qty":"200g"},{"name":"Rau sống, chuối chát, dưa leo","qty":"1 mớ"},{"name":"Mắm nêm","qty":"3 thìa"}]'::jsonb,
  recipe = '["Luộc thịt ba chỉ với chút muối + hành, vớt ra để nguội, thái lát mỏng.","Trải bánh tráng ướt, xếp bún + rau sống + chuối chát + dưa leo + thịt heo.","Cuộn chặt tay thành cuốn dài.","Pha mắm nêm: mắm nêm + dứa băm + đường + chanh + tỏi ớt + nước.","Chấm cuốn vào mắm nêm, ăn ngay."]'::jsonb
WHERE slug = 'banh-trang-cuon-thit-heo';

UPDATE foods SET
  ingredients = '[{"name":"Bánh tráng","qty":"5 cái"},{"name":"Khô bò xé","qty":"50g"},{"name":"Trứng cút luộc","qty":"5 quả"},{"name":"Xoài xanh bào sợi","qty":"100g"},{"name":"Rau răm","qty":"1 mớ"},{"name":"Đậu phộng rang","qty":"30g"},{"name":"Sa tế, ruốc, nước tắc","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Cắt bánh tráng thành sợi nhỏ.","Trộn bánh tráng với sa tế + ruốc + nước tắc + dầu ăn nóng.","Thêm xoài bào sợi, khô bò xé, rau răm thái nhỏ.","Bóp đều tay cho thấm gia vị, để 5 phút.","Trộn cùng trứng cút bổ đôi + đậu phộng rang giã dập.","Ăn ngay khi còn giòn, không để lâu sẽ ướt."]'::jsonb
WHERE slug = 'banh-trang-tron';

UPDATE foods SET
  ingredients = '[{"name":"Cà phê phin","qty":"3 thìa"},{"name":"Sữa đặc Ông Thọ","qty":"2 thìa"},{"name":"Nước sôi","qty":"100ml"},{"name":"Đá viên","qty":"đầy ly"}]'::jsonb,
  recipe = '["Tráng phin cà phê với nước sôi.","Cho 3 thìa cà phê xay vào phin, ấn nhẹ.","Châm 20ml nước sôi đầu, đợi 30 giây cho nở.","Đổ tiếp nước sôi đầy phin, đậy nắp, đợi 4-5 phút cho cà phê nhỏ giọt hết.","Cho sữa đặc xuống ly, đặt phin lên trên, đợi cà phê chảy hết.","Khuấy đều, đổ đá, thưởng thức."]'::jsonb
WHERE slug = 'ca-phe-sua-da';

UPDATE foods SET
  ingredients = '[{"name":"Trà ô long","qty":"15g"},{"name":"Sữa đặc","qty":"2 thìa"},{"name":"Đường nâu","qty":"2 thìa"},{"name":"Trân châu đen","qty":"100g"},{"name":"Đá viên","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Ủ trà ô long với 200ml nước nóng 85°C trong 5 phút, lọc bỏ bã.","Luộc trân châu 25-30 phút đến khi nở mềm, ngâm nước đường đen 10 phút.","Pha trà sữa: trà nóng + sữa đặc + đường nâu + ít kem sữa.","Cho trân châu vào ly, đổ trà sữa, thêm đá viên.","Khuấy đều, dùng ống hút to."]'::jsonb
WHERE slug = 'tra-sua-tran-chau';

UPDATE foods SET
  ingredients = '[{"name":"Bơ chín","qty":"1 quả"},{"name":"Sữa tươi không đường","qty":"150ml"},{"name":"Sữa đặc","qty":"2 thìa"},{"name":"Đá viên","qty":"1 cốc"}]'::jsonb,
  recipe = '["Bơ bóc vỏ, bỏ hạt, cắt miếng.","Cho bơ + sữa tươi + sữa đặc + đá vào máy xay.","Xay nhuyễn đến khi mịn (30 giây - 1 phút).","Đổ ra ly cao, trang trí miếng bơ + hạt điều rang.","Dùng ngay khi còn lạnh."]'::jsonb
WHERE slug = 'sinh-to-bo';

UPDATE foods SET
  ingredients = '[{"name":"Gạo nếp","qty":"500g"},{"name":"Đỗ xanh xát vỏ","qty":"200g"},{"name":"Hành phi","qty":"3 thìa"},{"name":"Mỡ hành","qty":"2 thìa"},{"name":"Pate, chà bông, ruốc tôm","qty":"vừa đủ"},{"name":"Lạp xưởng","qty":"1 cái"}]'::jsonb,
  recipe = '["Ngâm nếp 4 tiếng + đỗ xanh 2 tiếng, để ráo.","Đồ xôi: xôi gấc đáy chõ, đặt khăn, đổ nếp lên, đồ 30 phút.","Đỗ xanh hấp riêng, giã nhuyễn, viên thành nắm.","Lạp xưởng luộc sơ, thái lát.","Xới xôi ra đĩa, rắc đỗ xanh giã + lạp xưởng + chà bông + ruốc + hành phi + mỡ hành.","Ăn nóng, mặn ngọt vừa miệng."]'::jsonb
WHERE slug = 'xoi-xeo' OR slug = 'xoi-man';

UPDATE foods SET
  ingredients = '[{"name":"Cá lóc/cá kèo","qty":"500g"},{"name":"Nước hàng","qty":"3 thìa"},{"name":"Nước mắm ngon","qty":"3 thìa"},{"name":"Đường thốt nốt","qty":"2 thìa"},{"name":"Hành tím, tỏi, ớt, gừng","qty":"vừa đủ"},{"name":"Tiêu, hành lá","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Cá rửa sạch, ướp với nước mắm + đường + tiêu + hành tỏi 30 phút.","Phi tỏi + hành tím với dầu, cho cá vào áp 2 mặt vàng đều.","Đổ nước hàng (caramel) vào, đun lửa to cho thấm.","Thêm nước ấm xâm xấp mặt cá, đun nhỏ lửa 30-40 phút.","Khi nước rút gần cạn, kẹo lại, rắc tiêu + hành lá + ớt thái lát.","Ăn với cơm trắng + canh rau."]'::jsonb
WHERE slug = 'ca-kho-to';

UPDATE foods SET
  ingredients = '[{"name":"Mì cay Hàn Quốc","qty":"200g"},{"name":"Hải sản hỗn hợp","qty":"200g"},{"name":"Đậu hũ, nấm, kim chi","qty":"vừa đủ"},{"name":"Sốt cay Hàn (gochujang)","qty":"3-7 thìa tùy cấp độ"},{"name":"Phô mai mozzarella","qty":"50g"}]'::jsonb,
  recipe = '["Xào nhẹ hành tỏi với dầu mè, thêm kim chi cho thơm.","Đổ nước dùng + gochujang theo cấp độ cay (1-7 thìa).","Cho hải sản + đậu hũ + nấm vào, đun 5 phút.","Cuối cùng thả mì vào, đun 3 phút đến khi mì chín tới.","Rắc phô mai mozzarella, đậy nắp 1 phút cho chảy.","Múc ra tô đá, ăn ngay khi nóng. Chuẩn bị nước lạnh sẵn để chữa cay."]'::jsonb
WHERE slug = 'mi-cay-7-cap-do';

UPDATE foods SET
  ingredients = '[{"name":"Ức gà","qty":"300g"},{"name":"Cơm gạo lứt","qty":"1 chén"},{"name":"Bông cải xanh","qty":"100g"},{"name":"Dầu olive","qty":"1 thìa"},{"name":"Tỏi băm, tiêu, muối","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Ướp ức gà với dầu olive + tỏi băm + tiêu + chút muối 15 phút.","Áp chảo gà mỗi mặt 4-5 phút lửa vừa đến khi chín tới và còn mọng nước.","Nấu cơm gạo lứt với tỷ lệ 1:2 nước, hấp 35-40 phút.","Bông cải luộc 2 phút trong nước muối, vớt vào nước đá để giữ màu xanh.","Thái gà thành lát, bày cùng cơm + bông cải.","Rưới chút dầu olive + chanh, rắc tiêu xay."]'::jsonb
WHERE slug = 'com-ga-uc-nuong';

UPDATE foods SET
  ingredients = '[{"name":"Cá hồi tươi","qty":"150g"},{"name":"Rau xà lách hỗn hợp","qty":"100g"},{"name":"Bơ chín, dưa leo","qty":"1 quả + 50g"},{"name":"Cà chua bi","qty":"100g"},{"name":"Dầu olive, chanh, muối tiêu","qty":"vừa đủ"}]'::jsonb,
  recipe = '["Cá hồi rửa sạch, lau khô, ướp tiêu + muối.","Áp chảo cá hồi 2 phút mỗi mặt với dầu olive, da giòn, thịt còn hồng giữa.","Rửa rau xà lách, để ráo, xếp ra đĩa.","Bơ thái lát, dưa leo thái khoanh, cà chua bi bổ đôi.","Đặt cá hồi lên trên rau, vắt chanh, rưới dầu olive.","Rắc thêm tiêu đen xay + hạt vừng nếu thích."]'::jsonb
WHERE slug = 'salad-ca-hoi';

UPDATE foods SET
  ingredients = '[{"name":"Cá lóc/cá quả","qty":"500g"},{"name":"Nghệ tươi giã","qty":"2 thìa"},{"name":"Mẻ + mắm tôm","qty":"2 thìa mỗi loại"},{"name":"Thì là, hành hoa","qty":"1 mớ"},{"name":"Bún tươi","qty":"500g"},{"name":"Đậu phộng, bánh đa nướng","qty":"100g + 3 cái"}]'::jsonb,
  recipe = '["Cá lóc làm sạch, lóc phi lê thái lát vừa ăn.","Ướp cá với nghệ + mẻ + mắm tôm + nước mắm 30 phút.","Nướng cá trên than hoa cho đến khi vàng giòn 2 mặt.","Khi ăn cho cá vào chảo nóng cùng thì là + hành hoa.","Pha mắm tôm: mắm tôm + chanh + đường + ớt đánh bông.","Ăn với bún + rau thơm + đậu phộng + bánh đa nướng."]'::jsonb
WHERE slug = 'cha-ca-la-vong';

UPDATE foods SET
  ingredients = '[{"name":"Ốc bươu/ốc hương","qty":"1kg"},{"name":"Sả","qty":"5 cây"},{"name":"Gừng, lá chanh","qty":"1 củ + 5 lá"},{"name":"Muối ớt xanh","qty":"3 thìa"},{"name":"Quất","qty":"3 quả"}]'::jsonb,
  recipe = '["Ngâm ốc với nước vo gạo + ớt 2-3 tiếng cho nhả bùn.","Rửa lại bằng nước sạch nhiều lần.","Đun nồi nước với sả đập dập + gừng + lá chanh.","Khi nước sôi, cho ốc vào, đậy nắp 5-7 phút.","Vớt ốc ra khi miệng vừa mở, không luộc quá lâu sẽ dai.","Pha muối ớt xanh: muối + ớt xanh + quất + đường giã nhuyễn. Chấm ốc ăn nóng."]'::jsonb
WHERE slug = 'oc-luoc';

UPDATE foods SET
  ingredients = '[{"name":"Mì gói","qty":"1 gói"},{"name":"Trứng gà","qty":"1 quả"},{"name":"Xúc xích","qty":"1 cây"},{"name":"Rau cải, hành lá","qty":"vừa đủ"},{"name":"Phô mai","qty":"1 lát"}]'::jsonb,
  recipe = '["Đun 400ml nước sôi.","Cho mì + gói gia vị vào nồi, đun 2 phút.","Đập trứng thẳng vào nồi (không khuấy), đậy nắp 1 phút.","Thêm xúc xích thái lát + rau cải, đun thêm 30 giây.","Tắt bếp, đổ ra tô, đặt lát phô mai lên trên cho chảy.","Rắc hành lá thái nhỏ, ăn nóng."]'::jsonb
WHERE slug = 'mi-goi-cao-cap';

UPDATE foods SET
  ingredients = '[{"name":"Bún tươi","qty":"500g"},{"name":"Đậu hũ chiên","qty":"200g"},{"name":"Nấm hỗn hợp","qty":"200g"},{"name":"Cà chua, cải thảo","qty":"vừa đủ"},{"name":"Sả, lá thơm chay","qty":"vừa đủ"},{"name":"Nước tương, dầu mè","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Nấu nước dùng chay: hầm cải thảo + nấm + sả 30 phút.","Nêm nước dùng với muối + đường phèn + nước tương + dầu mè.","Đậu hũ cắt miếng, chiên vàng.","Nấm xé hoặc cắt vừa ăn, luộc sơ.","Trụng bún, xếp đậu + nấm + cà chua + cải thảo.","Chan nước dùng nóng, ăn kèm rau thơm chay."]'::jsonb
WHERE slug = 'bun-chay';

UPDATE foods SET
  ingredients = '[{"name":"Lẩu thập cẩm","qty":"800g hải sản + thịt"},{"name":"Rau hỗn hợp","qty":"500g"},{"name":"Nấm các loại","qty":"200g"},{"name":"Bún/mì","qty":"500g"},{"name":"Nước dùng lẩu","qty":"2 lít"}]'::jsonb,
  recipe = '["Chuẩn bị nước dùng: hầm xương 2 tiếng, nêm sa tế + me + đường + nước mắm.","Sơ chế hải sản: bóc vỏ tôm, làm sạch mực, rửa nghêu.","Thái thịt bò + thịt heo thành lát mỏng.","Cắt rau, nấm, đậu hũ vừa miệng.","Bày nguyên liệu xung quanh bếp lẩu, đun nước dùng sôi.","Lần lượt cho từng loại vào, ăn nóng kèm bún/mì và nước chấm."]'::jsonb
WHERE slug = 'lau-thap-cam' OR slug = 'lau-mam' OR slug = 'lau-thai';

UPDATE foods SET
  ingredients = '[{"name":"Bột chiên giòn","qty":"100g"},{"name":"Bánh bột chiên","qty":"4 cái"},{"name":"Trứng gà","qty":"2 quả"},{"name":"Đu đủ xanh, hành lá","qty":"vừa đủ"},{"name":"Tương đen, tương đỏ","qty":"vừa ăn"}]'::jsonb,
  recipe = '["Cắt bánh bột thành miếng vuông 3cm.","Chiên bột với chút dầu cho vàng giòn cạnh.","Đập trứng đánh tan, đổ vào chảo, để trứng bám đáy chảo + bột.","Đợi trứng se mặt, lật cả tảng cho vàng đều.","Bày ra đĩa, rắc hành lá, đu đủ xanh bào sợi.","Chấm tương đen pha tương đỏ + ớt."]'::jsonb
WHERE slug = 'bot-chien';

UPDATE foods SET
  ingredients = '[{"name":"Yến mạch cán dẹt","qty":"50g"},{"name":"Chuối chín","qty":"1 quả"},{"name":"Sữa hạnh nhân","qty":"200ml"},{"name":"Hạnh nhân lát","qty":"15g"},{"name":"Mật ong, quế","qty":"1 thìa + chút"}]'::jsonb,
  recipe = '["Đun sữa hạnh nhân + yến mạch lửa nhỏ 5 phút, khuấy đều.","Thái chuối thành khoanh.","Đổ cháo yến mạch ra bowl, thêm chuối + hạnh nhân.","Rưới mật ong, rắc bột quế.","Ăn ngay khi còn ấm, hợp bữa sáng healthy."]'::jsonb
WHERE slug = 'oat-banana';

-- Verification
SELECT COUNT(*) AS foods_with_recipes FROM foods WHERE recipe IS NOT NULL AND jsonb_array_length(recipe::jsonb) > 0;
