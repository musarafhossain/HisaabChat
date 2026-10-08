import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/features/accounts/accounts_controller.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';

/// The green + button: a new transaction, or an account first if there are none.
void openNewTransaction(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final accounts = container.read(accountsProvider).value?.active ?? const [];
  if (accounts.isEmpty) {
    unawaited(
      showAccountForm(context, intro: 'Transactions belong to an account. Add one first, like Cash or your bank.'),
    );
    return;
  }
  unawaited(showTxnForm(context, draft: TxnDraft(accountId: accounts.first.id)));
}
