import 'package:intl/intl.dart';

/// Money helpers. Amounts are always `int` paise; floating point is only
/// used for display. Mirrors `backend/app/services/money.ts`.
abstract final class Money {
  static final _plain = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');
  static final _whole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _fraction = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Parses user input such as `1,250.5` into paise. Throws [FormatException].
  static int parse(String input) {
    final value = tryParse(input);
    if (value == null) throw FormatException('Invalid amount', input);
    return value;
  }

  /// Like [parse] but returns null for invalid input. Negative input is not
  /// accepted: direction comes from the transaction type.
  static int? tryParse(String input) {
    final match = _plain.firstMatch(input.replaceAll(',', '').trim());
    if (match == null) return null;
    final rupees = int.parse(match.group(1)!);
    final paise = int.parse((match.group(2) ?? '').padRight(2, '0'));
    return rupees * 100 + paise;
  }

  /// Evaluates simple sums typed into the amount field (`120+80-5.5`).
  /// Returns null when the expression is invalid.
  static int? evaluate(String expression) {
    final text = expression.replaceAll(' ', '').replaceAll(',', '');
    if (text.isEmpty) return null;

    final terms = RegExp('([+-]?)([^+-]+)').allMatches(text).toList();
    if (terms.isEmpty || terms.map((m) => m.group(0)).join() != text) return null;

    var total = 0;
    for (final term in terms) {
      final value = tryParse(term.group(2)!);
      if (value == null) return null;
      total += term.group(1) == '-' ? -value : value;
    }
    return total;
  }

  /// `₹1,25,000` or `₹1,250.50` (paise shown only when non-zero).
  /// With [signed], positive values get a `+` and negatives a `−`.
  static String format(int paise, {bool signed = false}) {
    final abs = paise.abs();
    final formatter = abs % 100 == 0 ? _whole : _fraction;
    final text = formatter.format(abs / 100);
    if (paise < 0) return '−$text';
    if (signed && paise > 0) return '+$text';
    return text;
  }

  /// Compact form for charts and tight spaces: `₹950`, `₹12K`, `₹1.2L`, `₹3.5Cr`.
  static String compact(int paise) {
    final sign = paise < 0 ? '−' : '';
    final rupees = paise.abs() / 100;

    String scaled(double value, String suffix) {
      final rounded = value >= 100 ? value.round().toString() : _trimZero(value.toStringAsFixed(1));
      return '$sign₹$rounded$suffix';
    }

    if (rupees >= 1e7) return scaled(rupees / 1e7, 'Cr');
    if (rupees >= 1e5) return scaled(rupees / 1e5, 'L');
    if (rupees >= 1e3) return scaled(rupees / 1e3, 'K');
    return '$sign₹${rupees.round()}';
  }

  static String _trimZero(String value) => value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
}
