import SwiftUI
import GoogleMobileAds

struct AdMobNativeView: UIViewRepresentable {
    var nativeAd: NativeAd
    
    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        
        // 🌟 Premium Card Background
        adView.backgroundColor = UIColor.secondarySystemGroupedBackground
        adView.layer.cornerRadius = 16
        adView.layer.shadowColor = UIColor.black.cgColor
        adView.layer.shadowOpacity = 0.08
        adView.layer.shadowOffset = CGSize(width: 0, height: 4)
        adView.layer.shadowRadius = 12
        adView.layer.borderWidth = 1
        adView.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        
        // 1. Icon View (Larger, beautifully rounded)
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 12
        iconView.layer.masksToBounds = true
        iconView.layer.borderWidth = 0.5
        iconView.layer.borderColor = UIColor.separator.cgColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconView)
        adView.iconView = iconView
        
        // 2. Ad Badge (Sleek, subtle design)
        let adBadge = UILabel()
        adBadge.text = "AD"
        adBadge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        adBadge.textColor = UIColor.systemBackground
        adBadge.backgroundColor = UIColor.label.withAlphaComponent(0.8)
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 4
        adBadge.layer.masksToBounds = true
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adBadge)
        
        // 3. Headline View
        let headlineView = UILabel()
        headlineView.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        headlineView.textColor = UIColor.label
        headlineView.numberOfLines = 1
        headlineView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineView)
        adView.headlineView = headlineView
        
        // 4. Body View
        let bodyView = UILabel()
        bodyView.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        bodyView.textColor = UIColor.secondaryLabel
        bodyView.numberOfLines = 2
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyView)
        adView.bodyView = bodyView
        
        // 🌟 NEW: Media View (For main image or video)
        let mediaView = MediaView()
        mediaView.layer.cornerRadius = 8
        mediaView.layer.masksToBounds = true
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView
        
        // 5. Call To Action View (Pill shaped, vibrant color)
        let ctaButton = UIButton(type: .system)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor.systemBlue
        ctaButton.layer.cornerRadius = 22 // Pill shape for 44 height
        ctaButton.layer.shadowColor = UIColor.systemBlue.cgColor
        ctaButton.layer.shadowOpacity = 0.3
        ctaButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        ctaButton.layer.shadowRadius = 8
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton
        
        // Setup Premium Constraints
        NSLayoutConstraint.activate([
            // Icon Constraints
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Headline Constraints
            headlineView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headlineView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
            headlineView.trailingAnchor.constraint(equalTo: adBadge.leadingAnchor, constant: -8),
            
            // Ad Badge Constraints
            adBadge.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            adBadge.centerYAnchor.constraint(equalTo: headlineView.centerYAnchor),
            adBadge.widthAnchor.constraint(equalToConstant: 26),
            adBadge.heightAnchor.constraint(equalToConstant: 16),
            
            // Body Constraints
            bodyView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            bodyView.topAnchor.constraint(equalTo: headlineView.bottomAnchor, constant: 4),
            bodyView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            
            // Media View Constraints
            mediaView.topAnchor.constraint(equalTo: bodyView.bottomAnchor, constant: 12),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            mediaView.heightAnchor.constraint(equalToConstant: 120), // Adjusted height for main image/video
            
            // CTA Button Constraints
            ctaButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            ctaButton.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            ctaButton.heightAnchor.constraint(equalToConstant: 44),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -16)
        ])
        
        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        // Populate the views with the native ad data
        (uiView.headlineView as? UILabel)?.text = nativeAd.headline
        
        // Populate MediaView
        (uiView.mediaView as? MediaView)?.mediaContent = nativeAd.mediaContent
        
        (uiView.bodyView as? UILabel)?.text = nativeAd.body
        (uiView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        
        if let icon = nativeAd.icon?.image {
            (uiView.iconView as? UIImageView)?.image = icon
            uiView.iconView?.isHidden = false
        } else {
            uiView.iconView?.isHidden = true
        }
        
        // Hide body if empty
        uiView.bodyView?.isHidden = (nativeAd.body == nil)
        
        // Link the native ad object to the view to enable interactions (clicks, impressions)
        uiView.nativeAd = nativeAd
    }
}
