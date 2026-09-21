class FeatureFlags {
  /// Temporarily disables aggregate Total Balance / Total Net Worth.
  ///
  /// Set to true only after the balance calculation has been redesigned,
  /// verified, and covered by appropriate tests.
  static const bool enableTotalBalance = false;
}
