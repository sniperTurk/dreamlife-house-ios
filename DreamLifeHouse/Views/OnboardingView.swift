import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: GameStore
    @State private var page = 0
    private let steps = [
        ("Welcome home", "house.fill", "Create your character and make every room feel like yours."),
        ("Play your way", "sparkles", "Cook, decorate, care for a pet, visit the garden and spend time with friends."),
        ("Safe & comfortable", "heart.fill", "Sound, haptics, reduced motion and purchase confirmation can be changed anytime in Settings.")
    ]
    private let tints = [Theme.pink, Theme.lavender, Theme.mint]

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 22) {
                Spacer(minLength: 10)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white, tints[page].opacity(0.25)], center: .center, startRadius: 10, endRadius: 140))
                        .frame(width: 250, height: 250)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 6))
                        .shadow(color: tints[page].opacity(0.3), radius: 18, y: 10)
                    illustration
                }
                .accessibilityHidden(true)
                Text(steps[page].0)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(steps[page].2)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal)
                Spacer(minLength: 10)
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule().fill(i == page ? tints[page] : Theme.inkSoft.opacity(0.25))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(page + 1) of \(steps.count)")
                Button(page == steps.count - 1 ? "Start playing" : "Continue") {
                    if page == steps.count - 1 { store.completeOnboarding() } else { page += 1 }
                }
                .buttonStyle(CandyButtonStyle(color: tints[page]))
                .accessibilityHint(page == steps.count - 1 ? "Closes welcome guide" : "Shows the next welcome step")
                .padding(.bottom, 24)
            }
            .padding()
        }
        .animation(store.motionAnimationDuration == 0 ? nil : .easeInOut(duration: store.motionAnimationDuration), value: page)
    }

    @ViewBuilder private var illustration: some View {
        switch page {
        case 0:
            AvatarView(look: AvatarLook(), size: 150)
        case 1:
            HStack(spacing: -18) {
                AvatarView(look: FriendLooks.look(for: "luna"), size: 104)
                AvatarView(look: AvatarLook(), size: 120)
                PetPortrait(species: "dog", size: 84).offset(y: 30)
            }
        default:
            Image(systemName: steps[page].1)
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(tints[page].gradient)
                .gentleBounce(value: page, enabled: !store.playerSettings.reducedMotion)
        }
    }
}
