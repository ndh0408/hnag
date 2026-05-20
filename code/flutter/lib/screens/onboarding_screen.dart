import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// 8-step onboarding (≤60s) — collects Food DNA.
/// See docs/01-PRODUCT.md §9.
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> dna) onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _idx = 0;

  // Collected state
  String? _name;
  int _age = 25;
  String _diet = 'none';
  final Set<String> _allergies = {};
  double _budget = 80000;
  String _cookFreq = 'weekend';
  final Set<String> _loves = {};
  final Set<String> _hates = {};
  String _goal = 'maintain';

  static const _foodGrid = [
    {'id':'pho-bo','emoji':'🍜','name':'Phở bò'},
    {'id':'bun-cha','emoji':'🥢','name':'Bún chả'},
    {'id':'com-tam','emoji':'🍚','name':'Cơm tấm'},
    {'id':'banh-mi','emoji':'🥖','name':'Bánh mì'},
    {'id':'bun-bo-hue','emoji':'🌶','name':'Bún bò Huế'},
    {'id':'goi-cuon','emoji':'🌯','name':'Gỏi cuốn'},
    {'id':'bbq','emoji':'🥩','name':'BBQ'},
    {'id':'lau','emoji':'🍲','name':'Lẩu'},
    {'id':'sushi','emoji':'🍣','name':'Sushi'},
    {'id':'ramen','emoji':'🍜','name':'Ramen'},
    {'id':'pizza','emoji':'🍕','name':'Pizza'},
    {'id':'burger','emoji':'🍔','name':'Burger'},
    {'id':'salad','emoji':'🥗','name':'Salad'},
    {'id':'tra-sua','emoji':'🧋','name':'Trà sữa'},
    {'id':'che','emoji':'🍮','name':'Chè'},
    {'id':'banh-trang','emoji':'🌮','name':'Bánh tráng'},
  ];

  void _next() {
    if (_idx >= 7) {
      widget.onComplete({
        'name': _name, 'age': _age, 'diet': _diet,
        'allergies': _allergies.toList(),
        'budget': _budget.round(),
        'cookFrequency': _cookFreq,
        'foodsLove': _loves.toList(),
        'foodsHate': _hates.toList(),
        'healthGoal': _goal,
      });
      return;
    }
    setState(() => _idx++);
    _ctrl.animateToPage(_idx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_idx <= 0) return;
    setState(() => _idx--);
    _ctrl.animateToPage(_idx, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: PageView(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcome(),
                  _stepInput('Tên bạn?', (v) => _name = v, 'Hà sẽ gọi bạn bằng tên'),
                  _ageStep(),
                  _dietStep(),
                  _allergyStep(),
                  _budgetStep(),
                  _cookFreqStep(),
                  _foodGridStep(love: true),
                  // S8 reveal
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: [
          if (_idx > 0)
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
          const Spacer(),
          Row(
            children: List.generate(8, (i) {
              final active = i <= _idx;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 24, height: 4,
                decoration: BoxDecoration(
                  color: active ? AppColors.phoOrange : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => widget.onComplete({}),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍜', style: TextStyle(fontSize: 96)),
            const SizedBox(height: AppSpacing.x4),
            Text('Đừng đắn đo nữa,\nHà sẽ chọn cho bạn',
                textAlign: TextAlign.center, style: AppTypography.displayLg),
            const SizedBox(height: AppSpacing.x3),
            Text('AI hiểu khẩu vị, ngân sách, và cả tâm trạng',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLg.copyWith(color: Colors.grey.shade600)),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.05, end: 0),
    );
  }

  Widget _stepInput(String title, ValueChanged<String> onChanged, String? hint) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTypography.displayLg),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint, style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        ],
        const SizedBox(height: AppSpacing.x6),
        TextField(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _ageStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bạn bao nhiêu tuổi?', style: AppTypography.displayLg),
        const SizedBox(height: AppSpacing.x6),
        Center(child: Text('$_age', style: AppTypography.display2xl.copyWith(color: AppColors.phoOrange))),
        Slider(
          min: 13, max: 70, divisions: 57, value: _age.toDouble(),
          activeColor: AppColors.phoOrange,
          onChanged: (v) => setState(() => _age = v.round()),
        ),
      ]),
    );
  }

  Widget _dietStep() {
    final opts = [
      ('none', 'Không kiêng'),
      ('vegetarian', 'Chay'),
      ('vegan', 'Vegan'),
      ('pescatarian', 'Pescatarian'),
      ('halal', 'Halal'),
      ('keto', 'Keto'),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bạn ăn kiêng không?', style: AppTypography.displayLg),
        const SizedBox(height: AppSpacing.x4),
        ...opts.map((o) => RadioListTile<String>(
              title: Text(o.$2),
              value: o.$1,
              groupValue: _diet,
              activeColor: AppColors.phoOrange,
              onChanged: (v) => setState(() => _diet = v ?? 'none'),
            )),
      ]),
    );
  }

  Widget _allergyStep() {
    final all = ['tôm cua', 'đậu phộng', 'sữa', 'gluten', 'trứng', 'cá', 'mè', 'đậu nành'];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bạn dị ứng gì?', style: AppTypography.displayLg),
        Text('Hà sẽ không bao giờ gợi món có những thứ này.',
            style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: AppSpacing.x5),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: all.map((a) {
            final sel = _allergies.contains(a);
            return FilterChip(
              label: Text(a),
              selected: sel,
              selectedColor: AppColors.phoOrange,
              labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
              onSelected: (v) => setState(() => v ? _allergies.add(a) : _allergies.remove(a)),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _budgetStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ngân sách mỗi bữa?', style: AppTypography.displayLg),
        const SizedBox(height: AppSpacing.x6),
        Center(child: Text('${(_budget / 1000).round()}k ₫',
            style: AppTypography.display2xl.copyWith(color: AppColors.phoOrange))),
        Slider(
          min: 20000, max: 500000, divisions: 48, value: _budget,
          activeColor: AppColors.phoOrange,
          onChanged: (v) => setState(() => _budget = v),
        ),
      ]),
    );
  }

  Widget _cookFreqStep() {
    final opts = [
      ('never', 'Không bao giờ', '🥡'),
      ('weekend', 'Cuối tuần', '🍳'),
      ('daily', 'Hàng ngày', '👨‍🍳'),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bạn có nấu ăn không?', style: AppTypography.displayLg),
        const SizedBox(height: AppSpacing.x5),
        ...opts.map((o) {
          final sel = _cookFreq == o.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _cookFreq = o.$1),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: sel ? AppColors.phoOrange : Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  color: sel ? AppColors.phoOrange.withOpacity(0.08) : null,
                ),
                child: Row(children: [
                  Text(o.$3, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Text(o.$2, style: AppTypography.bodyLg),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _foodGridStep({required bool love}) {
    final set = love ? _loves : _hates;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(love ? 'Chọn món bạn YÊU' : 'Món KHÔNG ăn?', style: AppTypography.displayLg),
            const SizedBox(height: 4),
            Text('Đã chọn: ${set.length} / ${love ? "10+" : "5+"}',
                style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.x4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemCount: _foodGrid.length,
            itemBuilder: (_, i) {
              final f = _foodGrid[i];
              final sel = set.contains(f['id']);
              return InkWell(
                onTap: () => setState(() => sel ? set.remove(f['id']) : set.add(f['id']!)),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: sel ? AppColors.phoOrange : Colors.grey.shade300, width: sel ? 2.5 : 1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    color: sel ? AppColors.phoOrange.withOpacity(0.1) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(f['emoji']!, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 2),
                    Text(f['name']!, style: AppTypography.caption, textAlign: TextAlign.center),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x2, AppSpacing.x4, AppSpacing.x4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.phoOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
        ),
        onPressed: _next,
        child: Text(_idx == 7 ? 'Hoàn tất' : 'Tiếp tục',
            style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
