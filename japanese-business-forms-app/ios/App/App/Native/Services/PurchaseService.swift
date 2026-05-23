import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    static let proMonthlyProductID = "monthly"
    private static let proProductIDs: Set<String> = [proMonthlyProductID]

    @Published private(set) var proMonthlyProduct: Product?
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

    var displayMonthlyPrice: String {
        proMonthlyProduct?.displayPrice ?? "¥600"
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        await loadProducts()
        await updateEntitlements()
    }

    func purchasePro(_ option: ProPurchaseOption) async {
        statusMessage = ""
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
        } catch {
            proMonthlyProduct = nil
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
}
