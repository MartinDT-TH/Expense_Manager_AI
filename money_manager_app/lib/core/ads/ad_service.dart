import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_frequency_limiter.dart';
import 'ad_unit_ids.dart';

class AdService {
  AdService({AdFrequencyLimiter? limiter})
      : _limiter = limiter ?? AdFrequencyLimiter();

  final AdFrequencyLimiter _limiter;
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  Future<void> init() async {
    await _limiter.init();
    await preloadInterstitial();
  }

  Future<void> preloadInterstitial() async {
    if (_isLoadingInterstitial || _interstitialAd != null) {
      return;
    }
    _isLoadingInterstitial = true;

    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  BannerAd createBanner({required BannerAdListener listener}) {
    return BannerAd(
      adUnitId: AdUnitIds.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    );
  }

  Future<void> maybeShowInterstitial(
    BuildContext context, {
    required bool isPremium,
  }) async {
    if (isPremium) {
      return;
    }

    if (!_limiter.canShow()) {
      return;
    }

    if (_interstitialAd == null) {
      await preloadInterstitial();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _limiter.recordShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadInterstitial();
      },
    );

    ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
