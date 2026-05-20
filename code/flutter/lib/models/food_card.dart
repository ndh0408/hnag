/// HNAG domain models. Plain Dart for clarity — wire up freezed+json_serializable
/// in production (see pubspec). Mirrors the FoodCard schema in docs/06-VISUAL-FEED.md.
class FoodCard {
  final String cardId;
  final String foodId;
  final String title;
  final String? subtitle;
  final CardMedia media;
  final List<CardBadge> badges;
  final CardPrice price;
  final CardRating rating;
  final CardDistance distance;
  final int? calories;
  final List<String> tags;
  final CardLiveStatus? liveStatus;
  final String aiReason;
  final CardActions actions;
  final CardSocialProof? socialProof;

  const FoodCard({
    required this.cardId,
    required this.foodId,
    required this.title,
    this.subtitle,
    required this.media,
    this.badges = const [],
    required this.price,
    required this.rating,
    required this.distance,
    this.calories,
    this.tags = const [],
    this.liveStatus,
    required this.aiReason,
    required this.actions,
    this.socialProof,
  });

  factory FoodCard.fromJson(Map<String, dynamic> j) => FoodCard(
        cardId: j['cardId'] as String,
        foodId: j['foodId'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        media: CardMedia.fromJson(j['media'] as Map<String, dynamic>),
        badges: (j['badges'] as List? ?? []).map((e) => CardBadge.fromJson(e)).toList(),
        price: CardPrice.fromJson(j['price'] as Map<String, dynamic>),
        rating: CardRating.fromJson(j['rating'] as Map<String, dynamic>),
        distance: CardDistance.fromJson(j['distance'] as Map<String, dynamic>),
        calories: j['calories'] as int?,
        tags: (j['tags'] as List? ?? []).cast<String>(),
        liveStatus: j['liveStatus'] != null ? CardLiveStatus.fromJson(j['liveStatus']) : null,
        aiReason: (j['aiReason'] as String?) ?? '',
        actions: CardActions.fromJson(j['actions'] as Map<String, dynamic>),
        socialProof: j['socialProof'] != null ? CardSocialProof.fromJson(j['socialProof']) : null,
      );

  /// Bank of high-quality Vietnamese food images from Unsplash.
  /// Indexed by dish keyword → returns full URL.
  static const Map<String, String> _imageBank = {
    'pho':       'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=800',
    'bun-bo':    'https://images.unsplash.com/photo-1597138804456-e7dca7f59d52?w=800',
    'banh-mi':   'https://images.unsplash.com/photo-1600326145552-327c4df2c246?w=800',
    'com-tam':   'https://images.unsplash.com/photo-1583394293214-28ded15ee548?w=800',
    'bun-cha':   'https://images.unsplash.com/photo-1576577445504-6af96477db52?w=800',
    'goi-cuon':  'https://images.unsplash.com/photo-1553787499-6f9133860278?w=800',
    'banh-xeo':  'https://images.unsplash.com/photo-1565895405138-6c3a1555da6a?w=800',
    'lau':       'https://images.unsplash.com/photo-1552611052-33e04de081de?w=800',
    'sushi':     'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
    'ramen':     'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=800',
    'pizza':     'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800',
    'burger':    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
    'cafe':      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
    'trasua':    'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=800',
    'salad':     'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
    'bbq':       'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800',
  };

  static String imageFor(String slug) {
    final lower = slug.toLowerCase();
    for (final e in _imageBank.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return _imageBank.values.first;
  }

  static const _defaultRestaurantCover = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200';

  // Demo data for previewing widgets
  static FoodCard demo() => const FoodCard(
        cardId: 'demo-1',
        foodId: 'f0000000-0000-0000-0000-000000000011',
        title: 'Bún bò Huế đặc biệt',
        subtitle: 'Quán Bà Hai · 12 Lê Lợi',
        media: CardMedia(
          poster: 'https://images.unsplash.com/photo-1597138804456-e7dca7f59d52?w=1200&q=85',
          blurhash: 'L9C@4|D%01M{02D%-pIA0LIo-=Rj',
        ),
        badges: [
          CardBadge(type: 'trending', text: '#1 Trending Q1', icon: '🔥'),
          CardBadge(type: 'ai_pick',  text: 'Hà gợi ý',        icon: '✨'),
        ],
        price: CardPrice(amount: 45000, display: '45k ₫', vsUserBudget: 'in_range'),
        rating: CardRating(avg: 4.8, count: 1234, verified: true),
        distance: CardDistance(meters: 600, display: '600m', walkMin: 8, deliveryMin: 12),
        calories: 480,
        tags: ['cay vừa', 'ấm bụng', 'miền trung'],
        liveStatus: CardLiveStatus(
          isOpen: true,
          closingInMin: 240,
          crowdedness: 0.72,
          waitMinutes: 5,
          recentOrders24h: 387,
        ),
        aiReason: 'Trời mưa Hà Nội — ấm bụng cho ngày se lạnh',
        actions: CardActions(
          cookEnabled: true,
          orderPrimary: 'grabfood',
          orderDeeplink: 'grabfood://restaurant/abc',
          dineEnabled: true,
        ),
      );

  /// Bank of pre-built demo cards (varied dishes + images).
  static List<FoodCard> demos() => const [
        FoodCard(
          cardId: 'd1', foodId: 'f1', title: 'Bún bò Huế đặc biệt', subtitle: 'Quán Bà Hai · 600m',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1597138804456-e7dca7f59d52?w=1200&q=85'),
          badges: [CardBadge(type:'trending',text:'🔥 #1 Trending',icon:''), CardBadge(type:'ai_pick',text:'✨ Hà gợi ý',icon:'')],
          price: CardPrice(amount: 45000, display: '45k ₫'),
          rating: CardRating(avg: 4.8, count: 1234, verified: true),
          distance: CardDistance(meters: 600, display: '600m', deliveryMin: 12),
          calories: 480, tags: ['cay vừa','ấm bụng','miền trung'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.72, waitMinutes: 5, recentOrders24h: 387),
          aiReason: 'Trời mưa Hà Nội — ấm bụng cho ngày se lạnh',
          actions: CardActions(cookEnabled: true, orderPrimary: 'grabfood', orderDeeplink: '', dineEnabled: true),
        ),
        FoodCard(
          cardId: 'd2', foodId: 'f2', title: 'Phở bò tái nạm', subtitle: 'Phở Lý Quốc Sư · 800m',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=1200&q=85'),
          badges: [CardBadge(type:'top',text:'⭐ Top rated',icon:'')],
          price: CardPrice(amount: 55000, display: '55k ₫'),
          rating: CardRating(avg: 4.9, count: 3400, verified: true),
          distance: CardDistance(meters: 800, display: '800m', deliveryMin: 14),
          calories: 450, tags: ['truyền thống','ấm','miền bắc'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.55, waitMinutes: 3, recentOrders24h: 612),
          aiReason: 'Phở Hà Nội đậm vị — bữa sáng quốc dân',
          actions: CardActions(cookEnabled: false, orderPrimary: 'grabfood', orderDeeplink: '', dineEnabled: true),
        ),
        FoodCard(
          cardId: 'd3', foodId: 'f3', title: 'Cơm tấm sườn nướng', subtitle: 'Cơm Tấm Ba Ghiền · 1.2km',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1583394293214-28ded15ee548?w=1200&q=85'),
          badges: [CardBadge(type:'viral',text:'🎬 Viral TikTok',icon:'')],
          price: CardPrice(amount: 55000, display: '55k ₫'),
          rating: CardRating(avg: 4.7, count: 890, verified: true),
          distance: CardDistance(meters: 1200, display: '1.2km', deliveryMin: 18),
          calories: 680, tags: ['miền nam','no bụng','sườn nướng'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.88, waitMinutes: 8, recentOrders24h: 524),
          aiReason: 'Trưa nay đói cồn cào — cơm tấm bao no',
          actions: CardActions(cookEnabled: false, orderPrimary: 'shopeefood', orderDeeplink: '', dineEnabled: true),
        ),
        FoodCard(
          cardId: 'd4', foodId: 'f4', title: 'Bánh mì Huỳnh Hoa', subtitle: 'Q1 · 450m',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1600326145552-327c4df2c246?w=1200&q=85'),
          badges: [CardBadge(type:'fast',text:'⚡ < 5 phút',icon:'')],
          price: CardPrice(amount: 38000, display: '38k ₫'),
          rating: CardRating(avg: 4.6, count: 2100, verified: true),
          distance: CardDistance(meters: 450, display: '450m', deliveryMin: 10),
          calories: 500, tags: ['nhanh','bình dân','sáng'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.30, waitMinutes: 1, recentOrders24h: 1200),
          aiReason: 'Vội rồi à? 5 phút có bánh mì pate Huỳnh Hoa nha',
          actions: CardActions(cookEnabled: false, orderPrimary: 'grabfood', orderDeeplink: '', dineEnabled: true),
        ),
        FoodCard(
          cardId: 'd5', foodId: 'f5', title: 'Lẩu Thái nguyên liệu tươi', subtitle: 'Lẩu Phan · 2km',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=1200&q=85'),
          badges: [CardBadge(type:'group',text:'👥 Cho nhóm',icon:'')],
          price: CardPrice(amount: 180000, display: '180k/người'),
          rating: CardRating(avg: 4.5, count: 670, verified: true),
          distance: CardDistance(meters: 2000, display: '2.0km', deliveryMin: 25),
          calories: 580, tags: ['nhóm','cay nồng','chia sẻ'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.65, waitMinutes: 10, recentOrders24h: 240),
          aiReason: 'Cuối tuần đông bạn — lẩu Thái xua tan stress',
          actions: CardActions(cookEnabled: false, orderPrimary: 'grabfood', orderDeeplink: '', dineEnabled: true),
        ),
        FoodCard(
          cardId: 'd6', foodId: 'f6', title: 'Trà sữa trân châu đường đen', subtitle: 'Tocotoco · 350m',
          media: CardMedia(poster: 'https://images.unsplash.com/photo-1558857563-c0c8de2e0307?w=1200&q=85'),
          badges: [CardBadge(type:'genz',text:'💜 Gen Z thích',icon:'')],
          price: CardPrice(amount: 55000, display: '55k ₫'),
          rating: CardRating(avg: 4.4, count: 1800, verified: false),
          distance: CardDistance(meters: 350, display: '350m', deliveryMin: 8),
          calories: 340, tags: ['ngọt','mát','snack'],
          liveStatus: CardLiveStatus(isOpen: true, crowdedness: 0.42, waitMinutes: 2, recentOrders24h: 489),
          aiReason: 'Chiều nay cần ngọt cho khoẻ — trân châu sủi bọt',
          actions: CardActions(cookEnabled: false, orderPrimary: 'shopeefood', orderDeeplink: '', dineEnabled: false),
        ),
      ];
}

class CardMedia {
  final String? primaryVideo;
  final String poster;
  final String? blurhash;
  final List<String> images;
  const CardMedia({this.primaryVideo, required this.poster, this.blurhash, this.images = const []});
  factory CardMedia.fromJson(Map<String, dynamic> j) => CardMedia(
        primaryVideo: j['primaryVideo'] as String?,
        poster: j['poster'] as String,
        blurhash: j['blurhash'] as String?,
        images: (j['images'] as List? ?? []).cast<String>(),
      );
}

class CardBadge {
  final String type;
  final String text;
  final String icon;
  const CardBadge({required this.type, required this.text, required this.icon});
  factory CardBadge.fromJson(Map<String, dynamic> j) => CardBadge(type: j['type'], text: j['text'], icon: j['icon']);
}

class CardPrice {
  final int amount;
  final String display;
  final String vsUserBudget; // in_range | above | below
  const CardPrice({required this.amount, required this.display, this.vsUserBudget = 'in_range'});
  factory CardPrice.fromJson(Map<String, dynamic> j) => CardPrice(
        amount: j['amount'],
        display: j['display'] ?? '${j['amount']} ₫',
        vsUserBudget: j['vsUserBudget'] ?? 'in_range',
      );
}

class CardRating {
  final double avg;
  final int count;
  final bool verified;
  const CardRating({required this.avg, required this.count, this.verified = false});
  factory CardRating.fromJson(Map<String, dynamic> j) =>
      CardRating(avg: (j['avg'] as num).toDouble(), count: j['count'], verified: j['verified'] ?? false);
}

class CardDistance {
  final int meters;
  final String display;
  final int? walkMin;
  final int? deliveryMin;
  const CardDistance({required this.meters, required this.display, this.walkMin, this.deliveryMin});
  factory CardDistance.fromJson(Map<String, dynamic> j) => CardDistance(
        meters: j['meters'],
        display: j['display'] ?? '${j['meters']}m',
        walkMin: j['walkMin'],
        deliveryMin: j['deliveryMin'],
      );
}

class CardLiveStatus {
  final bool isOpen;
  final int? closingInMin;
  final double? crowdedness;
  final int? waitMinutes;
  final int? recentOrders24h;
  const CardLiveStatus({required this.isOpen, this.closingInMin, this.crowdedness, this.waitMinutes, this.recentOrders24h});
  factory CardLiveStatus.fromJson(Map<String, dynamic> j) => CardLiveStatus(
        isOpen: j['isOpen'] ?? true,
        closingInMin: j['closingInMin'],
        crowdedness: j['crowdedness'] != null ? (j['crowdedness'] as num).toDouble() : null,
        waitMinutes: j['waitMinutes'],
        recentOrders24h: j['recentOrders24h'],
      );
}

class CardActions {
  final bool cookEnabled;
  final String? recipeId;
  final String orderPrimary;
  final String orderDeeplink;
  final bool dineEnabled;
  final String? dineNavigation;
  const CardActions({
    this.cookEnabled = false,
    this.recipeId,
    required this.orderPrimary,
    required this.orderDeeplink,
    this.dineEnabled = false,
    this.dineNavigation,
  });
  factory CardActions.fromJson(Map<String, dynamic> j) {
    final cook  = j['cook']  as Map<String, dynamic>?;
    final order = j['order'] as Map<String, dynamic>? ?? {};
    final dine  = j['dine']  as Map<String, dynamic>?;
    return CardActions(
      cookEnabled: cook?['enabled'] ?? false,
      recipeId:    cook?['recipeId'],
      orderPrimary: order['primary']  ?? 'grabfood',
      orderDeeplink: order['deeplink'] ?? '',
      dineEnabled: (dine?['navigation'] as String?) != null,
      dineNavigation: dine?['navigation'],
    );
  }
}

class CardSocialProof {
  final int friendCount;
  final List<FriendBadge> friendsBeen;
  const CardSocialProof({this.friendCount = 0, this.friendsBeen = const []});
  factory CardSocialProof.fromJson(Map<String, dynamic> j) => CardSocialProof(
        friendCount: j['friendCount'] ?? 0,
        friendsBeen: (j['friendsBeen'] as List? ?? []).map((e) => FriendBadge.fromJson(e)).toList(),
      );
}

class FriendBadge {
  final String id;
  final String name;
  final String avatar;
  const FriendBadge({required this.id, required this.name, required this.avatar});
  factory FriendBadge.fromJson(Map<String, dynamic> j) => FriendBadge(
        id: j['id'], name: j['displayName'] ?? j['name'] ?? '', avatar: j['avatarUrl'] ?? j['avatar'] ?? '',
      );
}

/// Swipe outcomes
enum SwipeAction { skip, save, openDetail, later }
