class AdUnitIds {
  const AdUnitIds._();

  static const bool useTestAds = true;

  // Test App ID (Android)
  static const String appIdTest = 'ca-app-pub-3940256099942544~3347511713';

  // Test Ad Unit IDs (Android)
  static const String _bannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest =
      'ca-app-pub-3940256099942544/1033173712';

  // TODO: Replace with real Ad Unit IDs when releasing.
  static const String _bannerProd = _bannerTest;
  static const String _interstitialProd = _interstitialTest;

  static String get bannerId => useTestAds ? _bannerTest : _bannerProd;
  static String get interstitialId =>
      useTestAds ? _interstitialTest : _interstitialProd;
}
