import SwiftUI
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

// MARK: - Palette

/// Original DreamLife House palette: soft pastels with a deep plum ink colour
/// for text so every label keeps a readable contrast on light backgrounds.
enum Theme {
    static let pink = Color(hex: 0xFF5C9E)
    static let pinkSoft = Color(hex: 0xFFE3EF)
    static let lavender = Color(hex: 0xA98BFF)
    static let lavenderSoft = Color(hex: 0xEFE8FF)
    static let mint = Color(hex: 0x3CC7A8)
    static let mintSoft = Color(hex: 0xDDF7EF)
    static let peach = Color(hex: 0xFF9F6E)
    static let peachSoft = Color(hex: 0xFFE9DC)
    static let sun = Color(hex: 0xFFC23D)
    static let sunSoft = Color(hex: 0xFFF3CF)
    static let sky = Color(hex: 0x5DB3FF)
    static let skySoft = Color(hex: 0xDFF0FF)
    static let ink = Color(hex: 0x3D2B52)
    static let inkSoft = Color(hex: 0x76678A)
    static let cream = Color(hex: 0xFFF9F4)

    static let candy = LinearGradient(colors: [Color(hex: 0xFF7EB3), Color(hex: 0xFF5C9E)],
                                      startPoint: .top, endPoint: .bottom)

    static func roomTint(_ roomID: String) -> Color {
        switch roomID {
        case "bedroom": return lavender
        case "kitchen": return mint
        case "bathroom": return sky
        case "garden": return Color(hex: 0x5BBF5B)
        default: return pink
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Backgrounds and cards

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xFFF1F7), Color(hex: 0xF3EEFF), Color(hex: 0xEAF6FF)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle().fill(Theme.pink.opacity(0.10))
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.95, y: geo.size.height * 0.08)
                Circle().fill(Theme.lavender.opacity(0.10))
                    .frame(width: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.02, y: geo.size.height * 0.55)
                Circle().fill(Theme.sky.opacity(0.08))
                    .frame(width: geo.size.width * 0.6)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.95)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct DreamCard: ViewModifier {
    var cornerRadius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: Theme.lavender.opacity(0.18), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 1.5)
            )
    }
}

extension View {
    func dreamCard(cornerRadius: CGFloat = 22) -> some View { modifier(DreamCard(cornerRadius: cornerRadius)) }

    /// Plays a symbol bounce only when the player has not asked for reduced motion.
    func gentleBounce<V: Equatable>(value: V, enabled: Bool) -> some View {
        modifier(GentleBounce(value: value, enabled: enabled))
    }
}

private struct GentleBounce<V: Equatable>: ViewModifier {
    let value: V
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        if enabled && !systemReduceMotion {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}

// MARK: - Buttons

/// Big, glossy capsule used for the main action on a screen.
struct CandyButtonStyle: ButtonStyle {
    var color: Color = Theme.pink
    func makeBody(configuration: Configuration) -> some View {
        CandyButtonBody(configuration: configuration, color: color)
    }
    private struct CandyButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.82), color],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            Capsule().fill(Color.white.opacity(0.30))
                                .frame(height: 7)
                                .padding(.horizontal, 14)
                                .padding(.top, 4)
                        }
                        .shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 5)
                )
                .saturation(isEnabled ? 1 : 0)
                .opacity(isEnabled ? 1 : 0.55)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

/// Small pill used for claim / wear / invite actions inside cards.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.pink
    func makeBody(configuration: Configuration) -> some View {
        PillButtonBody(configuration: configuration, color: color)
    }
    private struct PillButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isEnabled ? Color.white : Theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(isEnabled ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color.gray.opacity(0.16))))
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

/// Soft tinted tile used for selectable options (rooms, outfits, hair…).
struct TileButtonStyle: ButtonStyle {
    var selected: Bool
    var tint: Color = Theme.pink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? tint.opacity(0.18) : Color.white.opacity(0.9))
                    .shadow(color: Theme.lavender.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? tint : Color.white, lineWidth: selected ? 2.5 : 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Shared small components

struct IconBadge: View {
    let icon: String
    var tint: Color = Theme.pink
    var size: CGFloat = 42
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.gradient))
            .shadow(color: tint.opacity(0.3), radius: 4, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

struct SectionTitle: View {
    let title: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).foregroundStyle(Theme.pink) }
            Text(title).font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A colourful meter used for character and pet needs.
struct NeedMeter: View {
    let name: String
    let icon: String
    let value: Int
    let tint: Color
    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2.weight(.bold)).foregroundStyle(tint)
                Text(name).font(.caption2.weight(.heavy)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.16))
                    Capsule().fill(tint.gradient)
                        .frame(width: max(8, geo.size.width * CGFloat(min(100, max(0, value))) / 100))
                }
            }
            .frame(height: 9)
            Text("\(value)%").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc("\(name) \(value) percent", "\(name) yüzde \(value)"))
    }
}

/// Card used for every daily / weekly goal so long lists stay tidy.
struct QuestCard<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    let trailing: Trailing

    init(icon: String, tint: Color = Theme.lavender, title: String, detail: String,
         @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon; self.tint = tint; self.title = title; self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            trailing.buttonStyle(PillButtonStyle(color: tint))
        }
        .padding(12)
        .dreamCard(cornerRadius: 20)
    }
}

/// Short-form number for the HUD (accessibility labels keep the exact value).
func compactNumber(_ value: Int) -> String {
    switch value {
    case 1_000_000_000...: return String(format: "%.1fB", Double(value) / 1_000_000_000)
    case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
    case 10_000...: return String(format: "%.1fK", Double(value) / 1_000)
    default: return "\(value)"
    }
}

// MARK: - Sound & haptics

/// Lightweight feedback that honours the player's Sound and Haptics settings.
/// Uses only system-provided sounds and generators (no bundled audio).
@MainActor enum Feedback {
    enum Kind { case tap, success, purchase, warning }

    static func play(_ kind: Kind, settings: PlayerSettings) {
        #if canImport(UIKit)
        if settings.hapticsEnabled {
            switch kind {
            case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .success, .purchase: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        if settings.soundEnabled {
            // System "Tock" / "Tink" style UI sounds; they respect the ring/silent switch.
            switch kind {
            case .tap: AudioServicesPlaySystemSound(1104)
            case .success, .purchase: AudioServicesPlaySystemSound(1057)
            case .warning: AudioServicesPlaySystemSound(1053)
            }
        }
        #endif
    }
}
