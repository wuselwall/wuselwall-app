/// The three ways the same app presents itself (docs/09): a dense adult UI, a large and
/// friendly kid UI, and the read-from-across-the-room wall display.
enum UiRegister {
  adult,
  kid,
  kiosk;

  /// Base body text size in logical pixels (docs/09 design system).
  double get baseFontSize => switch (this) {
    adult => 15,
    kid => 19,
    kiosk => 28,
  };

  /// Minimum touch target edge in logical pixels (NFR-13).
  double get touchTarget => switch (this) {
    adult => 44,
    kid => 56,
    kiosk => 56,
  };

  /// Smallest text allowed anywhere in this register (NFR-16 for the kiosk).
  double get minFontSize => switch (this) {
    adult => 12,
    kid => 16,
    kiosk => 24,
  };

  /// Corner radius of controls and cards (docs/17, "Shape, depth and motion").
  double get radius => switch (this) {
    adult => 10,
    kid => 18,
    kiosk => 14,
  };

  /// Name of the home route for this register.
  String get homeRoute => switch (this) {
    adult => '/adult',
    kid => '/kid',
    kiosk => '/kiosk',
  };
}
