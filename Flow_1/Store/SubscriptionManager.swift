//
//  SubscriptionManager.swift
//  Flow_1
//
//  Handles StoreKit 2 subscriptions, purchases, and the freemium quota.
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - 開發者外掛插口
    static func shouldBypassPayment() -> Bool {
        var requirePayment = false
        
        // 💡 只要把下面這行「註解掉」 (在開頭加上 //)，App 就會直接解鎖全部功能，沒有付費牆。
        requirePayment = true
        
        return !requirePayment
    }
    
    // MARK: - Product IDs
    let yearlySubId = "com.flow.subscription.yearly"
    let lifetimeId = "com.flow.lifetime"
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    @Published var isPremium: Bool = SubscriptionManager.shouldBypassPayment()
    @Published var isFetchingProducts = false
    
    // MARK: - Freemium Quota
    private var updatesTask: Task<Void, Never>? = nil
    
    private init() {
        updatesTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - StoreKit 2 Methods
    
    private func fetchProducts() async {
        isFetchingProducts = true
        defer { isFetchingProducts = false }
        
        do {
            let storeProducts = try await Product.products(for: [yearlySubId, lifetimeId])
            // Sort by price so subscription usually comes first
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedStatus()
            
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            print("Restore failed: \(error)")
        }
    }
    
    private func updatePurchasedStatus() async {
        if SubscriptionManager.shouldBypassPayment() {
            self.purchasedProductIDs = [yearlySubId, lifetimeId]
            self.isPremium = true
            return
        }
        
        var purchasedIDs: Set<String> = []
        
        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        self.isPremium = purchasedIDs.contains(yearlySubId) || purchasedIDs.contains(lifetimeId)
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
