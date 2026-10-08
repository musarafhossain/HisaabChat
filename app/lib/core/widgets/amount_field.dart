import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hisaabchat/core/money/money.dart';

/// Rupee amount input. Accepts `1,250.50` and simple sums like `120+80`;
/// the value is read with [AmountField.paiseOf] (paise, never negative).
class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    required this.hint,
    super.key,
    this.allowZero = true,
    this.required = true,
    this.errorText,
    this.helperText,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String hint;
  final bool allowZero;
  final bool required;
  final String? errorText;
  final String? helperText;
  final bool autofocus;
  final TextInputAction textInputAction;

  /// Parsed paise, or null when empty/invalid.
  static int? paiseOf(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return Money.evaluate(text);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,+\- ]'))],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 20, right: 8),
          child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        prefixIconConstraints: const BoxConstraints(),
        errorText: errorText,
        helperText: helperText,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return required ? 'Enter an amount' : null;
        final paise = Money.evaluate(text);
        if (paise == null) return 'Enter a valid amount, like 1250.50';
        if (paise < 0) return 'The amount can’t be negative';
        if (!allowZero && paise == 0) return 'The amount must be more than zero';
        return null;
      },
    );
  }
}
