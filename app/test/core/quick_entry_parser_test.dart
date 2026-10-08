import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/transactions/domain/quick_entry_parser.dart';

TxnCategory _cat(String name, [CategoryType type = CategoryType.expense]) => TxnCategory(
  id: name,
  name: name,
  type: type,
  color: Colors.green,
  icon: 'category',
  sortOrder: 0,
);

final List<TxnCategory> _expense = [
  _cat('Room Rent'),
  _cat('Food & Groceries'),
  _cat('Eating Out'),
  _cat('Bike EMI'),
  _cat('Petrol'),
  _cat('Bike Maintenance'),
  _cat('Education'),
  _cat('Mobile & Internet'),
  _cat('Travel'),
];

void main() {
  group('amount', () {
    test('first number becomes the amount', () {
      expect(QuickEntryParser.parse('120 petrol', _expense).amount, 12000);
      expect(QuickEntryParser.parse('petrol 200', _expense).amount, 20000);
      expect(QuickEntryParser.parse('1,250.50 rent', _expense).amount, 125050);
    });

    test('supports ₹, rs and simple sums', () {
      expect(QuickEntryParser.parse('₹99 tea', _expense).amount, 9900);
      expect(QuickEntryParser.parse('99rs tea', _expense).amount, 9900);
      expect(QuickEntryParser.parse('120+80 lunch', _expense).amount, 20000);
    });

    test('no amount yet', () {
      expect(QuickEntryParser.parse('petrol', _expense).amount, isNull);
      expect(QuickEntryParser.parse('', _expense).amount, isNull);
      expect(QuickEntryParser.parse('0 petrol', _expense).amount, isNull);
    });
  });

  group('category', () {
    test('matches category names', () {
      expect(QuickEntryParser.parse('120 petrol', _expense).best?.name, 'Petrol');
      expect(QuickEntryParser.parse('540 groceries', _expense).best?.name, 'Food & Groceries');
      expect(QuickEntryParser.parse('3200 emi', _expense).best?.name, 'Bike EMI');
    });

    test('matches aliases and prefixes', () {
      expect(QuickEntryParser.parse('60 chai', _expense).best?.name, 'Eating Out');
      expect(QuickEntryParser.parse('500 fuel', _expense).best?.name, 'Petrol');
      expect(QuickEntryParser.parse('299 recharge', _expense).best?.name, 'Mobile & Internet');
      expect(QuickEntryParser.parse('40 sabzi', _expense).best?.name, 'Food & Groceries');
      expect(QuickEntryParser.parse('6000 rent', _expense).best?.name, 'Room Rent');
      expect(QuickEntryParser.parse('80 petr', _expense).best?.name, 'Petrol');
      expect(QuickEntryParser.parse('30 metro', _expense).best?.name, 'Travel');
    });

    test('is case-insensitive', () {
      expect(QuickEntryParser.parse('120 PETROL', _expense).best?.name, 'Petrol');
    });

    test('no match gives no suggestions', () {
      expect(QuickEntryParser.parse('120 xyz', _expense).matches, isEmpty);
    });
  });

  group('note', () {
    test('words other than amount and category become the note', () {
      final entry = QuickEntryParser.parse('540 groceries Big Bazaar', _expense);
      expect(entry.best?.name, 'Food & Groceries');
      expect(entry.note, 'Big Bazaar');
    });

    test('unmatched words are all note', () {
      expect(QuickEntryParser.parse('250 birthday cake', _expense).note, 'birthday cake');
    });

    test('category-only line has an empty note', () {
      expect(QuickEntryParser.parse('120 petrol', _expense).note, '');
    });
  });
}
