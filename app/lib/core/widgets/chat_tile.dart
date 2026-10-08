import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// Circular icon avatar: category/account color at 15% behind a filled icon.
class IconAvatar extends StatelessWidget {
  const IconAvatar({required this.icon, required this.color, super.key, this.radius = 24, this.solid = false});

  final IconData icon;
  final Color color;
  final double radius;

  /// Solid background with a white icon (accounts) instead of a tint (categories).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: solid ? color : color.withValues(alpha: 0.15),
      child: Icon(icon, fill: 1, size: radius, color: solid ? Colors.white : color),
    );
  }
}

/// WhatsApp chat-list row: avatar | title + preview | trailing value + time.
class ChatTile extends StatelessWidget {
  const ChatTile({
    required this.leading,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.trailingCaption,
    this.badge,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Top-right value, e.g. an amount or balance.
  final Widget? trailing;

  /// Bottom-right caption, e.g. a time.
  final String? trailingCaption;

  /// Bottom-right badge (replaces the caption's line end), e.g. a count.
  final Widget? badge;

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Material(
      color: selected ? colors.chipSelected.withValues(alpha: 0.6) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: colors.inputFill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.listTileTheme.titleTextStyle,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.listTileTheme.subtitleTextStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null || trailingCaption != null || badge != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ?trailing,
                    if (trailingCaption != null || badge != null) const SizedBox(height: 4),
                    if (badge != null)
                      badge!
                    else if (trailingCaption != null)
                      Text(trailingCaption!, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Green rounded count badge (unread-style).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: colors.badge, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
