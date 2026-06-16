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
    @State private var showPolicy = false
    
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
                        Button("Terms of Use") { showPolicy = true }
                        Button("Privacy Policy") { showPolicy = true }
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
        .sheet(isPresented: $showPolicy) {
            PolicyView()
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

// MARK: - App Policy View

struct PolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Group {
                        Text("Privacy Policy")
                            .font(.title2.bold())
                        
                        Text("1. Data Processing\nAll PDF documents are processed entirely on-device using Apple's Vision framework and CoreML. Your documents, extracted text, and generated EPUB files never leave your device unless explicitly shared or exported by you. We do not collect, store, or transmit your files to any external servers.")
                        
                        Text("2. Data Collection\nWe may collect anonymous crash reports and usage metrics to improve the app's performance. This data contains no personally identifiable information or document contents.")
                        
                        Text("3. Changes to This Policy\nWe may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.")
                    }
                    .font(.body)
                    
                    Divider()
                    
                    Group {
                        Text("Terms of Use")
                            .font(.title2.bold())
                        
                        Text("1. Subscription Terms\nFlow offers premium subscriptions that unlock unlimited document conversions. Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period.")
                        
                        Text("2. Acceptable Use\nYou agree not to use the app to process illegal, offensive, or copyrighted materials without authorization. The app is provided 'as is' without warranties of any kind.")
                        
                        Text("3. Limitation of Liability\nIn no event shall the developer be liable for any indirect, incidental, special, or consequential damages arising out of the use or inability to use the app.")
                    }
                    .font(.body)
                }
                .padding()
            }
            .navigationTitle("App Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
