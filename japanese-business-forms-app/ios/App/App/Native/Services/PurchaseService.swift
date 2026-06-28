import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    static let proMonthlyProductID = "monthly"
    static let proYearlyProductID = "yearly"
    private static let proYearlyProductAliasIDs: Set<String> = [proYearlyProductID, "annual"]
    private static let proProductIDs: Set<String> = Set([proMonthlyProductID]).union(proYearlyProductAliasIDs)

    @Published private(set) var proMonthlyProduct: Product?
    @Published private(set) var proYearlyProduct: Product?
    @Published private(set) var hasProAccess = false
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage = ""

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = listenForTransactions()
        Task {
            await refresh()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var displayMonthlyPrice: String? {
        guard let proMonthlyProduct else {
            return nil
        }
        return "\(proMonthlyProduct.displayPrice) \(proMonthlyProduct.priceFormatStyle.currencyCode)"
    }

    var displayYearlyPrice: String? {
        guard let proYearlyProduct else {
            return nil
        }
        return "\(proYearlyProduct.displayPrice) \(proYearlyProduct.priceFormatStyle.currencyCode)"
    }

    var isProMonthlyProductAvailable: Bool {
        proMonthlyProduct != nil
    }

    var isProYearlyProductAvailable: Bool {
        proYearlyProduct != nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        await loadProducts()
        await updateEntitlements()
    }

    func purchasePro(_ option: ProPurchaseOption) async {
        statusMessage = ""
        isLoading = true
        defer { isLoading = false }

        if product(for: option) == nil {
            await loadProducts()
        }

        guard let proProduct = product(for: option) else {
            statusMessage = "productUnavailable"
            return
        }

        do {
            let result = try await proProduct.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateEntitlements()
                await transaction.finish()
                statusMessage = "purchaseComplete"
            case .userCancelled:
                statusMessage = "purchaseCancelled"
            case .pending:
                statusMessage = "purchasePending"
            @unknown default:
                statusMessage = "purchaseUnknown"
            }
        } catch {
            statusMessage = "purchaseFailed"
        }
    }

    func restorePurchases() async {
        statusMessage = ""
        do {
            try await AppStore.sync()
            await updateEntitlements()
            statusMessage = hasProAccess ? "restoreComplete" : "restoreEmpty"
        } catch {
            statusMessage = "restoreFailed"
        }
    }

    func presentOfferCodeRedemption() async {
        statusMessage = "offerCodeSheetPresented"
        SKPaymentQueue.default().presentCodeRedemptionSheet()

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await updateEntitlements()
        if hasProAccess {
            statusMessage = "offerCodeRedeemed"
        }
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: Array(Self.proProductIDs))
            proMonthlyProduct = products.first { $0.id == Self.proMonthlyProductID }
            proYearlyProduct = products.first { $0.id == Self.proYearlyProductID }
                ?? products.first { Self.proYearlyProductAliasIDs.contains($0.id) }
        } catch {
            proMonthlyProduct = nil
            proYearlyProduct = nil
        }
    }

    private func updateEntitlements() async {
        var isPro = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if Self.proProductIDs.contains(transaction.productID) {
                isPro = transaction.revocationDate == nil && !transaction.isUpgraded
            }
        }
        hasProAccess = isPro
    }

    private func product(for option: ProPurchaseOption) -> Product? {
        switch option {
        case .monthly:
            return proMonthlyProduct
        case .yearly:
            return proYearlyProduct
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard let transaction = try? checkVerified(result) else { continue }
                await updateEntitlements()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitError.failedVerification
        }
    }
}

private enum StoreKitError: Error {
    case failedVerification
}

enum ProPurchaseOption {
    case monthly
    case yearly
}
