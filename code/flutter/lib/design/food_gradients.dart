// Food placeholder gradients — stand-ins for real photography in design and
// dev. In production replace with Cloudinary-served photos. 16 named gradients
// derived from the design canvas.

import 'package:flutter/material.dart';

class FoodGradients {
  FoodGradients._();

  static const Map<String, LinearGradient> all = {
    'pho':      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD4651C), Color(0xFF8B3A0B)]),
    'bunbo':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE63946), Color(0xFF8B1A23)]),
    'comga':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF4B942), Color(0xFFC68820)]),
    'banhmi':   LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE8B86A), Color(0xFFA67841)]),
    'bunch':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8043), Color(0xFFC73C08)]),
    'comtam':   LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD166), Color(0xFFE89020)]),
    'goicuon':  LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8FCB9C), Color(0xFF3DB374)]),
    'banhxeo':  LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFC93D), Color(0xFFD49520)]),
    'lau':      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD02434), Color(0xFF7B1421)]),
    'chao':     LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7F5F1), Color(0xFFC9C3B6)]),
    'mi':       LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE89020), Color(0xFF9F310F)]),
    'che':      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEC4899), Color(0xFFA92160)]),
    'caphe':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6B4226), Color(0xFF2E1810)]),
    'trasua':   LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFDFC4A3), Color(0xFF8B6F4E)]),
    'sushi':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF26271), Color(0xFFC73C08)]),
    'pizza':    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8043), Color(0xFFD02434)]),
  };

  static LinearGradient bySlug(String slug) =>
      all[slug] ?? all['pho']!;

  /// Stable gradient picker from any seed (food name, id, etc.).
  static LinearGradient bySeed(String seed) {
    if (all.containsKey(seed)) return all[seed]!;
    final keys = all.keys.toList();
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return all[keys[hash % keys.length]]!;
  }
}
