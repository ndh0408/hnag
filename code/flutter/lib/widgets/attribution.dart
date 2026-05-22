import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme/app_theme.dart';

/// Required legal attribution for our data sources.
/// - Restaurant/map data comes from OpenStreetMap, licensed under the
///   Open Database License (ODbL).
/// - Food images come from Wikimedia Commons (CC licenses).
/// Tapping opens the respective license pages.
class DataAttribution extends StatelessWidget {
  /// Smaller variant with reduced padding, for tight footers.
  final bool dense;
  const DataAttribution({super.key, this.dense = false});

  static const _osmUrl = 'https://www.openstreetmap.org/copyright';
  static const _wikimediaUrl = 'https://commons.wikimedia.org/wiki/Commons:Licensing';

  Future<void> _open(String url) async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption.copyWith(color: Colors.grey.shade600, fontSize: 11);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 6 : 10),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Dữ liệu quán © '),
          TextSpan(
            text: 'OpenStreetMap (ODbL)',
            style: const TextStyle(decoration: TextDecoration.underline),
            recognizer: _tap(_osmUrl),
          ),
          const TextSpan(text: ' · Ảnh món từ '),
          TextSpan(
            text: 'Wikimedia Commons',
            style: const TextStyle(decoration: TextDecoration.underline),
            recognizer: _tap(_wikimediaUrl),
          ),
        ]),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }

  GestureRecognizer _tap(String url) => (TapGestureRecognizer()..onTap = () => _open(url));
}
