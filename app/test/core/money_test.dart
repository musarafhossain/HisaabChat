import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/core/money/money.dart';

void main() {
  group('Money.parse', () {
    test('parses rupee strings into paise', () {
      expect(Money.parse('1250.50'), 125050);
      expect(Money.parse('1,250.5'), 125050);
      expect(Money.parse(' 120 '), 12000);
      expect(Money.parse('0.05'), 5);
    });

    test('rejects invalid input', () {
      for (final input in ['', 'abc', '1.234', '-20', '12.', '1e5']) {
        expect(Money.tryParse(input), isNull, reason: input);
      }
      expect(() => Money.parse('abc'), throwsFormatException);
    });
  });

  group('Money.evaluate', () {
    test('adds and subtracts simple expressions', () {
      expect(Money.evaluate('120+80'), 20000);
      expect(Money.evaluate('120 + 80 - 5.5'), 19450);
      expect(Money.evaluate('1,000'), 100000);
    });

    test('returns null for invalid expressions', () {
      expect(Money.evaluate(''), isNull);
      expect(Money.evaluate('120+'), isNull);
      expect(Money.evaluate('12*3'), isNull);
    });
  });

  group('Money.format', () {
    test('uses Indian grouping and hides zero paise', () {
      expect(Money.format(12500000), '₹1,25,000');
      expect(Money.format(125050), '₹1,250.50');
      expect(Money.format(54000), '₹540');
    });

    test('signs', () {
      expect(Money.format(-54000), '−₹540');
      expect(Money.format(3500000, signed: true), '+₹35,000');
      expect(Money.format(0, signed: true), '₹0');
    });
  });

  group('Money.compact', () {
    test('K, L and Cr suffixes', () {
      expect(Money.compact(95000), '₹950');
      expect(Money.compact(1200000), '₹12K');
      expect(Money.compact(120000), '₹1.2K');
      expect(Money.compact(12000000), '₹1.2L');
      expect(Money.compact(3500000000), '₹3.5Cr');
      expect(Money.compact(35000000000), '₹35Cr');
      expect(Money.compact(-1200000), '−₹12K');
    });
  });
}
