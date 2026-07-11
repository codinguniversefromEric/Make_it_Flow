import SwiftUI
import GoogleMobileAds
import Combine

/// Manages AdMob Interstitial and Native Ads.
@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published var interstitialAd: InterstitialAd?
    @Published var nativeAd: NativeAd?
    @Published var isNativeAdLoading = false
    
    private let interstitialAdUnitID = Secrets.interstitialAdUnitID
    private let nativeAdUnitID = Secrets.nativeAdUnitID
    
    private var nativeAdLoader: AdLoader?
    
    override private init() {
        super.init()
    }
    
    func preloadAdsIfNeeded() {
        guard !SubscriptionManager.shared.isPremium else { return }
        loadInterstitial()
        loadNativeAd()
    }
    
    // MARK: - Interstitial Ad
    func loadInterstitial() {
        guard interstitialAd == nil else { return }
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                AppLogger.shared.error("Failed to load interstitial ad: \(error.localizedDescription)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            AppLogger.shared.info("Interstitial ad loaded successfully.")
        }
    }
    
    func showInterstitial(from rootViewController: UIViewController) {
        guard !SubscriptionManager.shared.isPremium else { return }
        
        if let ad = interstitialAd {
            ad.present(from: rootViewController)
        } else {
            AppLogger.shared.warning("Interstitial ad wasn't ready.")
            // Try to load one for next time
            loadInterstitial()
        }
    }
    
    // MARK: - Native Ad
    func loadNativeAd() {
        guard nativeAd == nil, !isNativeAdLoading else { return }
        isNativeAdLoading = true
        
        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        
        nativeAdLoader = AdLoader(adUnitID: nativeAdUnitID,
                                     rootViewController: nil,
                                     adTypes: [.native],
                                     options: [multipleAdsOptions])
        nativeAdLoader?.delegate = self
        nativeAdLoader?.load(Request())
    }
}

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Clear the old ad and load a new one for the next time
        self.interstitialAd = nil
        loadInterstitial()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AppLogger.shared.error("Ad failed to present: \(error.localizedDescription)")
        self.interstitialAd = nil
        loadInterstitial()
    }
}

extension AdManager: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        self.isNativeAdLoading = false
        AppLogger.shared.info("Native ad loaded successfully.")
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        AppLogger.shared.error("Native ad failed to load: \(error.localizedDescription)")
        self.isNativeAdLoading = false
    }
}
