import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// The HisaabChat mark: a white chat bubble holding a ₹ sign on a green
/// rounded square.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'HisaabChat',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(size * 0.28)),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size.square(size * 0.62),
          painter: _BubblePainter(),
          child: SizedBox.square(
            dimension: size * 0.62,
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.08),
              child: Center(
                child: Text(
                  '₹',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = Colors.white;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h * 0.84), Radius.circular(w * 0.3));
    canvas.drawRRect(body, paint);
    final tail = Path()
      ..moveTo(w * 0.2, h * 0.7)
      ..lineTo(w * 0.12, h)
      ..lineTo(w * 0.46, h * 0.8)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
