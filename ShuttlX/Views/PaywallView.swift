import SwiftUI
import RevenueCatUI

/// Presents the RevenueCat-hosted paywall configured in the dashboard.
/// The paywall template, copy, and product layout are all server-driven —
/// no client-side product cards or pricing logic needed.
struct ShuttlXPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { _ in
                dismiss()
            }
            .onRestoreCompleted { _ in
                dismiss()
            }
    }
}

/// Customer Center — lets users manage their subscription, request refunds,
/// and contact support. All configured server-side in the RevenueCat dashboard.
struct ShuttlXCustomerCenterView: View {
    var body: some View {
        CustomerCenterView()
    }
}

#Preview("Paywall") {
    ShuttlXPaywallView()
}

#Preview("Customer Center") {
    ShuttlXCustomerCenterView()
}
