import 'package:flutter/material.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/motion.dart';

/// Money text that counts from its previous value to the new one, using
/// tabular figures so the digits never jitter. Counts up from zero on first
/// show when [countUpOnFirstShow] is set.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(
    this.paise, {
    super.key,
    this.style,
    this.signed = false,
    this.compact = false,
    this.countUpOnFirstShow = true,
  });

  final int paise;
  final TextStyle? style;
  final bool signed;
  final bool compact;
  final bool countUpOnFirstShow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final textStyle = base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return Semantics(
      label: _spoken(paise),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: countUpOnFirstShow ? 0 : paise.toDouble(), end: paise.toDouble()),
        duration: context.motion(const Duration(milliseconds: 600)),
        curve: Motion.settle,
        builder: (context, value, _) {
          final current = value.round();
          final text = compact ? Money.compact(current) : Money.format(current, signed: signed);
          return Text(text, style: textStyle);
        },
      ),
    );
  }

  static String _spoken(int paise) {
    final rupees = Money.format(paise.abs()).replaceAll('₹', '');
    return '${paise < 0 ? 'minus ' : ''}$rupees rupees';
  }
}
