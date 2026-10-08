import 'package:flutter/material.dart';

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
  });

  static const light = AppColors(
    primary: Color(0xFF1DAA61),
    appBarTitle: Color(0xFF1DAA61),
    navIndicator: Color(0xFFD8FDD2),
    panel: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF0F2F5),
    chipSelected: Color(0xFFD8FDD2),
    onChipSelected: Color(0xFF15603E),
    divider: Color(0xFFE9EDEF),
    textPrimary: Color(0xFF111B21),
    textSecondary: Color(0xFF667781),
    threadBackground: Color(0xFFEFEAE2),
    doodle: Color(0x0F000000),
    bubbleOut: Color(0xFFD9FDD3),
    bubbleIn: Color(0xFFFFFFFF),
    dateChip: Color(0xFFFFFFFF),
    badge: Color(0xFF25D366),
    tick: Color(0xFF53BDEB),
    income: Color(0xFF1DAA61),
    expense: Color(0xFFE53935),
    transfer: Color(0xFF027EB5),
    warning: Color(0xFFE69500),
    danger: Color(0xFFE53935),
    toastBackground: Color(0xFF233138),
    onToast: Color(0xFFF0F2F5),
    toastAction: Color(0xFF25D366),
    toastSuccess: Color(0xFF25D366),
    toastError: Color(0xFFF15C6D),
    toastInfo: Color(0xFF53BDEB),
  );

  static const dark = AppColors(
    primary: Color(0xFF21C063),
    appBarTitle: Color(0xFFE9EDEF),
    navIndicator: Color(0xFF103629),
    panel: Color(0xFF111B21),
    inputFill: Color(0xFF202C33),
    chipSelected: Color(0xFF103629),
    onChipSelected: Color(0xFFD9FDD3),
    divider: Color(0xFF222D34),
    textPrimary: Color(0xFFE9EDEF),
    textSecondary: Color(0xFF8696A0),
    threadBackground: Color(0xFF0B141A),
    doodle: Color(0x0AFFFFFF),
    bubbleOut: Color(0xFF005C4B),
    bubbleIn: Color(0xFF202C33),
    dateChip: Color(0xFF182229),
    badge: Color(0xFF21C063),
    tick: Color(0xFF53BDEB),
    income: Color(0xFF21C063),
    expense: Color(0xFFF15C6D),
    transfer: Color(0xFF53BDEB),
    warning: Color(0xFFFFBC2D),
    danger: Color(0xFFF15C6D),
    toastBackground: Color(0xFFE9EDEF),
    onToast: Color(0xFF111B21),
    toastAction: Color(0xFF008069),
    toastSuccess: Color(0xFF1DAA61),
    toastError: Color(0xFFDC2626),
    toastInfo: Color(0xFF0284C7),
  );

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
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
