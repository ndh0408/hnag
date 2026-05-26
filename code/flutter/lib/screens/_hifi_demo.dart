// Demo data + navigation helpers for the Hi-Fi v2 screens shown in Tools tab.
// Lets QA preview the new design system screens without restructuring the
// whole app navigation. Production cut-over happens in a follow-up.

import 'package:flutter/material.dart';

import 'home_v2/home_v2.dart' as home_v2;
import 'detail_v2/detail_v2.dart' as detail_v2;

class HifiDemo {
  HifiDemo._();

  static home_v2.FoodCardLargeData _demoFood() => const home_v2.FoodCardLargeData(
    id: 'demo-bunbo',
    name: 'Bún bò Huế',
    foodSlug: 'bunbo',
    price: '50.000₫',
    calories: '480 cal',
    time: '30 phút',
    rating: '4.8',
    kind: 'order',
    kindLabel: 'Giao tận nơi',
    reason: 'Trời mưa Hà Nội — một tô ấm hợp ngày se lạnh, lại đúng mức cay bạn thích.',
  );

  static List<home_v2.FoodCardLargeData> _demoStack() => const [
    home_v2.FoodCardLargeData(
      id: 'c1', name: 'Cơm gà Hải Nam', foodSlug: 'comga',
      price: '45.000₫', calories: '520 cal', time: '15 phút', rating: '4.7',
      kind: 'pin', kindLabel: 'Đi ăn · 200m',
      reason: 'Trời nắng + đói mức 6.5 + ngân sách 80k → đây là combo khớp 94%.',
    ),
    home_v2.FoodCardLargeData(
      id: 'c2', name: 'Bún chả Hương Liên', foodSlug: 'bunch',
      price: '55.000₫', calories: '610 cal', time: '20 phút', rating: '4.9',
      kind: 'order', kindLabel: 'Giao tận nơi',
      reason: 'Bún chả cuối tuần, bạn chưa ăn 8 ngày — Hà nhớ đó.',
    ),
    home_v2.FoodCardLargeData(
      id: 'c3', name: 'Salad cá hồi', foodSlug: 'goicuon',
      price: '85.000₫', calories: '320 cal', time: '10 phút', rating: '4.6',
      kind: 'order', kindLabel: 'Healthy choice',
      reason: 'Healthy + đúng mục tiêu giữ dáng, lại có mặt trên budget của bạn.',
    ),
  ];

  static Widget homeDemo(BuildContext _) => home_v2.HomeScreenV2(
    userName: 'Thảo',
    heroSuggestion: _demoFood(),
    trending: const [
      home_v2.NearbyPlace(id: '1', name: 'Phở Lý QS', rating: '4.7', price: '45k', distance: '200m', foodSlug: 'pho',     hot: true),
      home_v2.NearbyPlace(id: '2', name: 'Bún chả H.L', rating: '4.8', price: '45k', distance: '600m', foodSlug: 'bunch'),
      home_v2.NearbyPlace(id: '3', name: 'Cơm tấm Bụi', rating: '4.6', price: '40k', distance: '400m', foodSlug: 'comga'),
      home_v2.NearbyPlace(id: '4', name: 'Saladbox Q3', rating: '4.5', price: '55k', distance: '600m', foodSlug: 'goicuon'),
    ],
    friends: const [
      home_v2.FriendActivity(name: 'Minh Trần',  text: 'check-in Bún chả Hương Liên', time: '5 phút',  emoji: '🍜'),
      home_v2.FriendActivity(name: 'Linh Hoàng', text: 'đang nấu Cá kho tộ',           time: '12 phút', emoji: '🍳', cooking: true),
    ],
    tiktoks: const [
      home_v2.TikTokVideo(name: 'Lẩu Thái 7 vị', views: '12.4k', foodSlug: 'lau'),
      home_v2.TikTokVideo(name: 'Bánh mì chảo',  views: '8.2k',  foodSlug: 'banhmi'),
    ],
  );

  static Widget aiDecideDemo(BuildContext _) => home_v2.AiDecideScreen(
    onDecide: (s) async {
      // In prod this calls HnagApi().aiDecide(); for demo we just wait.
      await Future.delayed(const Duration(milliseconds: 800));
    },
  );

  static Widget cardStackDemo(BuildContext _) => home_v2.CardStackV2(
    cards: _demoStack(),
    onAction: (card, action) {
      debugPrint('CardStack: ${card.name} → $action');
    },
  );

  static Widget foodDetailDemo(BuildContext _) => detail_v2.FoodDetailScreenV2(
    food: const detail_v2.FoodDetailDataV2(
      id: 'demo-bunbo',
      name: 'Bún bò Huế',
      foodSlug: 'bunbo',
      rating: 4.8,
      reviewCount: 1234,
      flavorTags: ['🌶 cay', 'mặn'],
      region: 'miền Trung',
      priceVnd: 50000,
      calories: 480,
      prepTimeMin: 30,
      macroLabel: 'High protein',
      hashtags: ['#cay', '#mặn', '#ấm', '#miềntrung', '#bún', '#bò'],
      aiReason: 'Đậm vị, đủ cay, đúng món miền Trung bạn thích. Cuối tuần tự nấu cho 6 người chỉ ~85k nguyên liệu.',
      ingredients: [
        (name: 'Bún sợi to',  qty: '500g'),
        (name: 'Thịt nạm bò', qty: '400g'),
        (name: 'Giò heo',     qty: '2 cái'),
        (name: 'Sả cây',      qty: '5 cây'),
        (name: 'Ớt sa tế',    qty: '2 muỗng'),
      ],
      servings: 6,
      steps: [
        (index: '01', title: 'Hầm xương bò 4 tiếng', description: 'Cho gừng nướng + củ hành nướng vào'),
        (index: '02', title: 'Phi sả ớt với dầu nóng', description: '7 phút đến khi vàng giòn'),
        (index: '03', title: 'Cho thịt nạm + giò vào hầm', description: '40 phút lửa nhỏ'),
      ],
      totalSteps: 8,
    ),
  );

  static Widget cartDemo(BuildContext context) => detail_v2.CartScreen(
    restaurantName: 'Phở Lý Quốc Sư · Q.3',
    deliveryFeeVnd: 25000,
    items: [
      detail_v2.CartItem(id: 'a', name: 'Phở bò tái',   foodSlug: 'pho',     unitPriceVnd: 45000, qty: 2),
      detail_v2.CartItem(id: 'b', name: 'Bún bò Huế',   foodSlug: 'bunbo',   unitPriceVnd: 50000, qty: 1),
      detail_v2.CartItem(id: 'c', name: 'Trà đá lipton', foodSlug: 'trasua', unitPriceVnd: 5000,  qty: 3),
    ],
    onCheckout: (items, total) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => detail_v2.CheckoutScreen(
          items: items,
          subtotalVnd: total - 25000,
          onPlaceOrder: () async {
            await Future.delayed(const Duration(seconds: 1));
            return 'demo-order-id';
          },
        ),
      ));
    },
  );

  static Widget orderTrackingDemo(BuildContext _) => const detail_v2.OrderTrackingScreen(
    orderId: 'demo000123',
    restaurantName: 'Phở Lý Quốc Sư',
    stage: detail_v2.OrderStage.delivering,
    etaText: '~ 8 phút tới',
    driverName: 'Bác Tài',
  );
}

class _Hifi {
  // Façade so main.dart only needs to import `_hifi_demo.dart`.
  static Widget homeDemo(BuildContext c)         => HifiDemo.homeDemo(c);
  static Widget aiDecideDemo(BuildContext c)     => HifiDemo.aiDecideDemo(c);
  static Widget cardStackDemo(BuildContext c)    => HifiDemo.cardStackDemo(c);
  static Widget foodDetailDemo(BuildContext c)   => HifiDemo.foodDetailDemo(c);
  static Widget cartDemo(BuildContext c)         => HifiDemo.cartDemo(c);
  static Widget orderTrackingDemo(BuildContext c)=> HifiDemo.orderTrackingDemo(c);
}
