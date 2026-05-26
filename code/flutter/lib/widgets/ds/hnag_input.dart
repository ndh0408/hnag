// HnagInput + HnagSearchBar — mirrors design `Input` + `SearchBar`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'hnag_icon.dart';

enum InputSize { sm, md }

class HnagInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? leading;
  final Widget? trailing;
  final InputSize size;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? errorText;
  final int? maxLength;

  const HnagInput({
    super.key,
    this.controller,
    this.placeholder,
    this.leading,
    this.trailing,
    this.size = InputSize.md,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.errorText,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final spec = size == InputSize.md
        ? (h: 44.0, px: 14.0, text: HnagType.bodyLg)
        : (h: 36.0, px: 12.0, text: HnagType.body);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final border = hasError ? t.danger : t.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: spec.h,
          padding: EdgeInsets.symmetric(horizontal: spec.px),
          decoration: BoxDecoration(
            color: t.bgElev,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(HnagRadius.md),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                HnagIcon(leading!, size: 18, color: t.textMuted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  onTap: onTap,
                  maxLength: maxLength,
                  style: spec.text.copyWith(color: t.text, fontFamily: HnagFonts.body),
                  cursorColor: t.brand,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: placeholder,
                    hintStyle: spec.text.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(errorText!, style: HnagType.bodySm.copyWith(color: t.danger, fontFamily: HnagFonts.body)),
        ],
      ],
    );
  }
}

class HnagSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final bool voice;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  const HnagSearchBar({
    super.key,
    this.controller,
    this.placeholder = 'Tìm món, quán...',
    this.voice = true,
    this.onVoiceTap,
    this.onTap,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagInput(
      controller: controller,
      leading: 'search',
      placeholder: placeholder,
      readOnly: onTap != null,
      onTap: onTap,
      onSubmitted: onSubmitted,
      trailing: voice
          ? Material(
              color: t.brandSoft,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onVoiceTap,
                child: SizedBox(
                  width: 28, height: 28,
                  child: Center(child: HnagIcon('mic', size: 14, color: t.brand)),
                ),
              ),
            )
          : null,
    );
  }
}
