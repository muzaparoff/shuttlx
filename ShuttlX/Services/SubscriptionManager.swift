import Foundation
import RevenueCat
import os.log

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Configuration

    /// RevenueCat public API key (safe to ship — read-only).
    static let apiKey = "appl_mHeFHuftdLXvNyxHabCOxrzHBIr"

    /// Entitlement identifier configured in RevenueCat dashboard.
    static let proEntitlementID = "shuttlx Pro"

    // MARK: - Public State

    /// Whether the user has an active Pro entitlement.
    private(set) var isPro: Bool = false

    /// Current customer info from RevenueCat.
    private(set) var customerInfo: CustomerInfo?

    /// True while a purchase or restore is in flight.
    private(set) var isPurchasing: Bool = false

    /// Human-readable error from the last failed operation.
    private(set) var lastError: String?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "Subscriptions")

    // MARK: - Lifecycle

    private init() {}

    /// Call once from ShuttlXApp.init() before any other RevenueCat usage.
    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(
            with: .builder(withAPIKey: Self.apiKey)
                // TODO: switch to .enforced once RevenueCat SDK ships it (marked "future release" in 5.x)
                .with(entitlementVerificationMode: .informational)
                .build()
        )
        logger.info("RevenueCat configured (SDK \(Purchases.frameworkVersion))")
        listenForCustomerInfoUpdates()
    }

    // MARK: - Entitlement Checking

    /// Fetches current customer info and updates `isPro`.
    func refreshEntitlementStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateEntitlementState(info)
        } catch {
            logger.error("Failed to fetch customer info: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchases

    /// Purchases a RevenueCat package (from an offering).
    func purchase(_ package: Package) async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                updateEntitlementState(result.customerInfo)
                logger.info("Purchase succeeded: \(package.identifier)")
                return isPro
            }
            logger.info("User cancelled purchase")
            return false
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
    }

    /// Restores purchases — required by App Store Review Guidelines.
    func restorePurchases() async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            updateEntitlementState(info)
            logger.info("Restore completed — isPro: \(self.isPro)")
            return isPro
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Private

    private func listenForCustomerInfoUpdates() {
        Task { [weak self] in
            for try await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self?.updateEntitlementState(info)
                }
            }
        }
    }

    private func updateEntitlementState(_ info: CustomerInfo) {
        customerInfo = info
        let wasProBefore = isPro
        isPro = info.entitlements[Self.proEntitlementID]?.isActive == true
        if isPro != wasProBefore {
            logger.info("Entitlement changed — isPro: \(self.isPro)")
            SharedDataManager.shared.sendSubscriptionStatusToWatch(isPro)
        }
    }
}
