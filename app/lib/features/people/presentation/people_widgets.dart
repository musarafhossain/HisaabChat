import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/format/dates.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/features/people/data/person.dart';

/// Initials on the person's color, like a WhatsApp contact without a photo.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({required this.name, required this.color, super.key, this.radius = 24});

  PersonAvatar.of(Person person, {Key? key, double radius = 24})
    : this(name: person.initials, color: person.color, key: key, radius: radius);

  /// Already-made initials ("AK").
  final String name;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: radius * 0.7),
      ),
    );
  }
}

/// "Owes you ₹1,500", "You owe ₹300", "Settled up".
String personStatus(Person person) => switch (person.balance) {
  > 0 => 'Owes you ${Money.format(person.balance)}',
  < 0 => 'You owe ${Money.format(-person.balance)}',
  _ => 'Settled up',
};

/// Green when they owe you, red when you owe them.
Color personStatusColor(AppColors colors, Person person) => switch (person.balance) {
  > 0 => colors.income,
  < 0 => colors.expense,
  _ => colors.textSecondary,
};

/// Chat-list row for a person.
class PersonTile extends StatelessWidget {
  const PersonTile({required this.person, super.key, this.selected = false, this.onTap});

  final Person person;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChatTile(
      selected: selected,
      onTap: onTap,
      leading: Hero(tag: 'person-avatar-${person.id}', child: PersonAvatar.of(person)),
      title: person.name,
      subtitle: personStatus(person),
      trailing: person.settled
          ? null
          : Text(
              Money.format(person.balance.abs()),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: personStatusColor(colors, person),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
      trailingCaption: person.lastActivity == null ? null : Dates.listStamp(person.lastActivity!.toLocal()),
    );
  }
}
