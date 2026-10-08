import SwiftUI

struct TopBar: View {
    @EnvironmentObject var store: GameStore
    /// Optional screen title (v2.56 fix: PetView passed a title that TopBar did not accept).
    var title: String = "DreamLife House"

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.candy))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 4)
            currencyPill(icon: "star.fill", tint: Theme.sun, value: store.stars)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(loc("\(store.stars) stars", "\(store.stars) yıldız"))
            currencyPill(icon: "circle.hexagongrid.fill", tint: Theme.peach, value: store.coins)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(loc("\(store.coins) coins", "\(store.coins) jeton"))
                .accessibilityIdentifier("topbar.coins")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func currencyPill(icon: String, tint: Color, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tint.gradient))
            Text(compactNumber(value))
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.92)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1.5))
        .shadow(color: tint.opacity(0.2), radius: 4, y: 2)
    }
}
