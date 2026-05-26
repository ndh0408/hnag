// Premium HNAG+ — dark pricing tiers with aurora background.
// Mirrors design/m-premium.jsx (3 tiers: Free / Plus / Family).

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class PremiumPlan {
  final String id;
  final String name;
  final String price;
  final String? priceSub;
  final String? badge;
  final List<String> features;
  final bool highlight;
  const PremiumPlan({
    required this.id,
    required this.name,
    required this.price,
    this.priceSub,
    this.badge,
    required this.features,
    this.highlight = false,
  });
}

class PremiumScreenV2 extends StatefulWidget {
  final Future<void> Function(String planId) onSubscribe;
  final VoidCallback? onClose;
  const PremiumScreenV2({super.key, required this.onSubscribe, this.onClose});

  static const plans = [
    PremiumPlan(
      id: 'free', name: 'Free', price: '0₫', priceSub: 'mãi mãi',
      features: [
        '3 AI Decide / ngày',
        'Mood Food cơ bản',
        'Search + map cơ bản',
        'Có quảng cáo',
      ],
    ),
    PremiumPlan(
      id: 'plus', name: 'HNAG+', price: '49k', priceSub: '/ tháng', badge: 'PHỔ BIẾN',
      highlight: true,
      features: [
        'Unlimited AI Decide',
        'Tất cả 6 engines',
        'Fridge Vision + Voice Hà',
        'Không quảng cáo',
        'Premium gradient theme',
        'Meal Planner 7 ngày',
      ],
    ),
    PremiumPlan(
      id: 'family', name: 'Family', price: '99k', priceSub: '/ tháng',
      features: [
        'Tất cả của Plus',
        '5 thành viên',
        'Couple Mode 💞',
        'Shared meal planner',
        'Family kitchen recipes',
        'Priority support',
      ],
    ),
  ];

  @override
  State<PremiumScreenV2> createState() => _PremiumScreenV2State();
}

class _PremiumScreenV2State extends State<PremiumScreenV2> {
  String _selectedId = 'plus';
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      await widget.onSubscribe(_selectedId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: true,
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: HnagColors.neutral950,
          body: Stack(
            children: [
              const Positioned.fill(child: AuroraBackground(opacity: 0.45)),
              SafeArea(
                child: Column(
                  children: [
                    HnagAppBar(
                      transparent: true,
                      title: '',
                      leading: HnagIconButton(
                        icon: 'x',
                        variant: IconBtnVariant.glass,
                        onPressed: widget.onClose ?? () => Navigator.maybePop(context),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        children: [
                          // Header
                          Center(
                            child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                gradient: HnagGradients.premium,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: HnagColors.brand500.withOpacity(0.5), blurRadius: 40, spreadRadius: 4)],
                              ),
                              child: const Center(child: HnagIcon('crown', size: 40, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text('HNAG+',
                            textAlign: TextAlign.center,
                            style: HnagType.d2.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Unlock unlimited AI · ẩn quảng cáo · Premium theme',
                            textAlign: TextAlign.center,
                            style: HnagType.bodyLg.copyWith(color: Colors.white.withOpacity(0.7), fontFamily: HnagFonts.body),
                          ),

                          const SizedBox(height: 28),
                          for (final p in PremiumScreenV2.plans) _PlanCard(
                            plan: p,
                            selected: _selectedId == p.id,
                            onTap: () => setState(() => _selectedId = p.id),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: Column(
                        children: [
                          HnagButton(
                            label: _selectedId == 'free' ? 'Đang dùng Free' : 'Đăng ký ${_planById(_selectedId).name}',
                            variant: BtnVariant.gradient,
                            size: BtnSize.xl,
                            fullWidth: true,
                            loading: _busy,
                            onPressed: _selectedId == 'free' || _busy ? null : _subscribe,
                          ),
                          const SizedBox(height: 8),
                          Text('Huỷ bất cứ lúc nào · không tính phí thiết lập',
                            style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.5), fontFamily: HnagFonts.body),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  PremiumPlan _planById(String id) => PremiumScreenV2.plans.firstWhere((p) => p.id == id);
}

class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glowColor = plan.highlight ? HnagColors.brand500 : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HnagMotion.fast,
        curve: HnagMotion.out,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: selected && plan.highlight ? HnagGradients.brand : null,
          color: selected
              ? (plan.highlight ? null : Colors.white.withOpacity(0.12))
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(HnagRadius.xl),
          border: Border.all(
            color: selected ? glowColor : Colors.white.withOpacity(0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected && plan.highlight
              ? [BoxShadow(color: HnagColors.brand500.withOpacity(0.4), blurRadius: 30, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.name,
                  style: HnagType.h1.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                ),
                if (plan.badge != null) ...[
                  const SizedBox(width: 8),
                  HnagBadge(label: plan.badge!, size: BadgeSize.sm, variant: BadgeVariant.glass),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price,
                  style: HnagType.numLg.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                ),
                if (plan.priceSub != null) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(plan.priceSub!,
                      style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.7), fontFamily: HnagFonts.body),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            for (final f in plan.features) Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f,
                      style: HnagType.body.copyWith(color: Colors.white.withOpacity(0.9), fontFamily: HnagFonts.body),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
