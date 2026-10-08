import SwiftUI

struct KitchenView: View {
    @EnvironmentObject var store: GameStore
    @State private var step = 0
    @State private var recipe = "Rainbow Cupcake"

    private let steps: [(title: String, icon: String, tint: Color)] = [
        ("Add flour", "bag.fill", Color(hex: 0xE8C48F)),
        ("Mix", "arrow.triangle.2.circlepath", Color(hex: 0xA98BFF)),
        ("Bake", "oven.fill", Color(hex: 0xFF9F6E)),
        ("Decorate", "sparkles", Color(hex: 0xFF5C9E))
    ]
    private var finished: Bool { step >= steps.count }
    private var alreadyRewarded: Bool { store.cookedRecipes.contains(recipe) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("Kitchen Mini Game").font(.title2.weight(.black)).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(recipe).font(.subheadline.weight(.bold)).foregroundStyle(Theme.pink)
                }

                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white, Theme.mintSoft], center: .center, startRadius: 10, endRadius: 120))
                        .frame(width: 210, height: 210)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 6))
                        .shadow(color: Theme.mint.opacity(0.25), radius: 14, y: 8)
                    if finished {
                        CupcakeIllustration().frame(width: 130, height: 140)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: steps[step].icon)
                            .font(.system(size: 84, weight: .bold))
                            .foregroundStyle(steps[step].tint.gradient)
                            .gentleBounce(value: step, enabled: !store.playerSettings.reducedMotion)
                    }
                }
                .animation(store.motionAnimationDuration == 0 ? nil : .spring(duration: 0.4), value: step)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(finished ? "\(recipe) is ready" : "Next step: \(steps[step].title)")

                Text(finished ? "\(recipe) is ready!" : steps[step].title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)

                // Step tracker
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        VStack(spacing: 4) {
                            Image(systemName: i < step ? "checkmark" : steps[i].icon)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(i < step ? Color.white : steps[i].tint)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(i < step ? AnyShapeStyle(Theme.mint.gradient) : AnyShapeStyle(Color.white)))
                                .overlay(Circle().strokeBorder(i == step ? steps[i].tint : Color.clear, lineWidth: 2.5))
                            Text(steps[i].title).font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(12)
                .dreamCard(cornerRadius: 20)
                .padding(.horizontal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(min(step, steps.count)) of \(steps.count) complete")

                Button {
                    if finished {
                        step = 0
                        Feedback.play(.tap, settings: store.playerSettings)
                    } else {
                        step += 1
                        if step == steps.count {
                            store.recordRecipe(recipe, rewardCoins: 75, rewardStars: 1)
                            Feedback.play(.success, settings: store.playerSettings)
                        } else {
                            Feedback.play(.tap, settings: store.playerSettings)
                        }
                    }
                } label: {
                    Label(finished ? "Cook Again" : "Do Step", systemImage: finished ? "arrow.counterclockwise" : "hand.tap.fill")
                }
                .buttonStyle(CandyButtonStyle(color: Theme.pink))

                Label(alreadyRewarded ? "First-bake reward collected: 75 coins + 1 star" : "First completion reward: 75 coins + 1 star",
                      systemImage: alreadyRewarded ? "checkmark.seal.fill" : "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }
}

/// Original cupcake drawn with shapes (shown when the recipe is complete).
private struct CupcakeIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Wrapper
                TrapezoidShape(topInset: 0.14)
                    .fill(LinearGradient(colors: [Color(hex: 0x7FD8FF), Color(hex: 0x5DB3FF)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.62, height: h * 0.36)
                    .scaleEffect(x: 1, y: -1)
                    .position(x: w * 0.5, y: h * 0.78)
                // Frosting tiers
                Ellipse().fill(Color(hex: 0xFFB3D1)).frame(width: w * 0.78, height: h * 0.26).position(x: w * 0.5, y: h * 0.56)
                Ellipse().fill(Color(hex: 0xFFC9DE)).frame(width: w * 0.6, height: h * 0.22).position(x: w * 0.5, y: h * 0.42)
                Ellipse().fill(Color(hex: 0xFFDCEA)).frame(width: w * 0.38, height: h * 0.18).position(x: w * 0.5, y: h * 0.3)
                // Sprinkles
                ForEach(0..<9, id: \.self) { i in
                    Capsule()
                        .fill([Theme.sun, Theme.mint, Theme.lavender, Theme.sky][i % 4])
                        .frame(width: 4, height: 10)
                        .rotationEffect(.degrees(Double(i) * 40))
                        .position(x: w * (0.3 + CGFloat(i % 5) * 0.1), y: h * (0.4 + CGFloat(i % 3) * 0.08))
                }
                // Cherry
                Circle().fill(Color(hex: 0xFF4D6D)).frame(width: w * 0.16).position(x: w * 0.5, y: h * 0.17)
                Circle().fill(Color.white.opacity(0.6)).frame(width: w * 0.05).position(x: w * 0.47, y: h * 0.15)
            }
        }
    }
}
