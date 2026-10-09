import SwiftUI

/// Everything needed to draw a character. Built from the saved profile so the
/// avatar finally reflects the player's hair, skin tone, outfit and accessory.
struct AvatarLook: Equatable {
    var skinToneID = "warm"
    var hairStyleID = "waves"
    var hairColorID = "chestnut"
    var outfitID = "sunny"
    var accessoryID = "none"

    init(skinToneID: String = "warm", hairStyleID: String = "waves", hairColorID: String = "chestnut",
         outfitID: String = "sunny", accessoryID: String = "none") {
        self.skinToneID = skinToneID; self.hairStyleID = hairStyleID; self.hairColorID = hairColorID
        self.outfitID = outfitID; self.accessoryID = accessoryID
    }

    init(profile: CharacterProfile, outfitID: String) {
        self.init(skinToneID: profile.skinToneID, hairStyleID: profile.hairStyleID,
                  hairColorID: profile.hairColorID, outfitID: outfitID, accessoryID: profile.accessoryID)
    }

    var skin: Color {
        switch skinToneID {
        case "light": return Color(hex: 0xFBDCC7)
        case "deep": return Color(hex: 0x8F5B3E)
        default: return Color(hex: 0xE5AE86)
        }
    }
    var skinShade: Color {
        switch skinToneID {
        case "light": return Color(hex: 0xF0BFA4)
        case "deep": return Color(hex: 0x744630)
        default: return Color(hex: 0xCF9469)
        }
    }
    var hair: Color {
        switch hairColorID {
        case "midnight": return Color(hex: 0x2E2A4A)
        case "honey": return Color(hex: 0xE3A949)
        case "berry": return Color(hex: 0xB23A78)
        default: return Color(hex: 0x7A4528)
        }
    }
    var outfit: Color {
        switch outfitID {
        case "party": return Color(hex: 0xA77BFF)
        case "sport": return Color(hex: 0x2EC4B6)
        case "pajamas": return Color(hex: 0x9DB8F0)
        case "creative": return Color(hex: 0xFF6F8E)
        default: return Color(hex: 0xFFBE3B)
        }
    }
    var outfitTrim: Color {
        switch outfitID {
        case "party": return Color(hex: 0xFFD6F5)
        case "sport": return .white
        case "pajamas": return Color(hex: 0xFFF3B0)
        case "creative": return Color(hex: 0xFFE38A)
        default: return Color(hex: 0xFFF4D6)
        }
    }
    var outfitEmblem: String {
        switch outfitID {
        case "party": return "sparkles"
        case "sport": return "bolt.fill"
        case "pajamas": return "moon.stars.fill"
        case "creative": return "paintpalette.fill"
        default: return "sun.max.fill"
        }
    }
    var wearsSkirt: Bool { outfitID == "sunny" || outfitID == "party" }
}

/// An original, fully vector character drawn with SwiftUI shapes. The view is
/// laid out on a 100 × 125 unit grid and scales cleanly to any size.
struct AvatarView: View {
    let look: AvatarLook
    var size: CGFloat = 120

    private var u: CGFloat { size / 100 }

    var body: some View {
        ZStack {
            // Soft ground shadow
            Ellipse().fill(Color.black.opacity(0.10))
                .frame(width: 62 * u, height: 10 * u)
                .offset(y: 60 * u)
            backHair
            legs
            arms
            torso
            // Neck
            RoundedRectangle(cornerRadius: 4 * u).fill(look.skinShade)
                .frame(width: 14 * u, height: 12 * u)
                .offset(y: 8 * u)
            head
            face
            bangs
            accessory
        }
        .frame(width: size, height: size * 1.25)
        .accessibilityHidden(true)
    }

    // MARK: Hair

    @ViewBuilder private var backHair: some View {
        switch look.hairStyleID {
        case "bob":
            RoundedRectangle(cornerRadius: 24 * u, style: .continuous).fill(look.hair)
                .frame(width: 70 * u, height: 58 * u)
                .offset(y: -22 * u)
        case "curls":
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) / 10 * 2 * Double.pi
                    Circle().fill(look.hair)
                        .frame(width: 24 * u, height: 24 * u)
                        .offset(x: CGFloat(cos(angle)) * 30 * u, y: CGFloat(sin(angle)) * 30 * u - 24 * u)
                }
                Circle().fill(look.hair).frame(width: 64 * u, height: 64 * u).offset(y: -24 * u)
            }
        case "ponytail":
            ZStack {
                Ellipse().fill(look.hair)
                    .frame(width: 24 * u, height: 50 * u)
                    .rotationEffect(.degrees(-24))
                    .offset(x: 36 * u, y: -18 * u)
                Circle().fill(look.outfit).frame(width: 10 * u, height: 10 * u)
                    .offset(x: 28 * u, y: -38 * u)
                RoundedRectangle(cornerRadius: 24 * u, style: .continuous).fill(look.hair)
                    .frame(width: 64 * u, height: 50 * u)
                    .offset(y: -28 * u)
            }
        default: // waves – long hair falling past the shoulders
            ZStack {
                RoundedRectangle(cornerRadius: 28 * u, style: .continuous).fill(look.hair)
                    .frame(width: 72 * u, height: 82 * u)
                    .offset(y: -12 * u)
                Circle().fill(look.hair).frame(width: 22 * u).offset(x: -30 * u, y: 22 * u)
                Circle().fill(look.hair).frame(width: 22 * u).offset(x: 30 * u, y: 22 * u)
            }
        }
    }

    private var bangs: some View {
        BangsShape().fill(look.hair)
            .overlay(BangsShape().stroke(Color.white.opacity(0.18), lineWidth: 1.2 * u).padding(3 * u))
            .frame(width: 64 * u, height: 38 * u)
            .offset(y: -41 * u)
    }

    // MARK: Body

    private var legs: some View {
        HStack(spacing: 8 * u) {
            Capsule().fill(look.skinShade).frame(width: 10 * u, height: 16 * u)
            Capsule().fill(look.skinShade).frame(width: 10 * u, height: 16 * u)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 6 * u) {
                Capsule().fill(Theme.ink).frame(width: 14 * u, height: 7 * u)
                Capsule().fill(Theme.ink).frame(width: 14 * u, height: 7 * u)
            }
            .offset(y: 2 * u)
        }
        .offset(y: 52 * u)
    }

    private var arms: some View {
        ZStack {
            Capsule().fill(look.skin)
                .frame(width: 11 * u, height: 36 * u)
                .rotationEffect(.degrees(16))
                .offset(x: -27 * u, y: 30 * u)
            Capsule().fill(look.skin)
                .frame(width: 11 * u, height: 36 * u)
                .rotationEffect(.degrees(-16))
                .offset(x: 27 * u, y: 30 * u)
        }
    }

    @ViewBuilder private var torso: some View {
        ZStack {
            if look.wearsSkirt {
                TrapezoidShape(topInset: 0.2)
                    .fill(LinearGradient(colors: [look.outfit.opacity(0.85), look.outfit], startPoint: .top, endPoint: .bottom))
                    .frame(width: 58 * u, height: 46 * u)
                TrapezoidShape(topInset: 0.2)
                    .stroke(look.outfitTrim, style: StrokeStyle(lineWidth: 2 * u, dash: [3 * u, 3 * u]))
                    .frame(width: 50 * u, height: 40 * u)
            } else {
                RoundedRectangle(cornerRadius: 14 * u, style: .continuous)
                    .fill(LinearGradient(colors: [look.outfit.opacity(0.85), look.outfit], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46 * u, height: 46 * u)
                if look.outfitID == "sport" {
                    Rectangle().fill(look.outfitTrim).frame(width: 46 * u, height: 5 * u).offset(y: 6 * u)
                } else {
                    // Overall straps for the Creative look
                    HStack(spacing: 18 * u) {
                        Capsule().fill(look.outfitTrim).frame(width: 5 * u, height: 22 * u)
                        Capsule().fill(look.outfitTrim).frame(width: 5 * u, height: 22 * u)
                    }
                    .offset(y: -10 * u)
                }
            }
            Image(systemName: look.outfitEmblem)
                .font(.system(size: 13 * u, weight: .bold))
                .foregroundStyle(look.outfitTrim)
                .offset(y: look.outfitID == "sport" ? -8 * u : 4 * u)
        }
        .offset(y: 34 * u)
    }

    // MARK: Head & face

    private var head: some View {
        ZStack {
            // Ears
            Circle().fill(look.skinShade).frame(width: 12 * u).offset(x: -28 * u, y: -18 * u)
            Circle().fill(look.skinShade).frame(width: 12 * u).offset(x: 28 * u, y: -18 * u)
            Circle().fill(look.skin).frame(width: 56 * u, height: 56 * u).offset(y: -20 * u)
        }
    }

    private var face: some View {
        ZStack {
            // Eyes with highlights
            ForEach([-10.0, 10.0], id: \.self) { x in
                Ellipse().fill(Theme.ink)
                    .frame(width: 7 * u, height: 9 * u)
                    .overlay(Circle().fill(.white).frame(width: 2.6 * u).offset(x: 1.2 * u, y: -1.8 * u))
                    .offset(x: CGFloat(x) * u, y: -16 * u)
            }
            // Cheeks
            ForEach([-17.0, 17.0], id: \.self) { x in
                Circle().fill(Color(hex: 0xFF7A9C).opacity(0.38))
                    .frame(width: 9 * u, height: 9 * u)
                    .offset(x: CGFloat(x) * u, y: -7 * u)
            }
            SmileShape()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.2 * u, lineCap: .round))
                .frame(width: 12 * u, height: 5 * u)
                .offset(y: -5 * u)
        }
    }

    // MARK: Accessories

    @ViewBuilder private var accessory: some View {
        switch look.accessoryID {
        case "glasses":
            HStack(spacing: 3 * u) {
                Circle().stroke(Theme.ink, lineWidth: 2 * u).frame(width: 15 * u, height: 15 * u)
                Circle().stroke(Theme.ink, lineWidth: 2 * u).frame(width: 15 * u, height: 15 * u)
            }
            .overlay(Rectangle().fill(Theme.ink).frame(width: 4 * u, height: 2 * u))
            .offset(y: -16 * u)
        case "star":
            Image(systemName: "star.fill")
                .font(.system(size: 15 * u, weight: .bold))
                .foregroundStyle(Theme.sun)
                .shadow(color: .white, radius: 1)
                .offset(x: 22 * u, y: -46 * u)
        case "flower":
            FlowerShape()
                .fill(Color(hex: 0xFF8FB8))
                .overlay(Circle().fill(Theme.sun).frame(width: 6 * u))
                .frame(width: 17 * u, height: 17 * u)
                .offset(x: 23 * u, y: -45 * u)
        case "starlightCrown":
            Image(systemName: "crown.fill")
                .font(.system(size: 22 * u, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF4A900)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.sun.opacity(0.6), radius: 4 * u)
                .offset(y: -62 * u)
        case "cometVeil":
            ZStack {
                Image(systemName: "sparkles").font(.system(size: 16 * u, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7FD8FF)).offset(x: 30 * u, y: -50 * u)
                Image(systemName: "sparkle").font(.system(size: 11 * u, weight: .bold))
                    .foregroundStyle(Color(hex: 0xC9A8FF)).offset(x: -32 * u, y: -36 * u)
                Image(systemName: "sparkle").font(.system(size: 9 * u, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7FD8FF)).offset(x: -24 * u, y: 10 * u)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Shapes

struct BangsShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX, y: r.minY + h * 0.92))
        p.addCurve(to: CGPoint(x: r.minX + w, y: r.minY + h * 0.92),
                   control1: CGPoint(x: r.minX - w * 0.02, y: r.minY - h * 0.28),
                   control2: CGPoint(x: r.minX + w * 1.02, y: r.minY - h * 0.28))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.68, y: r.minY + h * 0.62),
                       control: CGPoint(x: r.minX + w * 0.86, y: r.minY + h * 0.98))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.34, y: r.minY + h * 0.66),
                       control: CGPoint(x: r.minX + w * 0.52, y: r.minY + h * 0.92))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.92),
                       control: CGPoint(x: r.minX + w * 0.14, y: r.minY + h * 1.02))
        p.closeSubpath()
        return p
    }
}

struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        return p
    }
}

struct TrapezoidShape: Shape {
    var topInset: CGFloat = 0.2
    func path(in r: CGRect) -> Path {
        let inset = r.width * topInset
        var p = Path()
        p.move(to: CGPoint(x: r.minX + inset, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - 6), control: CGPoint(x: r.maxX - inset * 0.3, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 6), control: CGPoint(x: r.midX, y: r.maxY + 6))
        p.addQuadCurve(to: CGPoint(x: r.minX + inset, y: r.minY), control: CGPoint(x: r.minX + inset * 0.3, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct FlowerShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let petal = min(r.width, r.height) * 0.3
        for i in 0..<5 {
            let a = Double(i) / 5 * 2 * Double.pi - Double.pi / 2
            let center = CGPoint(x: c.x + CGFloat(cos(a)) * petal, y: c.y + CGFloat(sin(a)) * petal)
            p.addEllipse(in: CGRect(x: center.x - petal, y: center.y - petal, width: petal * 2, height: petal * 2))
        }
        return p
    }
}

// MARK: - Original friend looks

enum FriendLooks {
    static func look(for friendID: String) -> AvatarLook {
        switch friendID {
        case "luna": return AvatarLook(skinToneID: "light", hairStyleID: "curls", hairColorID: "midnight", outfitID: "party", accessoryID: "star")
        case "rio": return AvatarLook(skinToneID: "deep", hairStyleID: "bob", hairColorID: "berry", outfitID: "creative", accessoryID: "glasses")
        case "ivy": return AvatarLook(skinToneID: "warm", hairStyleID: "waves", hairColorID: "honey", outfitID: "sunny", accessoryID: "flower")
        case "nova": return AvatarLook(skinToneID: "deep", hairStyleID: "ponytail", hairColorID: "midnight", outfitID: "party", accessoryID: "none")
        case "milo": return AvatarLook(skinToneID: "light", hairStyleID: "bob", hairColorID: "chestnut", outfitID: "sport", accessoryID: "none")
        default: return AvatarLook()
        }
    }
}

// MARK: - Pet

/// Simple original pet portrait (cat or dog) drawn with shapes.
struct PetPortrait: View {
    let species: String
    var size: CGFloat = 120
    private var u: CGFloat { size / 100 }
    private var fur: Color { species == "dog" ? Color(hex: 0xD9A066) : Color(hex: 0xF5A97F) }
    private var furDark: Color { species == "dog" ? Color(hex: 0x9C6538) : Color(hex: 0xE07B4F) }

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.08)).frame(width: 70 * u, height: 10 * u).offset(y: 46 * u)
            // Body
            Ellipse().fill(fur).frame(width: 64 * u, height: 46 * u).offset(y: 24 * u)
            Ellipse().fill(Color.white.opacity(0.75)).frame(width: 30 * u, height: 26 * u).offset(y: 28 * u)
            // Ears
            if species == "dog" {
                Ellipse().fill(furDark).frame(width: 20 * u, height: 36 * u)
                    .rotationEffect(.degrees(20)).offset(x: -30 * u, y: -14 * u)
                Ellipse().fill(furDark).frame(width: 20 * u, height: 36 * u)
                    .rotationEffect(.degrees(-20)).offset(x: 30 * u, y: -14 * u)
            } else {
                TriangleShape().fill(fur).frame(width: 22 * u, height: 24 * u)
                    .rotationEffect(.degrees(-14)).offset(x: -20 * u, y: -38 * u)
                TriangleShape().fill(fur).frame(width: 22 * u, height: 24 * u)
                    .rotationEffect(.degrees(14)).offset(x: 20 * u, y: -38 * u)
                TriangleShape().fill(Color(hex: 0xFFC9D6)).frame(width: 11 * u, height: 12 * u)
                    .rotationEffect(.degrees(-14)).offset(x: -20 * u, y: -35 * u)
                TriangleShape().fill(Color(hex: 0xFFC9D6)).frame(width: 11 * u, height: 12 * u)
                    .rotationEffect(.degrees(14)).offset(x: 20 * u, y: -35 * u)
            }
            // Head
            Circle().fill(fur).frame(width: 58 * u).offset(y: -14 * u)
            Ellipse().fill(Color.white.opacity(0.8)).frame(width: 30 * u, height: 20 * u).offset(y: -4 * u)
            // Eyes
            ForEach([-11.0, 11.0], id: \.self) { x in
                Ellipse().fill(Theme.ink).frame(width: 7 * u, height: 9 * u)
                    .overlay(Circle().fill(.white).frame(width: 2.5 * u).offset(x: 1 * u, y: -2 * u))
                    .offset(x: CGFloat(x) * u, y: -18 * u)
            }
            // Nose & mouth
            Ellipse().fill(species == "dog" ? Theme.ink : Color(hex: 0xFF7A9C))
                .frame(width: 8 * u, height: 6 * u).offset(y: -8 * u)
            SmileShape().stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))
                .frame(width: 10 * u, height: 4 * u).offset(y: -3 * u)
            ForEach([-20.0, 20.0], id: \.self) { x in
                Circle().fill(Color(hex: 0xFF7A9C).opacity(0.35)).frame(width: 8 * u)
                    .offset(x: CGFloat(x) * u, y: -7 * u)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct TriangleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
