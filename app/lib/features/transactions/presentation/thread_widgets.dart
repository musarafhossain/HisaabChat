import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:hisaabchat/features/transactions/transactions_controller.dart';

/// Centered pill: day separators ("TODAY · −₹740") and system messages.
class ThreadChip extends StatelessWidget {
  const ThreadChip({required this.text, super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.dateChip,
          borderRadius: BorderRadius.circular(8),
          boxShadow: light ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: colors.textSecondary), const SizedBox(width: 6)],
            Text(
              text,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One transaction as a chat bubble (docs/04-UI-UX-Design-Brief.md §4.4).
/// Money out is on the right (outgoing), money in on the left.
class TxnBubble extends StatelessWidget {
  const TxnBubble({
    required this.txn,
    required this.accountId,
    super.key,
    this.status,
    this.selected = false,
    this.shakeTrigger = 0,
    this.onTap,
    this.onLongPress,
  });

  final Txn txn;

  /// The thread's account: decides the side and the sign.
  final String accountId;

  /// Null once saved on the server.
  final PendingStatus? status;
  final bool selected;
  final int shakeTrigger;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outgoing = txn.directionFor(accountId) == TxnDirection.outgoing;
    final signed = txn.signedFor(accountId);
    final maxWidth = MediaQuery.sizeOf(context).width * (context.windowClass == WindowClass.compact ? 0.75 : 0.5);

    final (IconData labelIcon, Color labelColor) = switch (txn.type) {
      TxnType.transfer => (AppIcons.transfer, colors.transfer),
      TxnType.adjustment => (AppIcons.adjustment, colors.textSecondary),
      _ => (AppIcons.byKey(txn.category?.icon ?? 'category'), txn.category?.color ?? colors.textSecondary),
    };

    final statusIcon = switch (status) {
      PendingStatus.sending => Icon(AppIcons.sending, size: 14, color: colors.textSecondary),
      PendingStatus.failed => Icon(AppIcons.failed, size: 14, color: colors.danger, fill: 1),
      null => Icon(AppIcons.saved, size: 14, color: colors.tick),
    };

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 120),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: outgoing ? colors.bubbleOut : colors.bubbleIn,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(outgoing ? 10 : 2),
          topRight: Radius.circular(outgoing ? 2 : 10),
          bottomLeft: const Radius.circular(10),
          bottomRight: const Radius.circular(10),
        ),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 1, offset: Offset(0, 1))],
      ),
      // Size to the content (like a chat message), not to the max width.
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(labelIcon, size: 16, color: labelColor, fill: 1),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    txn.labelFor(accountId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              Money.format(signed, signed: true),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: txn.type == TxnType.transfer
                    ? colors.textPrimary
                    : (signed >= 0 ? colors.income : colors.expense),
              ),
            ),
            if (txn.note != null && txn.note!.isNotEmpty && txn.note != txn.labelFor(accountId))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(txn.note!, style: TextStyle(fontSize: 14.5, color: colors.textPrimary)),
              ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (txn.isRecurring) ...[
                    Icon(AppIcons.recurring, size: 13, color: colors.textSecondary),
                    const SizedBox(width: 4),
                  ],
                  Text(Dates.time(txn.localDate), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: context.motion(Motion.short),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: KeyedSubtree(key: ValueKey(status), child: statusIcon),
                  ),
                ],
              ),
            ),
            if (status == PendingStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Not saved · Tap to retry', style: TextStyle(fontSize: 12, color: colors.danger)),
              ),
          ],
        ),
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Semantics(
              button: true,
              label:
                  '${outgoing ? 'Money out' : 'Money in'}, ${Money.format(txn.amount)} rupees, '
                  '${txn.labelFor(accountId)}, ${Dates.time(txn.localDate)}'
                  '${status == null
                      ? ', saved'
                      : status == PendingStatus.sending
                      ? ', sending'
                      : ', not saved'}',
              excludeSemantics: true,
              child: GestureDetector(onTap: onTap, onLongPress: onLongPress, child: bubble),
            ),
          ),
        ],
      ),
    );

    final highlighted = AnimatedContainer(
      duration: context.motion(Motion.instant),
      color: selected ? colors.chipSelected.withValues(alpha: 0.5) : Colors.transparent,
      child: Shake(trigger: shakeTrigger, child: row),
    );

    // New messages rise from the composer.
    return status == PendingStatus.sending ? FadeSlideIn(offset: 24, child: highlighted) : highlighted;
  }
}
