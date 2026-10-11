import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/context_menu.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/presentation/txn_form.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Deletes [txns] and shows a toast with Undo. Returns true when deleted.
Future<bool> deleteTxns(BuildContext context, WidgetRef ref, List<Txn> txns) async {
  final mutations = ref.read(txnMutationsProvider);
  final toast = AppToast.of(context);
  try {
    for (final txn in txns) {
      await mutations.delete(txn.id);
    }
    // The row that was clicked may be gone by now: use what was read above.
    showDeletedToastWith(toast, mutations, txns);
    return true;
  } on ApiException catch (error) {
    toast.show(error.message, kind: ToastKind.error);
    return false;
  }
}

/// Copies [txns] dated now (newest last). Returns true when done.
Future<bool> duplicateTxns(BuildContext context, WidgetRef ref, List<Txn> txns) async {
  final mutations = ref.read(txnMutationsProvider);
  final toast = AppToast.of(context);
  try {
    for (final txn in txns.reversed) {
      final body = txn.toCreateBody()
        ..remove('id')
        ..['date'] = DateTime.now().toUtc().toIso8601String();
      await mutations.create(body);
    }
    toast.show(txns.length == 1 ? 'Duplicated' : 'Duplicated ${txns.length} transactions', kind: ToastKind.success);
    return true;
  } on ApiException catch (error) {
    toast.show(error.message, kind: ToastKind.error);
    return false;
  }
}

/// Right-click menu for one transaction: Edit, Duplicate, Delete.
/// Balance adjustments can only be deleted (they come from Reconcile).
List<ContextMenuItem> txnMenuItems(BuildContext context, WidgetRef ref, Txn txn) => [
  if (txn.type != TxnType.adjustment) ...[
    ContextMenuItem(
      label: 'Edit',
      icon: AppIcons.edit,
      onSelected: () => unawaited(showTxnForm(context, existing: txn)),
    ),
    ContextMenuItem(
      label: 'Duplicate',
      icon: AppIcons.duplicate,
      onSelected: () => unawaited(duplicateTxns(context, ref, [txn])),
    ),
  ],
  ContextMenuItem(
    label: 'Delete',
    icon: AppIcons.delete,
    destructive: true,
    onSelected: () => unawaited(deleteTxns(context, ref, [txn])),
  ),
];

/// [child] with the transaction right-click menu.
class TxnContextMenu extends ConsumerWidget {
  const TxnContextMenu({required this.txn, required this.child, super.key, this.enabled = true, this.extra = const []});

  final Txn txn;
  final Widget child;

  /// Off for bubbles still sending, and while selecting several.
  final bool enabled;

  /// Shown first (e.g. "Select" in a chat).
  final List<ContextMenuItem> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ContextMenuRegion(
    items: () => enabled ? [...extra, ...txnMenuItems(context, ref, txn)] : const [],
    child: child,
  );
}
