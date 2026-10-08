import 'package:flutter/foundation.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/features/categories/data/category.dart';

/// Extra words that point to the default categories (lowercase), so
/// "120 fuel" or "60 chai" find the right one.
const Map<String, List<String>> kCategoryAliases = {
  'room rent': ['rent', 'room', 'pg', 'hostel', 'landlord'],
  'food & groceries': [
    'grocery',
    'groceries',
    'ration',
    'vegetables',
    'veggies',
    'sabzi',
    'fruits',
    'milk',
    'doodh',
    'bread',
    'eggs',
    'kirana',
    'bigbasket',
    'blinkit',
    'zepto',
    'dmart',
  ],
  'eating out': [
    'restaurant',
    'lunch',
    'dinner',
    'breakfast',
    'tea',
    'chai',
    'coffee',
    'snacks',
    'zomato',
    'swiggy',
    'canteen',
    'mess',
    'biryani',
    'pizza',
    'burger',
    'dhaba',
  ],
  'bike emi': ['emi', 'loan', 'installment'],
  'petrol': ['fuel', 'diesel', 'cng', 'pump'],
  'bike maintenance': ['service', 'servicing', 'repair', 'mechanic', 'tyre', 'tire', 'oil', 'puncture'],
  'education': ['fees', 'fee', 'tuition', 'books', 'book', 'course', 'exam', 'college', 'school', 'coaching'],
  'utilities': ['electricity', 'bijli', 'water', 'gas', 'cylinder', 'bill'],
  'mobile & internet': ['recharge', 'wifi', 'broadband', 'internet', 'mobile', 'jio', 'airtel', 'data'],
  'shopping': ['clothes', 'shoes', 'amazon', 'flipkart', 'myntra', 'meesho', 'mall'],
  'health': ['medicine', 'medicines', 'doctor', 'pharmacy', 'hospital', 'clinic', 'chemist', 'tablets'],
  'entertainment': ['movie', 'movies', 'netflix', 'hotstar', 'prime', 'spotify', 'cinema', 'game'],
  'travel': ['bus', 'train', 'metro', 'auto', 'cab', 'uber', 'ola', 'rapido', 'flight', 'ticket', 'toll'],
  'personal care': ['salon', 'haircut', 'parlour', 'parlor', 'barber', 'cosmetics'],
  'gifts': ['gift', 'birthday', 'wedding', 'shagun'],
  'salary': ['pay', 'paycheck', 'stipend', 'wages'],
  'freelance': ['client', 'project', 'gig', 'upwork', 'fiverr'],
  'pocket money / family': ['pocket', 'papa', 'mummy', 'mom', 'dad', 'family', 'home'],
  'interest': ['fd', 'savings', 'dividend'],
  'refund': ['cashback', 'return', 'reversal'],
};

/// Result of parsing a composer line such as "120 petrol" or "540 groceries big bazaar".
@immutable
class QuickEntry {
  const QuickEntry({required this.amount, required this.note, required this.matches});

  /// Paise, or null when the text has no valid amount yet.
  final int? amount;

  /// Words that weren't the amount or the matched category.
  final String note;

  /// Matching categories, best first (may be empty).
  final List<TxnCategory> matches;

  TxnCategory? get best => matches.isEmpty ? null : matches.first;
}

/// Turns free text into amount + category + note (docs/04-UI-UX-Design-Brief.md §4.4).
///
/// * The first token that is a valid amount (`120`, `1,250.50`, `120+80`,
///   `₹99`, `99rs`) becomes the amount.
/// * Remaining words are matched against category names and [kCategoryAliases]:
///   whole words score highest, then prefixes of 3+ letters.
/// * Words that didn't match the best category become the note.
abstract final class QuickEntryParser {
  static final _tokenSplit = RegExp(r'\s+');
  static final _wordSplit = RegExp('[^a-z0-9]+');

  static QuickEntry parse(String input, List<TxnCategory> categories) {
    final tokens = input.trim().split(_tokenSplit).where((t) => t.isNotEmpty).toList();

    int? amount;
    var amountIndex = -1;
    for (final (i, token) in tokens.indexed) {
      final value = _amountOf(token);
      if (value != null && value > 0) {
        amount = value;
        amountIndex = i;
        break;
      }
    }

    final words = [
      for (final (i, token) in tokens.indexed)
        if (i != amountIndex) token,
    ];

    final scored = <(TxnCategory, int, Set<int>)>[];
    for (final category in categories) {
      final (score, used) = _score(category, words);
      if (score > 0) scored.add((category, score, used));
    }
    // Higher score first; ties keep the categories' own order.
    final ordered = scored.indexed.toList()
      ..sort((a, b) {
        final byScore = b.$2.$2.compareTo(a.$2.$2);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });

    final used = ordered.isEmpty ? const <int>{} : ordered.first.$2.$3;
    final note = [
      for (final (i, word) in words.indexed)
        if (!used.contains(i)) word,
    ].join(' ');

    return QuickEntry(amount: amount, note: note, matches: [for (final entry in ordered) entry.$2.$1]);
  }

  static int? _amountOf(String token) {
    var text = token.toLowerCase().replaceAll('₹', '');
    for (final suffix in ['rupees', 'rs.', 'rs', '/-']) {
      if (text.endsWith(suffix)) text = text.substring(0, text.length - suffix.length);
    }
    if (text.startsWith('rs.')) text = text.substring(3);
    if (text.isEmpty || !RegExp('[0-9]').hasMatch(text)) return null;
    return Money.evaluate(text);
  }

  /// Best score of any word against the category name and its aliases,
  /// plus the indexes of the words that reached that score. Weaker partial
  /// matches stay in the note ("big" in "groceries big bazaar" is not
  /// swallowed just because it prefixes the alias "bigbasket").
  static (int, Set<int>) _score(TxnCategory category, List<String> words) {
    final name = category.name.toLowerCase();
    final vocabulary = {
      ...name.split(_wordSplit).where((w) => w.length >= 2),
      ...?kCategoryAliases[name],
    };

    final wordScores = <int, int>{};
    for (final (i, raw) in words.indexed) {
      for (final word in raw.toLowerCase().split(_wordSplit).where((w) => w.length >= 2)) {
        var score = 0;
        if (vocabulary.contains(word)) {
          score = 3;
        } else if (word.length >= 3 && vocabulary.any((v) => v.startsWith(word) || word.startsWith(v))) {
          score = 2;
        }
        if (score > (wordScores[i] ?? 0)) wordScores[i] = score;
      }
    }
    if (wordScores.isEmpty) return (0, const <int>{});

    final best = wordScores.values.reduce((a, b) => a > b ? a : b);
    return (
      best,
      {
        for (final MapEntry(:key, :value) in wordScores.entries)
          if (value == best) key,
      },
    );
  }
}
