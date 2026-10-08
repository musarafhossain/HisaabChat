import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';

/// Home. The real dashboard (balance, budget rings, upcoming, recent) is
/// built in Phase 5; until then it greets the user and shows the roadmap.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final colors = context.colors;
    final theme = Theme.of(context);

    const roadmap = [
      (AppIcons.accounts, 'Accounts', 'Cash, bank and UPI, each one a chat', 'Phase 2'),
      (AppIcons.send, 'Quick add', 'Type “120 petrol” and send', 'Phase 3'),
      (AppIcons.budgets, 'Budgets', 'Rings for Rent, Food, Bike EMI + Petrol…', 'Phase 4'),
      (AppIcons.home, 'Dashboard & reports', 'Your month at a glance', 'Phase 5'),
      (AppIcons.people, 'Lend & borrow', 'Who owes whom, per person', 'Phase 6'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${greeting(DateTime.now())}, ${user?.firstName ?? ''}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(AppIcons.ok, color: colors.primary, fill: 1, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your HisaabChat is ready', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Signed in as ${user?.email ?? ''}. Your 22 default categories are set up.',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const FadeSlideIn(index: 2, child: SectionLabel('Coming next')),
            for (final (i, (icon, title, subtitle, phase)) in roadmap.indexed)
              FadeSlideIn(
                index: 3 + i,
                child: ChatTile(
                  leading: IconAvatar(icon: icon, color: colors.primary),
                  title: title,
                  subtitle: subtitle,
                  trailingCaption: phase,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
