import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/router.dart';
import 'package:hisaabchat/app/settings/appearance_controller.dart';
import 'package:hisaabchat/app/theme/app_theme.dart';
import 'package:hisaabchat/core/navigation/back_navigation.dart';
import 'package:hisaabchat/core/platform/browser_bar_color.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/budgets/presentation/budget_alert_listener.dart';

class HisaabChatApp extends ConsumerWidget {
  const HisaabChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HisaabChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(appearance.accent),
      darkTheme: AppTheme.dark(appearance.accent),
      themeMode: appearance.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Easing.standard,
      routerConfig: router,
      builder: (context, child) {
        // The in-app "Reduce motion" switch behaves exactly like the OS
        // setting: every motion widget reads MediaQuery.disableAnimations.
        final media = MediaQuery.of(context);
        // Web: the browser's own top bar shows the chosen accent color, in
        // light and dark mode alike (otherwise it would fall back to the
        // manifest's color).
        setBrowserThemeColor(appearance.accent.light);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || appearance.reduceMotion,
          ),
          // Esc and the mouse's back button work like Android's Back.
          child: BackShortcuts(
            onBack: router.routerDelegate.popRoute,
            child: ToastHost(child: BudgetAlertListener(child: child!)),
          ),
        );
      },
    );
  }
}
