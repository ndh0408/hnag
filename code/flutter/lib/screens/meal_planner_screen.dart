import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';

class MealSlot {
  final String foodName;
  final int calories;
  final int priceVnd;
  final String type; // cook | order | dine
  const MealSlot({required this.foodName, required this.calories, required this.priceVnd, required this.type});
}

class MealDay {
  final MealSlot? breakfast;
  final MealSlot? lunch;
  final MealSlot? dinner;
  final MealSlot? snack;
  const MealDay({this.breakfast, this.lunch, this.dinner, this.snack});
}

class MealPlannerScreen extends StatefulWidget {
  final Map<String, MealDay> initialPlan; // 'mon','tue',...
  final Future<void> Function()? onAiGenerate;
  const MealPlannerScreen({super.key, this.initialPlan = const {}, this.onAiGenerate});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  late Map<String, MealDay> _plan;
  final _api = HnagApi();
  List<Map<String, dynamic>> _grocery = [];
  bool _busy = false;
  static const _days = ['mon','tue','wed','thu','fri','sat','sun'];
  static const _dayLabels = ['T2','T3','T4','T5','T6','T7','CN'];
  static const _slots = ['breakfast','lunch','dinner','snack'];

  @override
  void initState() {
    super.initState();
    _plan = {..._defaultPlan(), ...widget.initialPlan};
    _loadCurrent();
  }

  Map<String, MealDay> _defaultPlan() => {for (final d in _days) d: const MealDay()};

  Future<void> _loadCurrent() async {
    final data = await _api.currentMealPlan();
    if (data != null && mounted) _applyPlan(data);
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final data = await _api.generateMealPlan(budgetPerDay: 150000);
      if (data != null && mounted) _applyPlan(data);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    widget.onAiGenerate?.call();
  }

  void _applyPlan(Map<String, dynamic> data) {
    final planJson = data['plan_json'] as Map<String, dynamic>? ?? {};
    final next = <String, MealDay>{};
    for (final d in _days) {
      final day = planJson[d] as Map<String, dynamic>? ?? {};
      MealSlot? slot(String key) {
        final s = day[key] as Map<String, dynamic>?;
        if (s == null) return null;
        return MealSlot(
          foodName: s['name'] as String? ?? '',
          calories: (s['calories'] as int?) ?? 0,
          priceVnd: (s['priceVnd'] as int?) ?? 0,
          type: 'cook',
        );
      }
      next[d] = MealDay(breakfast: slot('breakfast'), lunch: slot('lunch'), dinner: slot('dinner'), snack: slot('snack'));
    }
    setState(() {
      _plan = next;
      _grocery = ((data['shopping_list'] as List?) ?? []).cast<Map<String, dynamic>>();
    });
  }

  void _showGrocery() {
    if (_grocery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo plan trước để có shopping list')));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.9,
      builder: (_, sc) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('🛒 ', style: TextStyle(fontSize: 22)),
          Text('Đi chợ — ${_grocery.length} nguyên liệu', style: AppTypography.headingSm),
        ])),
        Expanded(child: ListView.builder(
          controller: sc, itemCount: _grocery.length,
          itemBuilder: (_, i) {
            final g = _grocery[i];
            return CheckboxListTile(
              value: false, onChanged: (_) {},
              activeColor: AppColors.phoOrange,
              title: Text(g['name'] as String? ?? ''),
              secondary: (g['count'] as int? ?? 1) > 1
                  ? Chip(label: Text('×${g['count']}'), visualDensity: VisualDensity.compact)
                  : null,
            );
          },
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totals = _computeTotals();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kế hoạch tuần'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.phoOrange))
                : const Icon(Icons.auto_awesome, color: AppColors.phoOrange),
            tooltip: 'AI auto-plan',
            onPressed: _busy ? null : _generate,
          ),
        ],
      ),
      body: Column(children: [
        _summary(totals),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 7 * 120 + 80,
              child: Column(children: [
                _headerRow(),
                for (final slot in _slots) _slotRow(slot),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _showGrocery,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(_grocery.isEmpty ? 'Đi chợ' : 'Đi chợ (${_grocery.length})'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI plan tuần'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.phoOrange, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _summary(({int cal, int budget, int p, int c, int f}) t) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(children: [
        Expanded(child: _summaryCard('Tuần', '${t.cal} cal', '${(t.budget / 1000).round()}k₫')),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Macro', 'P ${t.p}% C ${t.c}%', 'F ${t.f}%')),
      ]),
    );
  }

  Widget _summaryCard(String label, String v1, String v2) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.phoOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          Text(v1, style: AppTypography.headingSm.copyWith(color: AppColors.phoOrange)),
          Text(v2, style: AppTypography.caption),
        ]),
      );

  Widget _headerRow() {
    return Row(children: [
      const SizedBox(width: 80),
      for (final d in _dayLabels) Container(
        width: 120, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(d, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _slotRow(String slot) {
    return Row(children: [
      SizedBox(width: 80, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(_slotLabel(slot), style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
      )),
      for (final d in _days) _slotCell(d, slot),
    ]);
  }

  Widget _slotCell(String day, String slot) {
    final meal = _slotOf(_plan[day]!, slot);
    return Container(
      width: 120,
      margin: const EdgeInsets.all(2),
      height: 100,
      decoration: BoxDecoration(
        color: meal != null ? AppColors.phoOrange.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: meal == null
          ? Center(child: IconButton(icon: const Icon(Icons.add, color: Colors.grey), onPressed: () {}))
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meal.foodName, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('${meal.calories} cal', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
                Text(_typeEmoji(meal.type), style: const TextStyle(fontSize: 12)),
              ]),
            ),
    );
  }

  MealSlot? _slotOf(MealDay d, String slot) => switch (slot) {
        'breakfast' => d.breakfast, 'lunch' => d.lunch, 'dinner' => d.dinner, 'snack' => d.snack, _ => null
      };

  String _slotLabel(String s) => switch (s) {
        'breakfast' => 'Sáng', 'lunch' => 'Trưa', 'dinner' => 'Tối', 'snack' => 'Snack', _ => s
      };
  String _typeEmoji(String t) => switch (t) { 'cook' => '🍳', 'order' => '🛵', 'dine' => '🚶', _ => '🍽' };

  ({int cal, int budget, int p, int c, int f}) _computeTotals() {
    int cal = 0, budget = 0;
    for (final day in _plan.values) {
      for (final m in [day.breakfast, day.lunch, day.dinner, day.snack]) {
        if (m == null) continue;
        cal += m.calories;
        budget += m.priceVnd;
      }
    }
    return (cal: cal, budget: budget, p: 32, c: 48, f: 20);
  }
}
