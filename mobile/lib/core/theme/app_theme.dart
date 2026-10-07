import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';

class AppTheme {
  /// Brand primary (logo blue). Kept as `seed` for existing callers.
  static const seed = BrandPalette.primary;

  static ThemeData light() => _build(Brightness.light);

  /// Ready for a future dark mode; not wired in `MaterialApp` yet.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final appColors = isLight ? AppColors.light : AppColors.dark;
    final generated = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final colorScheme = isLight
        ? generated.copyWith(
            primary: BrandPalette.primary,
            onPrimary: const Color(0xFFFFFFFF),
            primaryContainer: const Color(0xFFD7E9FA),
            onPrimaryContainer: BrandPalette.deepBlue,
            secondaryContainer: const Color(0xFFD7E9FA),
            onSecondaryContainer: BrandPalette.deepBlue,
            surface: const Color(0xFFFFFFFF),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF3F6FA),
            surfaceContainer: const Color(0xFFEDF2F7),
            onSurfaceVariant: const Color(0xFF475467),
            outlineVariant: appColors.cardBorder,
            error: appColors.danger,
          )
        : generated;

    final baseText = GoogleFonts.manropeTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );
    final textTheme = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final scaffold = isLight ? colorScheme.surfaceContainerLow : colorScheme.surface;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [appColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: appColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: AppTextSize.caption,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        side: BorderSide(color: appColors.cardBorder),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colorScheme.primary,
          selectedForegroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AppSpacing.minTouch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: const OutlineInputBorder(borderRadius: AppRadius.mdAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colorScheme.primary),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    );
  }
}
