//
//  PaywallView.swift
//  Flow_1
//
//  Premium Paywall View
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var isPurchasing = false
    @State private var errorText: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    
                    Text("Unlock Flow Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlimited PDF to EPUB synthesis powered by On-Device AI.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Features
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "doc.text.viewfinder", title: "CoreML Layout Vision", subtitle: "Extract text in reading order perfectly.")
                    FeatureRow(icon: "brain.head.profile", title: "Apple Intelligence", subtitle: "Advanced semantic text reconstruction.")
                    FeatureRow(icon: "infinity", title: "Unlimited Conversions", subtitle: "Convert as many PDFs as you want.")
                    FeatureRow(icon: "lock.shield", title: "100% Privacy", subtitle: "Everything runs locally on your device.")
                }
                .padding(.horizontal, 24)
                
                // Products
                if subscriptionManager.isFetchingProducts {
                    ProgressView()
                        .padding()
                } else if subscriptionManager.products.isEmpty {
                    Text("No products available.")
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 16) {
                        ForEach(subscriptionManager.products, id: \.id) { product in
                            Button {
                                Task { await purchase(product) }
                            } label: {
                                ProductRow(product: product)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isPurchasing)
                            .accessibilityLabel("\(product.displayName), \(product.displayPrice)")
                            .accessibilityHint("Purchase \(product.displayName)")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                if let error = errorText {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Footer
                VStack(spacing: 16) {
                    Button("Restore Purchases") {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Restore Purchases")
                    .accessibilityHint("Restore previously purchased subscriptions")
                    
                    HStack(spacing: 16) {
                        // TODO: Replace with your actual Terms of Use URL before App Store submission
                        Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                        // TODO: Replace with your actual Privacy Policy URL before App Store submission
                        Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.8))
            }
            .padding()
            .accessibilityLabel("Close")
            .accessibilityHint("Dismiss the upgrade screen")
        }
        .onChange(of: subscriptionManager.isPremium) { _, newValue in
            if newValue { dismiss() }
        }
    }
    
    private func purchase(_ product: Product) async {
        isPurchasing = true
        errorText = nil
        do {
            try await subscriptionManager.purchase(product)
        } catch {
            errorText = error.localizedDescription
        }
        isPurchasing = false
    }
}

// MARK: - Subviews

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(product.displayPrice)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
