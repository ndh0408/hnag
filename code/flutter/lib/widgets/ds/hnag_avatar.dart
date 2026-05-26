// HnagAvatar + HnagAvatarStack — mirrors design `Avatar` + `AvatarStack`.
// Stable HSL gradient bg from name hash, image fallback, ring + status badge.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class HnagAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;
  final bool ring;
  final Color? ringColor;
  final HnagStatus? status;

  const HnagAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
    this.ring = false,
    this.ringColor,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final initial = (name.isEmpty ? '?' : name[0]).toUpperCase();
    final hue = name.codeUnits.fold<int>(0, (a, b) => a + b) % 360;
    final hue2 = (hue + 40) % 360;
    final gradient = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.65).toColor(),
               HSLColor.fromAHSL(1, hue2.toDouble(), 0.70, 0.55).toColor()],
    );

    Widget child;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        errorWidget: (_, __, ___) => _initialContent(initial, size),
      );
    } else {
      child = _initialContent(initial, size);
    }

    final avatar = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: imageUrl == null || imageUrl!.isEmpty ? gradient : null,
        border: ring ? Border.all(color: ringColor ?? t.brand, width: 2) : null,
        boxShadow: ring ? [BoxShadow(color: t.bg, spreadRadius: 1)] : null,
      ),
      child: ClipOval(child: child),
    );

    if (status == null) return avatar;
    final dotSize = size * 0.32;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2, bottom: -2,
          child: Container(
            width: dotSize, height: dotSize,
            decoration: BoxDecoration(
              color: _statusColor(status!),
              shape: BoxShape.circle,
              border: Border.all(color: t.bg, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialContent(String initial, double s) => Center(
    child: Text(
      initial,
      style: TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700,
        fontSize: s * 0.4, fontFamily: HnagFonts.display,
      ),
    ),
  );

  static Color _statusColor(HnagStatus s) => switch (s) {
    HnagStatus.online  => HnagColors.basil400,
    HnagStatus.away    => HnagColors.turmeric500,
    HnagStatus.busy    => HnagColors.chili500,
    HnagStatus.offline => HnagColors.neutral500,
  };
}

enum HnagStatus { online, away, busy, offline }

class HnagAvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;
  final double overlap;

  const HnagAvatarStack({
    super.key,
    required this.names,
    this.size = 28,
    this.max = 4,
    this.overlap = 8,
  });

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final remaining = names.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : -overlap),
            child: HnagAvatar(name: shown[i], size: size, ring: true, ringColor: Colors.white),
          ),
        if (remaining > 0)
          Container(
            margin: EdgeInsets.only(left: -overlap),
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: context.hnag.text, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$remaining',
              style: HnagType.labelSm.copyWith(color: context.hnag.text, fontFamily: HnagFonts.body),
            ),
          ),
      ],
    );
  }
}
