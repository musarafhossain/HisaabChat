import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/accent.dart';

/// WhatsApp-inspired color tokens (docs/04-UI-UX-Design-Brief.md §2.1) that
/// don't fit Material's ColorScheme: bubbles, thread wallpaper, finance colors.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.appBarTitle,
    required this.navIndicator,
    required this.panel,
    required this.inputFill,
    required this.chipSelected,
    required this.onChipSelected,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.threadBackground,
    required this.doodle,
    required this.bubbleOut,
    required this.bubbleIn,
    required this.dateChip,
    required this.badge,
    required this.tick,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warning,
    required this.danger,
    required this.toastBackground,
    required this.onToast,
    required this.toastAction,
    required this.toastSuccess,
    required this.toastError,
    required this.toastInfo,
    required this.toastWarning,
  });

  /// Light palette in the given accent.
  factory AppColors.lightFor(AccentColor accent) {
    const white = Color(0xFFFFFFFF);
    final a = accent.light;
    final tint = Color.lerp(white, a, 0.16)!;
    return AppColors(
      primary: a,
      appBarTitle: a,
      navIndicator: tint,
      panel: white,
      inputFill: const Color(0xFFF0F2F5),
      chipSelected: tint,
      onChipSelected: Color.lerp(a, const Color(0xFF000000), 0.45)!,
      divider: const Color(0xFFE9EDEF),
      textPrimary: const Color(0xFF111B21),
      textSecondary: const Color(0xFF667781),
      threadBackground: const Color(0xFFEFEAE2),
      doodle: const Color(0x0F000000),
      bubbleOut: Color.lerp(white, a, 0.18)!,
      bubbleIn: white,
      dateChip: white,
      badge: a,
      tick: const Color(0xFF53BDEB),
      income: const Color(0xFF1DAA61),
      expense: const Color(0xFFE53935),
      transfer: const Color(0xFF027EB5),
      warning: const Color(0xFFE69500),
      danger: const Color(0xFFE53935),
      toastBackground: const Color(0xFF233138),
      onToast: const Color(0xFFF0F2F5),
      // The toast is dark in light mode, so its action uses the bright shade.
      toastAction: accent.dark,
      toastSuccess: const Color(0xFF25D366),
      toastError: const Color(0xFFF15C6D),
      toastInfo: const Color(0xFF53BDEB),
      toastWarning: const Color(0xFFFFBC2D),
    );
  }

  /// Dark palette in the given accent.
  factory AppColors.darkFor(AccentColor accent) {
    const panel = Color(0xFF111B21);
    const background = Color(0xFF0B141A);
    final a = accent.dark;
    final tint = Color.lerp(panel, a, 0.24)!;
    return AppColors(
      primary: a,
      appBarTitle: const Color(0xFFE9EDEF),
      navIndicator: tint,
      panel: panel,
      inputFill: const Color(0xFF202C33),
      chipSelected: tint,
      onChipSelected: Color.lerp(a, const Color(0xFFFFFFFF), 0.7)!,
      divider: const Color(0xFF222D34),
      textPrimary: const Color(0xFFE9EDEF),
      textSecondary: const Color(0xFF8696A0),
      threadBackground: background,
      doodle: const Color(0x0AFFFFFF),
      // A deep version of the accent, like WhatsApp's dark green bubble.
      bubbleOut: Color.lerp(background, accent.light, 0.62)!,
      bubbleIn: const Color(0xFF202C33),
      dateChip: const Color(0xFF182229),
      badge: a,
      tick: const Color(0xFF53BDEB),
      income: const Color(0xFF21C063),
      expense: const Color(0xFFF15C6D),
      transfer: const Color(0xFF53BDEB),
      warning: const Color(0xFFFFBC2D),
      danger: const Color(0xFFF15C6D),
      toastBackground: const Color(0xFFE9EDEF),
      onToast: const Color(0xFF111B21),
      toastAction: accent.light,
      toastSuccess: const Color(0xFF1DAA61),
      toastError: const Color(0xFFDC2626),
      toastInfo: const Color(0xFF0284C7),
      toastWarning: const Color(0xFFD97706),
    );
  }

  final Color primary;
  final Color appBarTitle;
  final Color navIndicator;
  final Color panel;
  final Color inputFill;
  final Color chipSelected;
  final Color onChipSelected;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color threadBackground;
  final Color doodle;
  final Color bubbleOut;
  final Color bubbleIn;
  final Color dateChip;
  final Color badge;
  final Color tick;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;
  final Color danger;

  // Toasts (inverse surface: dark in light mode, light in dark mode)
  final Color toastBackground;
  final Color onToast;
  final Color toastAction;
  final Color toastSuccess;
  final Color toastError;
  final Color toastInfo;
  final Color toastWarning;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: mix(primary, other.primary),
      appBarTitle: mix(appBarTitle, other.appBarTitle),
      navIndicator: mix(navIndicator, other.navIndicator),
      panel: mix(panel, other.panel),
      inputFill: mix(inputFill, other.inputFill),
      chipSelected: mix(chipSelected, other.chipSelected),
      onChipSelected: mix(onChipSelected, other.onChipSelected),
      divider: mix(divider, other.divider),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      threadBackground: mix(threadBackground, other.threadBackground),
      doodle: mix(doodle, other.doodle),
      bubbleOut: mix(bubbleOut, other.bubbleOut),
      bubbleIn: mix(bubbleIn, other.bubbleIn),
      dateChip: mix(dateChip, other.dateChip),
      badge: mix(badge, other.badge),
      tick: mix(tick, other.tick),
      income: mix(income, other.income),
      expense: mix(expense, other.expense),
      transfer: mix(transfer, other.transfer),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      toastBackground: mix(toastBackground, other.toastBackground),
      onToast: mix(onToast, other.onToast),
      toastAction: mix(toastAction, other.toastAction),
      toastSuccess: mix(toastSuccess, other.toastSuccess),
      toastError: mix(toastError, other.toastError),
      toastInfo: mix(toastInfo, other.toastInfo),
      toastWarning: mix(toastWarning, other.toastWarning),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
