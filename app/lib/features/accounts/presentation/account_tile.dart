import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/animated_amount.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/features/accounts/data/account.dart';

/// WhatsApp chat-list row for an account. The preview line becomes the last
/// transaction in Phase 3; until then it describes the account.
class AccountTile extends StatelessWidget {
  const AccountTile({required this.account, super.key, this.selected = false, this.onTap});

  final Account account;
  final bool selected;
  final VoidCallback? onTap;

  static String describe(Account account) {
    final parts = <String>[account.type.label];
    if (account.isCreditCard && account.creditLimit != null) {
      parts.add('${Money.compact(account.availableCredit!)} available');
    }
    if (!account.includeInTotal) parts.add('Not in total');
    if (account.archived) parts.add('Archived');
    return parts.join(' · ');
  }

  /// WhatsApp-style last message: "Petrol −₹200", "From Bank +₹2,000".
  static String? _preview(Account account) {
    final last = account.lastTransaction;
    if (last == null) return null;
    final amount = Money.format(last.incoming ? last.amount : -last.amount, signed: true);
    return '${last.label} $amount';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final negative = account.balance < 0;
    return Opacity(
      opacity: account.archived ? 0.6 : 1,
      child: ChatTile(
        selected: selected,
        onTap: onTap,
        leading: Hero(
          tag: 'account-avatar-${account.id}',
          child: IconAvatar(icon: AppIcons.byKey(account.icon), color: account.color, solid: true),
        ),
        title: account.name,
        subtitle: _preview(account) ?? describe(account),
        trailing: AnimatedAmount(
          account.isCreditCard ? account.outstanding : account.balance,
          countUpOnFirstShow: false,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: negative && !account.isCreditCard ? colors.expense : colors.textPrimary,
          ),
        ),
        trailingCaption: account.isCreditCard
            ? 'Outstanding'
            : (account.lastTransaction == null ? null : Dates.listStamp(account.lastTransaction!.date.toLocal())),
      ),
    );
  }
}
