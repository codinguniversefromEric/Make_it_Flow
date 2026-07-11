import SwiftUI

// MARK: - AdMob Setup Instructions
/*
  ========================================================
  Google AdMob 整合說明 (Google Mobile Ads SDK)
  ========================================================
  
  1. 在 Xcode 中加入 Google Mobile Ads SDK:
     - 點擊 File > Add Package Dependencies...
     - 貼上網址: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
     - 選擇 "Up to Next Major Version" 並安裝。
 
  2. 修改 Info.plist:
     - 加入 key: `GADApplicationIdentifier` (String)
     - value: `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy` (替換為您在 AdMob 的應用程式 ID)
 
  3. 修改 App 進入點 (App.swift):
     import GoogleMobileAds
     ...
     init() {
         GADMobileAds.sharedInstance().start(completionHandler: nil)
     }
 
  4. 解開下方程式碼的註解並移除目前的佔位區 (Placeholder) 程式碼。
*/



// ========================================================
// 真實 AdMob 程式碼
// ========================================================

import GoogleMobileAds




struct InterstitialAdView: UIViewControllerRepresentable {
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> InterstitialAdViewController {
        let vc = InterstitialAdViewController()
        vc.onDismiss = onDismiss
        return vc
    }
    
    func updateUIViewController(_ uiViewController: InterstitialAdViewController, context: Context) {}
}

class InterstitialAdViewController: UIViewController, FullScreenContentDelegate {
    var interstitial: InterstitialAd?
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        loadAd()
    }
    
    func loadAd() {
        let adUnitID = Secrets.interstitialAdUnitID
        let request = Request()
        
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                self?.onDismiss?()
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            if let self = self {
                self.interstitial?.present(from: self)
            }
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismiss?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismiss?()
    }
}
