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

// MARK: - Banner Ad Placeholder
struct AdBannerView: View {
    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
            Text("AdMob Banner Placeholder")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Interstitial Ad Placeholder
struct InterstitialAdView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Interstitial Ad Placeholder")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("This will be a full-screen ad from Google AdMob.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
                
                Button(action: onDismiss) {
                    Text("Close Ad")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
}

/* 
// ========================================================
// 真實 AdMob 程式碼 (解開註解並替換上方 Placeholder)
// ========================================================

import GoogleMobileAds

struct AdBannerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        
        // 替換為您的 Banner 廣告單元 ID (這裡使用 Google 的測試 ID)
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        bannerView.rootViewController = viewController
        viewController.view.addSubview(bannerView)
        
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        bannerView.load(GADRequest())
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct InterstitialAdView: UIViewControllerRepresentable {
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> InterstitialAdViewController {
        let vc = InterstitialAdViewController()
        vc.onDismiss = onDismiss
        return vc
    }
    
    func updateUIViewController(_ uiViewController: InterstitialAdViewController, context: Context) {}
}

class InterstitialAdViewController: UIViewController, GADFullScreenContentDelegate {
    var interstitial: GADInterstitialAd?
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        loadAd()
    }
    
    func loadAd() {
        // 替換為您的 Interstitial 廣告單元 ID (這裡使用 Google 的測試 ID)
        let adUnitID = "ca-app-pub-3940256099942544/4411468910"
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                // 載入失敗直接視同關閉廣告
                self?.onDismiss?()
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.interstitial?.present(fromRootViewController: self!)
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismiss?()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismiss?()
    }
}
*/
