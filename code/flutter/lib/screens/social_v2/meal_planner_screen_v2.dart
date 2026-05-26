// Meal Planner v2 — week grid 7 days × 3 meals, AI auto-fill, grocery list.
// Mirrors design/m-social.jsx#Screen_MealPlanner.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class PlannedMeal {
  final String foodId;
  final String foodName;
  final String foodSlug;
  final int? calories;
  final int? priceVnd;
  const PlannedMeal({required this.foodId, required this.foodName, required this.foodSlug, this.calories, this.priceVnd});
}

class MealPlannerScreenV2 extends StatefulWidget {
  final Map<String, Map<String, PlannedMeal?>> plan;
  final Future<PlannedMeal?> Function(String day, String meal)? onPickMeal;
  final Future<void> Function(Map<String, Map<String, PlannedMeal?>> plan)? onAutoFill;
  final VoidCallback? onGroceryList;

  const MealPlannerScreenV2({
    super.key,
    required this.plan,
    this.onPickMeal,
    this.onAutoFill,
    this.onGroceryList,
  });

  @override
  State<MealPlannerScreenV2> createState() => _MealPlannerScreenV2State();
}

class _MealPlannerScreenV2State extends State<MealPlannerScreenV2> {
  late Map<String, Map<String, PlannedMeal?>> _plan;
  bool _busy = false;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _meals = ['Sáng', 'Trưa', 'Tối'];

  @override
  void initState() {
    super.initState();
    _plan = Map<String, Map<String, PlannedMeal?>>.from(widget.plan);
    for (final d in _days) {
      _plan.putIfAbsent(d, () => {for (final m in _meals) m: null});
    }
  }

  int get _filled => _plan.values.fold<int>(0, (s, m) => s + m.values.where((v) => v != null).length);
  int get _totalSlots => _days.length * _meals.length;
  int get _budgetSum => _plan.values.fold<int>(0,
    (s, m) => s + m.values.fold<int>(0, (s2, v) => s2 + (v?.priceVnd ?? 0)));
  int get _calSum => _plan.values.fold<int>(0,
    (s, m) => s + m.values.fold<int>(0, (s2, v) => s2 + (v?.calories ?? 0)));

  Future<void> _autoFill() async {
    if (widget.onAutoFill == null) return;
    setState(() => _busy = true);
    try {
      await widget.onAutoFill!(_plan);
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
            title: 'Lịch ăn tuần',
            subtitle: '$_filled/$_totalSlots bữa · ~${(_budgetSum / 1000).round()}k · ${_calSum} cal',
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
            actions: [
              HnagIconButton(icon: 'cart', variant: IconBtnVariant.soft, onPressed: widget.onGroceryList),
            ],
          ),
          body: Column(
            children: [
              // Auto-fill hero
              Padding(
                padding: const EdgeInsets.all(16),
                child: HnagCard(
                  variant: CardVariant.gradient,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(HnagRadius.md),
                        ),
                        child: const Center(child: HnagIcon('sparkle', color: Colors.white, size: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hà tự chọn cho cả tuần',
                              style: HnagType.h4.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                            ),
                            Text('Tối ưu macro + ngân sách + Food DNA',
                              style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
                            ),
                          ],
                        ),
                      ),
                      HnagButton(
                        label: 'Auto-fill',
                        size: BtnSize.sm,
                        variant: BtnVariant.glass,
                        loading: _busy,
                        onPressed: widget.onAutoFill == null ? null : _autoFill,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _days.length,
                  itemBuilder: (_, i) {
                    final day = _days[i];
                    final meals = _plan[day] ?? {};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(day,
                              style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
                            ),
                          ),
                          Row(
                            children: [
                              for (final m in _meals) ...[
                                Expanded(child: _MealSlot(
                                  meal: meals[m],
                                  label: m,
                                  onPick: () async {
                                    if (widget.onPickMeal != null) {
                                      final result = await widget.onPickMeal!(day, m);
                                      if (result != null && mounted) {
                                        setState(() => _plan[day]![m] = result);
                                      }
                                    }
                                  },
                                  onRemove: () => setState(() => _plan[day]![m] = null),
                                )),
                                if (m != _meals.last) const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
                child: HnagButton(
                  label: 'Xuất grocery list ($_filled món)',
                  iconLeading: 'cart',
                  variant: BtnVariant.primary,
                  size: BtnSize.lg,
                  fullWidth: true,
                  onPressed: _filled > 0 ? widget.onGroceryList : null,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MealSlot extends StatelessWidget {
  final PlannedMeal? meal;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _MealSlot({required this.meal, required this.label, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    if (meal == null) {
      return HnagCard(
        variant: CardVariant.dashed,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        onTap: onPick,
        child: Column(
          children: [
            HnagIcon('plus', color: t.textMuted, size: 18),
            const SizedBox(height: 4),
            Text(label, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          ],
        ),
      );
    }
    return GestureDetector(
      onLongPress: onRemove,
      onTap: onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HnagRadius.md),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: FoodGradients.bySlug(meal!.foodSlug)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label, style: HnagType.micro.copyWith(color: Colors.black87, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(meal!.foodName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: HnagType.bodySm.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
          ),
        ],
      ),
    );
  }
}
