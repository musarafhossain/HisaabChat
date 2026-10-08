import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';
import 'package:hisaabchat/features/categories/categories_controller.dart';
import 'package:hisaabchat/features/categories/data/category.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/domain/quick_entry_parser.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// WhatsApp-style message bar for an account thread: type "120 petrol", send.
class QuickComposer extends ConsumerStatefulWidget {
  const QuickComposer({required this.account, required this.recentCategoryIds, super.key});

  final Account account;

  /// Categories used most recently in this thread, newest first.
  final List<String> recentCategoryIds;

  @override
  ConsumerState<QuickComposer> createState() => _QuickComposerState();
}

class _QuickComposerState extends ConsumerState<QuickComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _income = false;
  String? _pickedCategoryId;
  int _shake = 0;
  String? _hint;

  CategoryType get _categoryType => _income ? CategoryType.income : CategoryType.expense;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _hint = null));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<TxnCategory> get _categories => (ref.read(categoriesProvider).value ?? const []).activeOf(_categoryType);

  QuickEntry get _entry => QuickEntryParser.parse(_text.text, _categories);

  TxnCategory? _selectedCategory(QuickEntry entry) {
    final all = _categories;
    return all.byId(_pickedCategoryId) ?? entry.best;
  }

  /// Matches for what's typed, else recently used, else the first few.
  List<TxnCategory> _suggestions(QuickEntry entry) {
    final all = _categories;
    if (entry.matches.isNotEmpty) return entry.matches.take(4).toList();
    final recent = [for (final id in widget.recentCategoryIds) ?all.byId(id)];
    return {...recent, ...all}.take(6).toList();
  }

  void _toggleSign() => setState(() {
    _income = !_income;
    _pickedCategoryId = null;
  });

  void _openFullForm() {
    final entry = _entry;
    unawaited(
      showTxnForm(
        context,
        draft: TxnDraft(
          type: _income ? TxnType.income : TxnType.expense,
          amount: entry.amount,
          accountId: widget.account.id,
          categoryId: _selectedCategory(entry)?.id,
          note: entry.note.isEmpty ? null : entry.note,
        ),
      ).then((saved) {
        if (saved ?? false) _clear();
      }),
    );
  }

  void _clear() {
    _text.clear();
    setState(() => _pickedCategoryId = null);
  }

  void _send() {
    final entry = _entry;
    final category = _selectedCategory(entry);
    if (entry.amount == null || category == null) {
      // Inline hint rather than a SnackBar, which would cover the composer.
      setState(() {
        _shake++;
        _hint = entry.amount == null ? 'Start with an amount, e.g. 120 tea' : 'Pick a category above';
      });
      return;
    }

    final id = TxnMutations.newId();
    final now = DateTime.now().toUtc();
    final type = _income ? TxnType.income : TxnType.expense;
    final note = entry.note.isEmpty ? null : entry.note;
    final body = <String, Object?>{
      'id': id,
      'type': type.api,
      'amount': entry.amount,
      'accountId': widget.account.id,
      'categoryId': category.id,
      'date': now.toIso8601String(),
      'note': note,
    };
    final preview = Txn(
      id: id,
      type: type,
      amount: entry.amount!,
      date: now,
      note: note,
      account: AccountRef(
        id: widget.account.id,
        name: widget.account.name,
        icon: widget.account.icon,
        color: widget.account.color,
      ),
      category: CategoryRef(id: category.id, name: category.name, icon: category.icon, color: category.color),
    );

    unawaited(HapticFeedback.lightImpact());
    unawaited(
      ref
          .read(txnMutationsProvider)
          .send(PendingTxn(id: id, body: body, preview: preview, status: PendingStatus.sending)),
    );
    _clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesProvider);
    final colors = context.colors;
    final theme = Theme.of(context);
    final typing = _text.text.trim().isNotEmpty;
    final entry = _entry;
    final selected = _selectedCategory(entry);
    final signColor = _income ? colors.income : colors.expense;

    return ToastAvoid(
      child: Material(
        color: colors.threadBackground,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: context.motion(Motion.medium),
                  curve: Motion.enter,
                  alignment: Alignment.bottomCenter,
                  child: typing
                      ? SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            children: [
                              for (final category in _suggestions(entry))
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      AppIcons.byKey(category.icon),
                                      size: 18,
                                      color: category.color,
                                      fill: 1,
                                    ),
                                    label: Text(category.name),
                                    selected: selected?.id == category.id,
                                    showCheckmark: false,
                                    backgroundColor: colors.panel,
                                    labelStyle: selected?.id == category.id
                                        ? theme.chipTheme.secondaryLabelStyle
                                        : null,
                                    onSelected: (_) => setState(() {
                                      _pickedCategoryId = category.id;
                                      _hint = null;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                AnimatedSize(
                  duration: context.motion(Motion.short),
                  child: _hint == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(56, 0, 8, 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_hint!, style: TextStyle(fontSize: 12.5, color: colors.danger)),
                          ),
                        ),
                ),
                Shake(
                  trigger: _shake,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: _income ? 'Income (tap for expense)' : 'Expense (tap for income)',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _toggleSign,
                          child: AnimatedContainer(
                            duration: context.motion(Motion.medium),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: signColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: MorphIcon(
                              first: AppIcons.toggleExpense,
                              second: AppIcons.toggleIncome,
                              showSecond: _income,
                              color: signColor,
                              turns: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            fillColor: colors.panel,
                            hintText: _income ? 'Income, e.g. 35000 salary' : 'Amount and note, e.g. 120 tea',
                            suffixIcon: typing
                                ? IconButton(
                                    tooltip: 'More details',
                                    icon: const Icon(AppIcons.attach),
                                    onPressed: _openFullForm,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: typing ? 'Send' : 'Full form',
                        child: Material(
                          color: colors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: typing ? _send : _openFullForm,
                            child: SizedBox.square(
                              dimension: 48,
                              child: MorphIcon(
                                first: AppIcons.attach,
                                second: AppIcons.send,
                                showSecond: typing,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
