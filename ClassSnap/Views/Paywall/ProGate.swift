import SwiftUI

/// A Toggle row that requires Pro. Shows a crown icon for free users and redirects
/// to PaywallView when the row is tapped.
struct ProFeatureToggle: View {
    let label: String
    @Binding var isOn: Bool
    @Binding var showPaywall: Bool

    private var isPro: Bool { EntitlementManager.shared.isPro }

    var body: some View {
        HStack {
            Toggle(label, isOn: $isOn)
                .tint(Color.appGreen)
                .disabled(!isPro)
            if !isPro {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.appGreen)
                    .font(.caption)
                    .onTapGesture { showPaywall = true }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPro { showPaywall = true }
        }
    }
}

// MARK: - Crown badge overlay

private struct CrownBadgeModifier: ViewModifier {
    let isPro: Bool

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            if !isPro {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.appGreen)
                    .offset(x: 6, y: -4)
            }
        }
    }
}

extension View {
    /// Overlays a small crown badge in the top-trailing corner for non-Pro users.
    func crownBadge(isPro: Bool) -> some View {
        modifier(CrownBadgeModifier(isPro: isPro))
    }
}
