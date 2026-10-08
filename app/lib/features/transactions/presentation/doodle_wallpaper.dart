import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';

/// Our own money-themed doodle pattern behind account threads (in the spirit
/// of WhatsApp's chat wallpaper, not a copy of it). Drawn once per size.
class DoodleWallpaper extends StatelessWidget {
  const DoodleWallpaper({required this.child, super.key});

  final Widget child;

  static const _glyphs = [
    'payments',
    'shopping_cart',
    'two_wheeler',
    'local_cafe',
    'savings',
    'receipt',
    'school',
    'credit_card',
    'home',
    'local_gas_station',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.threadBackground,
      child: CustomPaint(
        painter: _DoodlePainter(color: colors.doodle, icons: [for (final key in _glyphs) AppIcons.byKey(key)]),
        child: child,
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({required this.color, required this.icons});

  final Color color;
  final List<IconData> icons;

  static const _cell = 72.0;

  @override
  void paint(Canvas canvas, Size size) {
    final painters = [
      for (final icon in icons)
        TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(fontFamily: icon.fontFamily, fontSize: 22, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    var n = 0;
    for (var y = 8.0; y < size.height; y += _cell) {
      final row = (y / _cell).floor();
      for (var x = (row.isOdd ? _cell / 2 : 0) + 8; x < size.width; x += _cell) {
        final painter = painters[n++ % painters.length];
        canvas
          ..save()
          ..translate(x + 11, y + 11)
          ..rotate((n % 5 - 2) * 0.18)
          ..translate(-11, -11);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.color != color;
}
