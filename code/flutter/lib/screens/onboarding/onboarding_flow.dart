// Onboarding flow v2 — 6 steps wired to the new design system.
//
// Steps (mirrors design_handoff_hnag/design/m-onboard.jsx):
//  1. DietAllergy   — allergens grid + diet radio list
//  2. TasteQuiz     — 12-food grid, tap to like, need ≥ 8
//  3. HateFoods     — opposite of taste, optional 0–5
//  4. BudgetGoal    — slider + cooking freq + health goal
//  5. DnaReveal     — hero card with flavor profile bars + tags
//  6. OnboardChat   — short conversational interview with Hà
//
// State is collected in `_FoodDna` and returned to the caller as a
// Map<String, dynamic> matching the original OnboardingScreen API so it can
// be persisted via HnagApi.updatePreferences().

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class OnboardingFlow extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> dna) onComplete;
  final String? userName;
  const OnboardingFlow({super.key, required this.onComplete, this.userName});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _ctrl = PageController();
  int _idx = 0;
  static const int _totalSteps = 6;

  // Collected Food DNA
  final Set<String> _allergies = {};
  String _diet = 'mặn';
  final Set<String> _loves = {};
  final Set<String> _hates = {};
  double _budget = 50;       // x1000 VND
  String _cookFreq = 'cuối-tuần';
  String _goal = 'giữ-dáng';
  bool _busy = false;

  bool get _canAdvance => switch (_idx) {
    0 => true,             // diet always picked (default 'mặn')
    1 => _loves.length >= 8,
    2 => true,             // hate is optional
    3 => true,
    4 => true,
    5 => true,
    _ => false,
  };

  void _next() {
    if (_idx >= _totalSteps - 1) return;
    setState(() => _idx++);
    _ctrl.animateToPage(_idx, duration: HnagMotion.base, curve: HnagMotion.out);
  }

  void _back() {
    if (_idx == 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() => _idx--);
    _ctrl.animateToPage(_idx, duration: HnagMotion.base, curve: HnagMotion.out);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final dna = <String, dynamic>{
      'diet': _diet,
      'allergies': _allergies.toList(),
      'budget_vnd_per_meal': (_budget * 1000).round(),
      'cook_frequency': _cookFreq,
      'health_goal': _goal,
      'loves': _loves.toList(),
      'hates': _hates.toList(),
    };
    try {
      await widget.onComplete(dna);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: '',
            transparent: true,
            leading: HnagIconButton(icon: 'chevL', onPressed: _back),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${_idx + 2} / 8',  // continue from permissions step (2/8) per design
                  style: HnagType.mono.copyWith(color: t.textMuted),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _ctrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _idx = i),
                    children: [
                      _StepDietAllergy(
                        selectedDiet: _diet,
                        selectedAllergies: _allergies,
                        onDietChanged: (d) => setState(() => _diet = d),
                        onAllergyToggle: (a) => setState(() {
                          _allergies.contains(a) ? _allergies.remove(a) : _allergies.add(a);
                        }),
                      ),
                      _StepTasteQuiz(
                        liked: _loves,
                        onToggle: (slug) => setState(() {
                          _loves.contains(slug) ? _loves.remove(slug) : _loves.add(slug);
                        }),
                      ),
                      _StepHateFoods(
                        hated: _hates,
                        onToggle: (slug) => setState(() {
                          _hates.contains(slug) ? _hates.remove(slug) : _hates.add(slug);
                        }),
                      ),
                      _StepBudgetGoal(
                        budget: _budget,
                        cookFreq: _cookFreq,
                        goal: _goal,
                        onBudget: (b) => setState(() => _budget = b),
                        onCookFreq: (c) => setState(() => _cookFreq = c),
                        onGoal: (g) => setState(() => _goal = g),
                      ),
                      _StepDnaReveal(
                        name: widget.userName ?? 'bạn',
                        loves: _loves,
                        diet: _diet,
                        budget: _budget,
                      ),
                      _StepOnboardChat(
                        onName: (_) {}, // chat is conversational, no destructive change
                      ),
                    ],
                  ),
                ),
                _BottomBar(
                  idx: _idx,
                  totalSteps: _totalSteps,
                  canAdvance: _canAdvance,
                  isLast: _idx == _totalSteps - 1,
                  loves: _loves.length,
                  busy: _busy,
                  onNext: _next,
                  onFinish: _finish,
                  onSkip: _idx == 1 ? () => _next() : null,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM BAR
// ─────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int idx;
  final int totalSteps;
  final bool canAdvance;
  final bool isLast;
  final int loves;
  final bool busy;
  final VoidCallback onNext;
  final VoidCallback onFinish;
  final VoidCallback? onSkip;

  const _BottomBar({
    required this.idx,
    required this.totalSteps,
    required this.canAdvance,
    required this.isLast,
    required this.loves,
    required this.busy,
    required this.onNext,
    required this.onFinish,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        children: [
          if (onSkip != null) ...[
            HnagButton(
              label: 'Bỏ qua',
              variant: BtnVariant.ghost,
              size: BtnSize.lg,
              onPressed: onSkip,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: HnagButton(
              label: isLast
                  ? 'Vào nhà bếp'
                  : idx == 1
                      ? 'Tiếp ($loves/8)'
                      : 'Tiếp tục',
              variant: isLast ? BtnVariant.gradient : BtnVariant.primary,
              size: BtnSize.lg,
              fullWidth: true,
              iconTrailing: 'arrowR',
              loading: busy,
              onPressed: canAdvance ? (isLast ? onFinish : onNext) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 1 — DIET + ALLERGY
// ─────────────────────────────────────────────────────────────
class _StepDietAllergy extends StatelessWidget {
  final String selectedDiet;
  final Set<String> selectedAllergies;
  final ValueChanged<String> onDietChanged;
  final ValueChanged<String> onAllergyToggle;

  const _StepDietAllergy({
    required this.selectedDiet,
    required this.selectedAllergies,
    required this.onDietChanged,
    required this.onAllergyToggle,
  });

  static const _allergens = [
    ('tôm', '🦐', 'Tôm'),
    ('đậu-phộng', '🥜', 'Đậu phộng'),
    ('gluten', '🌾', 'Gluten'),
    ('sữa', '🥛', 'Sữa'),
    ('trứng', '🥚', 'Trứng'),
    ('hải-sản', '🐟', 'Hải sản'),
    ('đậu-nành', '🫘', 'Đậu nành'),
    ('mè', '🌰', 'Mè'),
  ];

  static const _diets = [
    ('mặn', 'Mặn (default)', 'Không hạn chế'),
    ('chay-kỳ', 'Chay kỳ', 'Mùng 1, rằm'),
    ('chay-trường', 'Chay trường', 'Không thịt, không cá'),
    ('pescatarian', 'Pescatarian', 'Cá + đồ chay'),
    ('low-carb', 'Low-carb', 'Giảm tinh bột'),
    ('halal', 'Halal', 'Theo đạo Hồi'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dị ứng gì không?',
            style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              children: const [
                TextSpan(text: 'Hà sẽ '),
                TextSpan(text: 'không bao giờ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' gợi món có thứ này'),
              ],
            ),
          ),

          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allergens.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 56,
            ),
            itemBuilder: (_, i) {
              final a = _allergens[i];
              final on = selectedAllergies.contains(a.$1);
              return HnagCard(
                variant: on ? CardVariant.soft : CardVariant.outline,
                padding: const EdgeInsets.all(12),
                onTap: () => onAllergyToggle(a.$1),
                child: Row(
                  children: [
                    Text(a.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.$3,
                        style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                      ),
                    ),
                    if (on) HnagIcon('check', size: 16, color: t.brand),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),
          Text('CHẾ ĐỘ ĂN',
            style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
          ),
          const SizedBox(height: 10),
          for (final d in _diets) ...[
            HnagCard(
              variant: selectedDiet == d.$1 ? CardVariant.soft : CardVariant.outline,
              padding: const EdgeInsets.all(14),
              onTap: () => onDietChanged(d.$1),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.$2, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                        const SizedBox(height: 1),
                        Text(d.$3, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                      ],
                    ),
                  ),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selectedDiet == d.$1 ? t.brand : t.borderStrong, width: 2),
                      color: selectedDiet == d.$1 ? t.brand : Colors.transparent,
                    ),
                    child: selectedDiet == d.$1
                        ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white))
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 2 — TASTE QUIZ (12 foods grid, like ≥ 8)
// ─────────────────────────────────────────────────────────────
class _StepTasteQuiz extends StatelessWidget {
  final Set<String> liked;
  final ValueChanged<String> onToggle;

  const _StepTasteQuiz({required this.liked, required this.onToggle});

  static const _foods = [
    ('pho', 'Phở bò'),
    ('bunch', 'Bún chả'),
    ('comga', 'Cơm tấm'),
    ('banhmi', 'Bánh mì'),
    ('bunbo', 'Bún bò Huế'),
    ('goicuon', 'Gỏi cuốn'),
    ('sushi', 'Sushi'),
    ('pizza', 'Pizza'),
    ('lau', 'Lẩu Thái'),
    ('comtam', 'Cơm tấm bì'),
    ('mi', 'Mì cay'),
    ('trasua', 'Trà sữa'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn yêu món nào?',
            style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              children: [
                const TextSpan(text: 'Chạm để chọn · cần ≥ 8 món · '),
                TextSpan(
                  text: 'đã chọn ${liked.length}',
                  style: TextStyle(color: t.brand, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          HnagProgress(value: liked.length.toDouble().clamp(0, 10), max: 10, height: 4),

          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _foods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.82,
            ),
            itemBuilder: (_, i) {
              final food = _foods[i];
              final on = liked.contains(food.$1);
              return GestureDetector(
                onTap: () => onToggle(food.$1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: HnagMotion.fast,
                        curve: HnagMotion.spring,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(HnagRadius.lg),
                          gradient: FoodGradients.bySlug(food.$1),
                          boxShadow: on
                              ? [
                                  BoxShadow(color: t.brand, spreadRadius: 3, blurRadius: 0),
                                  BoxShadow(color: t.brand.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -4),
                                ]
                              : t.shadow1,
                        ),
                        transform: on ? (Matrix4.identity()..scale(0.97)) : Matrix4.identity(),
                        transformAlignment: Alignment.center,
                        child: Stack(
                          children: [
                            if (on)
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: t.brand.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(HnagRadius.lg),
                                  ),
                                ),
                              )
                            else
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                      stops: const [0.5, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(HnagRadius.lg),
                                  ),
                                ),
                              ),
                            if (on)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: t.shadow2,
                                  ),
                                  child: Center(child: HnagIcon('heart', size: 14, color: t.brand)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      food.$2,
                      textAlign: TextAlign.center,
                      style: HnagType.label.copyWith(color: t.text, fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 3 — HATE FOODS (optional)
// ─────────────────────────────────────────────────────────────
class _StepHateFoods extends StatelessWidget {
  final Set<String> hated;
  final ValueChanged<String> onToggle;

  const _StepHateFoods({required this.hated, required this.onToggle});

  static const _options = [
    ('mắm-tôm', '🦐', 'Mắm tôm'),
    ('sầu-riêng', '🫒', 'Sầu riêng'),
    ('nội-tạng', '🫀', 'Nội tạng'),
    ('thịt-chó', '🐕', 'Thịt chó'),
    ('tiết-canh', '🩸', 'Tiết canh'),
    ('cay-quá', '🌶', 'Cay quá'),
    ('béo-mỡ', '🥓', 'Béo mỡ'),
    ('ngọt-quá', '🍰', 'Ngọt quá'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Có gì bạn không thích?',
            style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          const SizedBox(height: 6),
          Text('Tuỳ chọn · chọn 0–5 món Hà sẽ tránh',
            style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),

          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 56,
            ),
            itemBuilder: (_, i) {
              final o = _options[i];
              final on = hated.contains(o.$1);
              return HnagCard(
                variant: on ? CardVariant.soft : CardVariant.outline,
                padding: const EdgeInsets.all(12),
                onTap: () => onToggle(o.$1),
                child: Row(
                  children: [
                    Text(o.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o.$3, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body))),
                    if (on) HnagIcon('x', size: 16, color: t.danger),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          HnagCard(
            variant: CardVariant.soft,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HnagIcon('info', size: 18, color: HnagColors.brand500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hà sẽ không bao giờ gợi món có thứ này. Có thể đổi sau ở Settings.',
                    style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 4 — BUDGET + GOAL
// ─────────────────────────────────────────────────────────────
class _StepBudgetGoal extends StatelessWidget {
  final double budget;
  final String cookFreq;
  final String goal;
  final ValueChanged<double> onBudget;
  final ValueChanged<String> onCookFreq;
  final ValueChanged<String> onGoal;

  const _StepBudgetGoal({
    required this.budget,
    required this.cookFreq,
    required this.goal,
    required this.onBudget,
    required this.onCookFreq,
    required this.onGoal,
  });

  String _budgetRange(double v) {
    final lower = (v * 0.6).round();
    final upper = (v * 1.4).round();
    return '${lower}–${upper}k';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ngân sách mỗi bữa?',
            style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          const SizedBox(height: 6),
          Text('Có thể đổi sau · không cố định',
            style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),

          const SizedBox(height: 24),
          HnagCard(
            variant: CardVariant.elevated,
            padding: const EdgeInsets.all(28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [t.brandSoft, t.bgElev],
                ),
                borderRadius: BorderRadius.circular(HnagRadius.md),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('KHOẢNG', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                  const SizedBox(height: 6),
                  Text(
                    _budgetRange(budget),
                    style: HnagType.d1.copyWith(color: t.brand, fontFamily: HnagFonts.display, letterSpacing: -2.4),
                  ),
                  const SizedBox(height: 6),
                  Text('~${budget.round()}k₫ / bữa trung bình',
                    style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          HnagSlider(
            value: budget,
            min: 20, max: 500,
            leading: '20k',
            trailing: '500k',
            onChanged: onBudget,
          ),

          const SizedBox(height: 28),
          Text('BẠN CÓ NẤU KHÔNG?',
            style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final c in const [
                ('không-nấu', 'Không nấu'),
                ('cuối-tuần', 'Cuối tuần'),
                ('hằng-ngày', 'Hằng ngày'),
              ])
                HnagChip(
                  label: c.$2,
                  active: cookFreq == c.$1,
                  onTap: () => onCookFreq(c.$1),
                ),
            ],
          ),

          const SizedBox(height: 28),
          Text('MỤC TIÊU SỨC KHOẺ',
            style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final g in const [
                ('giữ-dáng',     'Giữ dáng',     'leaf'),
                ('giảm-cân',     'Giảm cân',     'target'),
                ('tăng-cân',     'Tăng cân',     null),
                ('khoẻ-mạnh',    'Khoẻ mạnh',    null),
                ('không-quan-tâm','Không quan tâm', null),
              ])
                HnagChip(
                  label: g.$2,
                  icon: g.$3,
                  active: goal == g.$1,
                  onTap: () => onGoal(g.$1),
                ),
            ],
          ),

          const SizedBox(height: 24),
          HnagCard(
            variant: CardVariant.soft,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HnagIcon('info', size: 18, color: HnagColors.brand500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hà sẽ tự nới hoặc thắt ngân sách khi cần — VD bữa đặc biệt cuối tuần.',
                    style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 5 — DNA REVEAL
// ─────────────────────────────────────────────────────────────
class _StepDnaReveal extends StatelessWidget {
  final String name;
  final Set<String> loves;
  final String diet;
  final double budget;

  const _StepDnaReveal({required this.name, required this.loves, required this.diet, required this.budget});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    // Heuristic flavor profile from selected loves
    int cay = 0, ngot = 0, umami = 0, chua = 0;
    for (final f in loves) {
      if (['bunbo','mi','lau'].contains(f)) cay += 25;
      if (['trasua','che','comtam'].contains(f)) ngot += 30;
      if (['pho','comga','sushi','banhmi'].contains(f)) umami += 25;
      if (['goicuon','salad','goi'].contains(f)) chua += 25;
    }
    cay = cay.clamp(0, 100); ngot = ngot.clamp(0, 100);
    umami = umami.clamp(0, 100); chua = chua.clamp(0, 100);

    final budgetTag = '${(budget * 0.6).round()}–${(budget * 1.4).round()}k';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const HnagBadge(label: 'FOOD DNA', variant: BadgeVariant.soft, icon: 'sparkle'),
              const HnagIconButton(icon: 'share', variant: IconBtnVariant.soft),
            ],
          ),
          const SizedBox(height: 28),
          Text('Chào,\n$name',
            style: HnagType.d2.copyWith(color: t.text, fontFamily: HnagFonts.display, letterSpacing: -1.2)),
          const SizedBox(height: 8),
          Text('Hà đã xây hồ sơ vị giác cho bạn:',
            style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),

          const SizedBox(height: 22),
          // DNA hero card
          HnagCard(
            variant: CardVariant.elevated,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header gradient with aurora
                Container(
                  decoration: const BoxDecoration(gradient: HnagGradients.brand),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HnagBadge(label: 'Mực 🦑 · Level 4', variant: BadgeVariant.glass),
                      const SizedBox(height: 12),
                      Text(
                        '"Đứa thích cay, mê Việt miền Trung, ăn lành mạnh"',
                        style: HnagType.h2.copyWith(color: Colors.white, fontFamily: HnagFonts.display, letterSpacing: -0.4),
                      ),
                    ],
                  ),
                ),
                // Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: _stat(context, '86', 'món sẵn sàng')),
                      Expanded(child: _stat(context, '14k', 'quán quanh bạn')),
                      Expanded(child: _stat(context, '6', 'AI engines')),
                    ],
                  ),
                ),
                const HnagDivider(),
                // Flavor bars
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VỊ GIÁC', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                      const SizedBox(height: 10),
                      _bar(context, 'Cay', cay, t.danger),
                      _bar(context, 'Ngọt', ngot, t.warning),
                      _bar(context, 'Umami', umami, t.brand),
                      _bar(context, 'Chua', chua, t.success),
                    ],
                  ),
                ),
                const HnagDivider(),
                // Tags
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      const HnagBadge(label: '🌶 cay', variant: BadgeVariant.soft),
                      const HnagBadge(label: '🥗 healthy', variant: BadgeVariant.success),
                      const HnagBadge(label: '📍 quanh bạn'),
                      HnagBadge(label: '💰 $budgetTag'),
                      HnagBadge(label: '🍽 $diet'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Center(
            child: Text('✨ Cập nhật mỗi tuần theo hành vi thực',
              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final t = context.hnag;
    return Column(
      children: [
        Text(value, style: HnagType.numLg.copyWith(color: t.brand, fontFamily: HnagFonts.display)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
          style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
      ],
    );
  }

  Widget _bar(BuildContext context, String label, int value, Color color) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: HnagType.labelSm.copyWith(color: t.text, fontFamily: HnagFonts.body))),
          Expanded(child: HnagProgress(value: value.toDouble(), max: 100, color: color)),
          const SizedBox(width: 10),
          SizedBox(width: 32, child: Text('$value%', textAlign: TextAlign.right, style: HnagType.mono.copyWith(color: t.textMuted))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 6 — ONBOARD CHAT (conversational interview with Hà)
// ─────────────────────────────────────────────────────────────
class _StepOnboardChat extends StatefulWidget {
  final ValueChanged<String>? onName;
  const _StepOnboardChat({this.onName});

  @override
  State<_StepOnboardChat> createState() => _StepOnboardChatState();
}

class _StepOnboardChatState extends State<_StepOnboardChat> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(text: 'Một câu cuối nha — bạn thường ăn 1 mình hay với ai?', fromHa: true),
  ];
  bool _typing = false;

  void _send(String reply) {
    setState(() {
      _messages.add(_ChatMessage(text: reply, fromHa: false));
      _typing = true;
    });
    Future.delayed(HnagMotion.slow, () {
      if (!mounted) return;
      String response = 'Tuyệt vời! Mình đã hiểu hơn về bạn rồi.';
      if (reply.toLowerCase().contains('một mình')) {
        response = 'Một mình là phong cách 🫶. Hà sẽ ưu tiên món vừa khẩu phần cá nhân.';
      } else if (reply.toLowerCase().contains('gia đình')) {
        response = 'Gia đình ấm cúng — Hà sẽ gợi thêm món chia sẻ.';
      } else if (reply.toLowerCase().contains('bạn')) {
        response = 'Đi với bạn vui ghê! Hà nhớ gợi quán không gian rộng nha.';
      }
      setState(() {
        _typing = false;
        _messages.add(_ChatMessage(text: response, fromHa: true));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          // Top intro
          Row(
            children: [
              const HnagAvatar(name: 'Hà', size: 48, ring: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hà · AI Assistant',
                      style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display)),
                    Row(
                      children: [
                        const HnagStatusDot(),
                        const SizedBox(width: 6),
                        Text('đang online',
                          style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Messages
          Expanded(
            child: ListView(
              reverse: false,
              children: [
                for (final m in _messages) _bubble(context, m),
                if (_typing) _typingDots(context),
              ],
            ),
          ),

          // Quick replies
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final reply in ['Một mình 🧘', 'Với gia đình 👨‍👩‍👧', 'Với bạn bè 🍻'])
                HnagChip(label: reply, onTap: _typing ? null : () => _send(reply)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, _ChatMessage m) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: m.fromHa ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (m.fromHa) const HnagAvatar(name: 'Hà', size: 28),
          if (m.fromHa) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.fromHa ? t.bgMuted : t.brand,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(HnagRadius.md),
                  topRight: const Radius.circular(HnagRadius.md),
                  bottomLeft: Radius.circular(m.fromHa ? 4 : HnagRadius.md),
                  bottomRight: Radius.circular(m.fromHa ? HnagRadius.md : 4),
                ),
              ),
              child: Text(
                m.text,
                style: HnagType.body.copyWith(
                  color: m.fromHa ? t.text : Colors.white,
                  fontFamily: HnagFonts.body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingDots(BuildContext context) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const HnagAvatar(name: 'Hà', size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.bgMuted,
              borderRadius: BorderRadius.circular(HnagRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(width: 5, height: 5,
                  decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle)),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromHa;
  const _ChatMessage({required this.text, required this.fromHa});
}
