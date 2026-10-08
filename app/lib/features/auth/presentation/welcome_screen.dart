import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/widgets/app_logo.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Hero(tag: 'app-logo', child: AppLogo(size: 96)),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    child: Text(
                      'Welcome to HisaabChat',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 1,
                    child: Text(
                      'Track every rupee across cash, bank and UPI, as easily as sending a message.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const FadeSlideIn(index: 2, child: _Preview()),
                  const SizedBox(height: 32),
                  FadeSlideIn(
                    index: 3,
                    child: FilledButton(onPressed: () => context.push('/register'), child: const Text('Get started')),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 4,
                    child: TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('I already have an account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three sample "chats" that explain the idea at a glance.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget amount(String text, Color color) => Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey('payments'), color: const Color(0xFF16A34A), solid: true),
              title: 'Cash',
              subtitle: 'Petrol −₹200',
              trailing: amount('₹2,300', colors.textPrimary),
              trailingCaption: '7:45 PM',
            ),
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey('account_balance'), color: const Color(0xFF4F46E5), solid: true),
              title: 'SBI Savings',
              subtitle: 'Salary +₹35,000',
              trailing: amount('₹40,950', colors.textPrimary),
              badge: const CountBadge(2),
            ),
            ChatTile(
              leading: IconAvatar(icon: AppIcons.byKey('shopping_cart'), color: const Color(0xFF10B981)),
              title: 'Food & Groceries',
              subtitle: '₹3,400 of ₹4,000 · ₹50/day left',
              trailing: amount('85%', colors.warning),
            ),
          ],
        ),
      ),
    );
  }
}
