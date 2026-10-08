import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';

/// Material 3 themes tuned to the WhatsApp-inspired design brief.
/// Fonts are the platform defaults (Roboto on Android/Web, Segoe UI on Windows).
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light, background: Colors.white);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark, background: const Color(0xFF0B141A));

  static ThemeData _build(Brightness brightness, AppColors c, {required Color background}) {
    final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness).copyWith(
      primary: c.primary,
      onPrimary: brightness == Brightness.light ? Colors.white : const Color(0xFF0B141A),
      secondaryContainer: c.navIndicator,
      onSecondaryContainer: c.textPrimary,
      surface: background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: background,
      surfaceContainerLow: c.panel,
      surfaceContainer: c.panel,
      surfaceContainerHigh: c.inputFill,
      surfaceContainerHighest: c.inputFill,
      outline: c.textSecondary,
      outlineVariant: c.divider,
      error: c.danger,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
    const tabular = [FontFeature.tabularFigures()];

    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      textTheme: base.textTheme
          .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary)
          .copyWith(
            displaySmall: base.textTheme.displaySmall?.copyWith(fontFeatures: tabular),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.appBarTitle),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.navIndicator,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: c.textPrimary,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.textPrimary)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.panel,
        indicatorColor: c.navIndicator,
        selectedIconTheme: IconThemeData(color: c.textPrimary),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.primary)),
      chipTheme: ChipThemeData(
        backgroundColor: c.inputFill,
        selectedColor: c.chipSelected,
        checkmarkColor: c.onChipSelected,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: c.onChipSelected, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        hintStyle: TextStyle(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, color: c.textPrimary),
        subtitleTextStyle: TextStyle(fontSize: 14, color: c.textSecondary),
        iconColor: c.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: c.inputFill,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: TextStyle(color: background),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
