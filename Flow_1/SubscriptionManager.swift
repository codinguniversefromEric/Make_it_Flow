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
    
    // MARK: - Product IDs
    let bimonthlySubId = "com.flow.subscription.bimonthly"
    let lifetimeId = "com.flow.lifetime"
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    @Published var isPremium: Bool = false
    @Published var isFetchingProducts = false
    
    // MARK: - Freemium Quota
    private let initialFreeConversions = 3
    private let freeConversionsKey = "freeConversionsLeft"
    
    @Published var freeConversionsLeft: Int {
        didSet {
            UserDefaults.standard.set(freeConversionsLeft, forKey: freeConversionsKey)
        }
    }
    
    private var updatesTask: Task<Void, Never>? = nil
    
    private init() {
        // Load free conversions quota
        if UserDefaults.standard.object(forKey: freeConversionsKey) == nil {
            self.freeConversionsLeft = initialFreeConversions
            UserDefaults.standard.set(initialFreeConversions, forKey: freeConversionsKey)
        } else {
            self.freeConversionsLeft = UserDefaults.standard.integer(forKey: freeConversionsKey)
        }
        
        updatesTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - Quota Management
    
    /// Called when a PDF is successfully converted.
    func recordConversion() {
        if !isPremium && freeConversionsLeft > 0 {
            freeConversionsLeft -= 1
        }
    }
    
    /// Check if user can convert (either premium or has quota)
    func canConvert() -> Bool {
        return isPremium || freeConversionsLeft > 0
    }
    
    // MARK: - StoreKit 2 Methods
    
    private func fetchProducts() async {
        isFetchingProducts = true
        defer { isFetchingProducts = false }
        
        do {
            let storeProducts = try await Product.products(for: [bimonthlySubId, lifetimeId])
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
        var purchasedIDs: Set<String> = []
        
        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        self.isPremium = purchasedIDs.contains(bimonthlySubId) || purchasedIDs.contains(lifetimeId)
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
