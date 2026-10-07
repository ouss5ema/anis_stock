import 'package:flutter/widgets.dart';

/// Spacing scale shared by every screen.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page margin.
  static const double page = 16;

  /// Minimum touch target (Material accessibility guideline).
  static const double minTouch = 48;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Typographic sizes used on top of the Material text theme.
abstract final class AppTextSize {
  static const double kpiValue = 22;
  static const double kpiLabel = 13;
  static const double section = 17;
  static const double caption = 12;
  static const double badge = 12;
  static const double greeting = 24;
}
