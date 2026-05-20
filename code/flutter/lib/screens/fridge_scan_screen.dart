import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class FridgeDetection {
  String name;
  double quantity;
  String unit;
  double confidence;
  bool confirmed;
  FridgeDetection({required this.name, required this.quantity, required this.unit, required this.confidence, this.confirmed = true});
}

class FridgeRecipe {
  final String id;
  final String name;
  final int timeMin;
  final List<String> uses;
  final List<String> missing;
  final String tip;
  const FridgeRecipe({required this.id, required this.name, required this.timeMin, required this.uses, required this.missing, required this.tip});
}

/// AI Fridge Scan — see docs/07-AI-ENGINES.md §5.
class FridgeScanScreen extends StatefulWidget {
  final Future<List<FridgeDetection>> Function(File image) onScan;
  final Future<List<FridgeRecipe>> Function(List<FridgeDetection> items) onSuggestRecipes;
  const FridgeScanScreen({super.key, required this.onScan, required this.onSuggestRecipes});

  @override
  State<FridgeScanScreen> createState() => _FridgeScanScreenState();
}

class _FridgeScanScreenState extends State<FridgeScanScreen> {
  File? _image;
  bool _busy = false;
  List<FridgeDetection>? _detections;
  List<FridgeRecipe>? _recipes;

  Future<void> _pickAndScan(ImageSource src) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: src, maxWidth: 2048, imageQuality: 88);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _busy = true;
      _detections = null;
      _recipes = null;
    });
    try {
      _detections = await widget.onScan(_image!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan lỗi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getRecipes() async {
    if (_detections == null) return;
    final confirmed = _detections!.where((d) => d.confirmed).toList();
    setState(() => _busy = true);
    try {
      _recipes = await widget.onSuggestRecipes(confirmed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét tủ lạnh'), elevation: 0),
      body: _detections == null ? _intro() : (_recipes == null ? _confirmStep() : _recipeStep()),
    );
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🥗', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: AppSpacing.x4),
                  Text('Có gì trong tủ?', textAlign: TextAlign.center, style: AppTypography.headingMd),
                  const SizedBox(height: AppSpacing.x2),
                  Text('Nhập vài nguyên liệu — Hà gợi ý món nấu được từ kho 60+ món Việt.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
          _btn(Icons.add_circle_outline, 'Nhập nguyên liệu', () => setState(() => _detections = [])),
        ],
      ),
    );
  }

  Widget _confirmStep() {
    return Column(children: [
      if (_image != null)
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(children: [
          Text('Tìm thấy ${_detections!.length} nguyên liệu', style: AppTypography.headingSm),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm tay'),
            onPressed: () => _showAddDialog(),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          itemCount: _detections!.length,
          itemBuilder: (_, i) {
            final d = _detections![i];
            return CheckboxListTile(
              activeColor: AppColors.phoOrange,
              value: d.confirmed,
              onChanged: (v) => setState(() => d.confirmed = v ?? true),
              title: Row(children: [
                Text(d.confidence >= 0.8 ? '✅' : '⚠️'),
                const SizedBox(width: 8),
                Text(d.name, style: AppTypography.bodyLg),
                const Spacer(),
                Text('${d.quantity.toStringAsFixed(0)} ${d.unit}',
                    style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
              ]),
              subtitle: d.confidence < 0.8 ? Text('Confidence: ${(d.confidence * 100).round()}%') : null,
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: _btn(Icons.restaurant_menu_rounded, 'Gợi ý món nấu được', _getRecipes),
      ),
    ]);
  }

  Widget _recipeStep() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Row(children: [
          const Text('💡 ', style: TextStyle(fontSize: 22)),
          Text('Hà gợi ý ${_recipes!.length} món', style: AppTypography.headingMd),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          itemCount: _recipes!.length,
          itemBuilder: (_, i) {
            final r = _recipes![i];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.name, style: AppTypography.headingSm)),
                    const Icon(Icons.timer_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('${r.timeMin}p', style: AppTypography.caption),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, children: r.uses.map((u) => Chip(
                    label: Text(u),
                    labelStyle: AppTypography.caption,
                    backgroundColor: AppColors.basil.withOpacity(0.12),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  )).toList()),
                  if (r.missing.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Expanded(child: Text('Cần thêm: ${r.missing.join(", ")}',
                          style: AppTypography.caption.copyWith(color: Colors.grey.shade700))),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Text('💡 ${r.tip}', style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap, {bool primary = true}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? AppColors.phoOrange : Colors.transparent,
        foregroundColor: primary ? Colors.white : AppColors.phoOrange,
        minimumSize: const Size.fromHeight(54),
        side: primary ? null : const BorderSide(color: AppColors.phoOrange, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
      ),
      onPressed: _busy ? null : onTap,
      icon: _busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Icon(icon),
      label: Text(label, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  void _showAddDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm nguyên liệu'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'vd: trứng, cà chua')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () {
            if (c.text.trim().isNotEmpty) {
              setState(() => _detections!.add(FridgeDetection(name: c.text.trim(), quantity: 1, unit: 'cái', confidence: 1.0)));
            }
            Navigator.pop(context);
          }, child: const Text('Thêm')),
        ],
      ),
    );
  }
}
