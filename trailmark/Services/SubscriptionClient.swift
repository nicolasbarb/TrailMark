import Foundation
import Dependencies
import RevenueCat

// MARK: - SubscriptionClient

struct SubscriptionClient: Sendable {
    var configure: @Sendable () -> Void
    var isPremium: @Sendable () async -> Bool
    var premiumStatusStream: @Sendable () -> AsyncStream<Bool>
    var fetchOfferings: @Sendable () async throws -> [SubscriptionPackage]
    var purchase: @Sendable (SubscriptionPackage) async throws -> Bool
    var restorePurchases: @Sendable () async throws -> Bool
}

// MARK: - SubscriptionPackage

struct SubscriptionPackage: Equatable, Sendable, Identifiable {
    let id: String
    let type: PackageType
    let localizedPrice: String
    let localizedPricePerMonth: String?

    enum PackageType: String, Equatable, Sendable {
        case monthly
        case annual
    }
}

// MARK: - DependencyKey

extension SubscriptionClient: DependencyKey {
    // TODO: Replace with your RevenueCat API key
    private static let apiKey = "test_QrTpXTemJkitHByxyvcjzRoVAPa"
    private static let premiumEntitlementID = "premium"

    static var liveValue: SubscriptionClient {
        let manager = SubscriptionManager()

        return SubscriptionClient(
            configure: {
                Purchases.logLevel = .debug
                Purchases.configure(withAPIKey: apiKey)
            },
            isPremium: {
                await manager.checkPremiumStatus()
            },
            premiumStatusStream: {
                manager.premiumStatusStream()
            },
            fetchOfferings: {
                try await manager.fetchOfferings()
            },
            purchase: { package in
                try await manager.purchase(package)
            },
            restorePurchases: {
                try await manager.restorePurchases()
            }
        )
    }

    static var testValue: SubscriptionClient {
        SubscriptionClient(
            configure: { },
            isPremium: { false },
            premiumStatusStream: { AsyncStream { $0.yield(false) } },
            fetchOfferings: { [] },
            purchase: { _ in true },
            restorePurchases: { false }
        )
    }

    static var previewValue: SubscriptionClient {
        SubscriptionClient(
            configure: { },
            isPremium: { false },
            premiumStatusStream: { AsyncStream { $0.yield(false) } },
            fetchOfferings: {
                [
                    SubscriptionPackage(
                        id: "monthly",
                        type: .monthly,
                        localizedPrice: "1,99 €",
                        localizedPricePerMonth: "1,99 €"
                    ),
                    SubscriptionPackage(
                        id: "annual",
                        type: .annual,
                        localizedPrice: "9,99 €",
                        localizedPricePerMonth: "0,83 €"
                    )
                ]
            },
            purchase: { _ in true },
            restorePurchases: { false }
        )
    }
}

extension DependencyValues {
    var subscription: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}

// MARK: - SubscriptionManager

private final class SubscriptionManager: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _continuation: AsyncStream<Bool>.Continuation?
    private static let premiumEntitlementID = "premium"

    nonisolated private var continuation: AsyncStream<Bool>.Continuation? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    private var delegateSet = false

    private func ensureDelegateSet() {
        guard !delegateSet else { return }
        delegateSet = true
        Purchases.shared.delegate = self
    }

    func checkPremiumStatus() async -> Bool {
        ensureDelegateSet()
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[Self.premiumEntitlementID]?.isActive == true
        } catch {
            return false
        }
    }

    func premiumStatusStream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.continuation = nil
            }
            // Emit initial value
            Task {
                let isPremium = await self.checkPremiumStatus()
                continuation.yield(isPremium)
            }
        }
    }

    func fetchOfferings() async throws -> [SubscriptionPackage] {
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
            return []
        }

        var packages: [SubscriptionPackage] = []

        if let monthly = current.monthly {
            packages.append(SubscriptionPackage(
                id: monthly.identifier,
                type: .monthly,
                localizedPrice: monthly.localizedPriceString,
                localizedPricePerMonth: monthly.localizedPriceString
            ))
        }

        if let annual = current.annual {
            let monthlyPrice = annual.storeProduct.price as Decimal / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = annual.storeProduct.priceFormatter?.locale ?? .current
            let monthlyString = formatter.string(from: monthlyPrice as NSDecimalNumber)

            packages.append(SubscriptionPackage(
                id: annual.identifier,
                type: .annual,
                localizedPrice: annual.localizedPriceString,
                localizedPricePerMonth: monthlyString
            ))
        }

        return packages
    }

    func purchase(_ subscriptionPackage: SubscriptionPackage) async throws -> Bool {
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
            throw SubscriptionError.noOfferingsAvailable
        }

        let rcPackage: Package?
        switch subscriptionPackage.type {
        case .monthly:
            rcPackage = current.monthly
        case .annual:
            rcPackage = current.annual
        }

        guard let package = rcPackage else {
            throw SubscriptionError.packageNotFound
        }

        let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
        return customerInfo.entitlements[Self.premiumEntitlementID]?.isActive == true
    }

    func restorePurchases() async throws -> Bool {
        let customerInfo = try await Purchases.shared.restorePurchases()
        return customerInfo.entitlements[Self.premiumEntitlementID]?.isActive == true
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let isPremium = customerInfo.entitlements[Self.premiumEntitlementID]?.isActive == true
        continuation?.yield(isPremium)
    }
}

// MARK: - SubscriptionError

enum SubscriptionError: LocalizedError {
    case noOfferingsAvailable
    case packageNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .noOfferingsAvailable:
            return "Aucune offre disponible"
        case .packageNotFound:
            return "Offre introuvable"
        case .purchaseFailed:
            return "Échec de l'achat"
        }
    }
}
