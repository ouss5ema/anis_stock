import 'package:flutter/material.dart';

/// Brand palette sampled from `assets/branding/app_logo.jpg`
/// (average of the matching pixels).
abstract final class BrandPalette {
  /// Primary: dominant deep blue of the logo background.
  /// Contrast 7.0:1 on white (AA, AAA for large text).
  static const primary = Color(0xFF035B9D);

  /// Darker shade of the primary for the header gradient start
  /// (white text 9.9:1).
  static const deepBlue = Color(0xFF024578);

  /// Lighter blue of the logo gradient (3.7:1 on white): decorative only.
  static const lightBlue = Color(0xFF098FC2);

  /// Bright cyan of the word "stock" (1.3:1 on white).
  /// Decorative only, never text on a light background.
  static const cyan = Color(0xFF23F6FA);
}

/// Semantic and brand colors not covered by [ColorScheme].
/// Read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brandDeep,
    required this.accent,
    required this.sale,
    required this.saleContainer,
    required this.purchase,
    required this.purchaseContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.neutral,
    required this.neutralContainer,
    required this.success,
    required this.successContainer,
    required this.onHeader,
    required this.onHeaderMuted,
    required this.cardBorder,
    required this.skeleton,
  });

  final Color brandDeep;
  final Color accent;
  final Color sale;
  final Color saleContainer;
  final Color purchase;
  final Color purchaseContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color neutral;
  final Color neutralContainer;
  final Color success;
  final Color successContainer;

  /// Text and icons on the brand gradient header.
  final Color onHeader;
  final Color onHeaderMuted;
  final Color cardBorder;
  final Color skeleton;

  /// Header gradient: deep blue to primary, cyan kept for a subtle glow.
  LinearGradient headerGradient(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandDeep, scheme.primary],
      );

  static const light = AppColors(
    brandDeep: BrandPalette.deepBlue,
    accent: BrandPalette.cyan,
    sale: Color(0xFF15803D),
    saleContainer: Color(0xFFDCFCE7),
    purchase: Color(0xFF7C3AED),
    purchaseContainer: Color(0xFFEDE9FE),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    danger: Color(0xFFB91C1C),
    dangerContainer: Color(0xFFFEE2E2),
    neutral: Color(0xFF475569),
    neutralContainer: Color(0xFFE2E8F0),
    success: Color(0xFF15803D),
    successContainer: Color(0xFFDCFCE7),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xFFD6E8F8),
    cardBorder: Color(0xFFDCE3EA),
    skeleton: Color(0xFFE3E9EF),
  );

  /// Prepared for a future dark theme (not enabled yet).
  static const dark = AppColors(
    brandDeep: Color(0xFF062E59),
    accent: BrandPalette.cyan,
    sale: Color(0xFF4ADE80),
    saleContainer: Color(0xFF14532D),
    purchase: Color(0xFFC4B5FD),
    purchaseContainer: Color(0xFF4C1D95),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF78350F),
    danger: Color(0xFFF87171),
    dangerContainer: Color(0xFF7F1D1D),
    neutral: Color(0xFFCBD5E1),
    neutralContainer: Color(0xFF334155),
    success: Color(0xFF4ADE80),
    successContainer: Color(0xFF14532D),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xFFBFD7EE),
    cardBorder: Color(0xFF2B3A4A),
    skeleton: Color(0xFF2B3A4A),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? brandDeep,
    Color? accent,
    Color? sale,
    Color? saleContainer,
    Color? purchase,
    Color? purchaseContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? neutral,
    Color? neutralContainer,
    Color? success,
    Color? successContainer,
    Color? onHeader,
    Color? onHeaderMuted,
    Color? cardBorder,
    Color? skeleton,
  }) {
    return AppColors(
      brandDeep: brandDeep ?? this.brandDeep,
      accent: accent ?? this.accent,
      sale: sale ?? this.sale,
      saleContainer: saleContainer ?? this.saleContainer,
      purchase: purchase ?? this.purchase,
      purchaseContainer: purchaseContainer ?? this.purchaseContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      neutral: neutral ?? this.neutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onHeader: onHeader ?? this.onHeader,
      onHeaderMuted: onHeaderMuted ?? this.onHeaderMuted,
      cardBorder: cardBorder ?? this.cardBorder,
      skeleton: skeleton ?? this.skeleton,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brandDeep: mix(brandDeep, other.brandDeep),
      accent: mix(accent, other.accent),
      sale: mix(sale, other.sale),
      saleContainer: mix(saleContainer, other.saleContainer),
      purchase: mix(purchase, other.purchase),
      purchaseContainer: mix(purchaseContainer, other.purchaseContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      neutral: mix(neutral, other.neutral),
      neutralContainer: mix(neutralContainer, other.neutralContainer),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onHeader: mix(onHeader, other.onHeader),
      onHeaderMuted: mix(onHeaderMuted, other.onHeaderMuted),
      cardBorder: mix(cardBorder, other.cardBorder),
      skeleton: mix(skeleton, other.skeleton),
    );
  }
}
