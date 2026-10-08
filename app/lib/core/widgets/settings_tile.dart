import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// WhatsApp settings row: grey leading icon, title, optional subtitle.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.danger : null;
    return ListTile(
      leading: Icon(icon, color: color ?? colors.textSecondary),
      title: Text(
        title,
        style: color == null ? null : TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
      hoverColor: colors.inputFill,
    );
  }
}

/// Small grey section label inside settings and lists.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
      ),
    );
  }
}
