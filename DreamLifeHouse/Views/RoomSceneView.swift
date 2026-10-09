import SwiftUI

/// Layout data for each illustrated room. Coordinates are unit values (0...1)
/// inside the room stage, matching GameStore's drop-zone rules.
struct RoomLayout {
    let actionZone: CGRect          // where dropping the character triggers the room activity
    let zoneLabel: String
    let mainDecor: CGPoint
    let sideDecor: CGPoint
    let friendSpot: CGPoint
    let petSpot: CGPoint

    static func forRoom(_ roomID: String) -> RoomLayout {
        switch roomID {
        case "bedroom":
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.5, width: 0.38, height: 0.42), zoneLabel: loc("Bed · drop here to rest", "Yatak · dinlenmek için bırak"),
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "kitchen":
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.42, width: 0.38, height: 0.5), zoneLabel: loc("Snack bar · drop here", "Atıştırma · buraya bırak"),
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "bathroom":
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.4, width: 0.38, height: 0.52), zoneLabel: loc("Shower · drop here", "Duş · buraya bırak"),
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "garden":
            return RoomLayout(actionZone: CGRect(x: 0.02, y: 0.42, width: 0.4, height: 0.5), zoneLabel: loc("Play area · drop here", "Oyun alanı · buraya bırak"),
                              mainDecor: CGPoint(x: 0.64, y: 0.80), sideDecor: CGPoint(x: 0.88, y: 0.76),
                              friendSpot: CGPoint(x: 0.76, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        default: // living
            return RoomLayout(actionZone: CGRect(x: 0.02, y: 0.5, width: 0.38, height: 0.42), zoneLabel: loc("Dance floor · drop here", "Dans pisti · buraya bırak"),
                              mainDecor: CGPoint(x: 0.64, y: 0.80), sideDecor: CGPoint(x: 0.88, y: 0.76),
                              friendSpot: CGPoint(x: 0.76, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        }
    }
}

/// Hand-built vector illustration for each room. Purely decorative.
struct RoomBackdrop: View {
    let roomID: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                if roomID == "garden" { gardenScene(w: w, h: h) } else { indoorScene(w: w, h: h) }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Indoor rooms

    private var wallColors: [Color] {
        switch roomID {
        case "bedroom": return [Color(hex: 0xEDE4FF), Color(hex: 0xDCCDFF)]
        case "kitchen": return [Color(hex: 0xE3F8F0), Color(hex: 0xC8EFE2)]
        case "bathroom": return [Color(hex: 0xE4F3FF), Color(hex: 0xC9E6FF)]
        default: return [Color(hex: 0xFFE8F1), Color(hex: 0xFFD3E5)]
        }
    }
    private var floorColor: Color {
        switch roomID {
        case "bedroom": return Color(hex: 0xC7B3F2)
        case "kitchen": return Color(hex: 0xF7F1E8)
        case "bathroom": return Color(hex: 0xE9F4FF)
        default: return Color(hex: 0xF1C79B)
        }
    }

    @ViewBuilder private func indoorScene(w: CGFloat, h: CGFloat) -> some View {
        let floorTop = h * 0.62
        // Wall
        LinearGradient(colors: wallColors, startPoint: .top, endPoint: .bottom)
        // Wallpaper dots / tiles
        let roomID = self.roomID
        Canvas { ctx, size in
            if roomID == "kitchen" || roomID == "bathroom" {
                let tile: CGFloat = 22
                var y = floorTop - tile * 3
                while y < floorTop {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.stroke(Path(roundedRect: CGRect(x: x + 1, y: y + 1, width: tile - 2, height: tile - 2), cornerRadius: 4),
                                   with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                        x += tile
                    }
                    y += tile
                }
            } else {
                var row = 0
                var y: CGFloat = 16
                while y < floorTop - 10 {
                    var x: CGFloat = row % 2 == 0 ? 14 : 34
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 5)), with: .color(.white.opacity(0.55)))
                        x += 40
                    }
                    y += 26; row += 1
                }
            }
        }
        // Skirting board
        Rectangle().fill(Color.white.opacity(0.85))
            .frame(width: w, height: 6)
            .offset(y: floorTop - 6)
        // Floor
        floorLayer(w: w, h: h, top: floorTop)
        // Window
        window(w: w, h: h)
        // Room furniture (decorative, behind decor slots)
        furniture(w: w, h: h)
    }

    @ViewBuilder private func floorLayer(w: CGFloat, h: CGFloat, top: CGFloat) -> some View {
        let floorColor = self.floorColor
        let roomID = self.roomID
        Canvas { ctx, size in
            let rect = CGRect(x: 0, y: top, width: size.width, height: size.height - top)
            ctx.fill(Path(rect), with: .color(floorColor))
            switch roomID {
            case "kitchen":
                let tile: CGFloat = 26
                var y = top; var row = 0
                while y < size.height {
                    var x: CGFloat = row % 2 == 0 ? 0 : tile
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: y, width: tile, height: tile)), with: .color(Color(hex: 0xFFB8C9).opacity(0.55)))
                        x += tile * 2
                    }
                    y += tile; row += 1
                }
            case "bathroom":
                let tile: CGFloat = 24
                var y = top
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.stroke(Path(CGRect(x: x, y: y, width: tile, height: tile)), with: .color(.white), lineWidth: 1.5)
                        x += tile
                    }
                    y += tile
                }
            case "bedroom":
                ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.18, y: top + 18, width: size.width * 0.5, height: (size.height - top) * 0.62)),
                         with: .color(Color(hex: 0xFFC6E0).opacity(0.9)))
            default:
                var y = top + 16
                while y < size.height {
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) },
                               with: .color(Color(hex: 0xD9A877).opacity(0.7)), lineWidth: 1.2)
                    y += 18
                }
            }
        }
    }

    @ViewBuilder private func window(w: CGFloat, h: CGFloat) -> some View {
        let night = roomID == "bedroom"
        let ww = min(w * 0.26, 110), wh = h * 0.30
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: night ? [Color(hex: 0x3B3F8F), Color(hex: 0x6E63C9)] : [Color(hex: 0x8FD3FF), Color(hex: 0xD6F0FF)],
                                     startPoint: .top, endPoint: .bottom))
            if night {
                Image(systemName: "moon.stars.fill").font(.system(size: wh * 0.38)).foregroundStyle(Color(hex: 0xFFE38A))
            } else {
                Image(systemName: "cloud.fill").font(.system(size: wh * 0.32)).foregroundStyle(.white)
                    .offset(x: -ww * 0.12, y: wh * 0.08)
                Image(systemName: "sun.max.fill").font(.system(size: wh * 0.22)).foregroundStyle(Theme.sun)
                    .offset(x: ww * 0.24, y: -wh * 0.22)
            }
            Rectangle().fill(Color.white).frame(width: 4)
            Rectangle().fill(Color.white).frame(height: 4)
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white, lineWidth: 6)
        }
        .frame(width: ww, height: wh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .position(x: w * 0.5, y: h * 0.27)
    }

    @ViewBuilder private func furniture(w: CGFloat, h: CGFloat) -> some View {
        switch roomID {
        case "bedroom":
            prop("bed.double.fill", size: h * 0.30, color: Color(hex: 0x8C6CE0), at: CGPoint(x: w * 0.79, y: h * 0.70))
            prop("lamp.floor.fill", size: h * 0.20, color: Color(hex: 0xFFB84D), at: CGPoint(x: w * 0.93, y: h * 0.48))
            prop("star.fill", size: h * 0.06, color: Theme.sun, at: CGPoint(x: w * 0.2, y: h * 0.14))
            prop("star.fill", size: h * 0.04, color: Theme.sun, at: CGPoint(x: w * 0.82, y: h * 0.18))
        case "kitchen":
            prop("cup.and.saucer.fill", size: h * 0.07, color: Theme.pink, at: CGPoint(x: w * 0.1, y: h * 0.4))
        case "bathroom":
            prop("bathtub.fill", size: h * 0.28, color: Color(hex: 0x5DB3FF), at: CGPoint(x: w * 0.8, y: h * 0.72))
            prop("shower.fill", size: h * 0.16, color: Color(hex: 0x8AA4C8), at: CGPoint(x: w * 0.88, y: h * 0.38))
            bubbles(w: w, h: h)
        default:
            // Dance floor
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF9AC6), Color(hex: 0xB9A2FF), Color(hex: 0x8CD7FF)],
                                     startPoint: .leading, endPoint: .trailing))
                .opacity(0.8)
                .frame(width: w * 0.32, height: h * 0.12)
                .rotation3DEffect(.degrees(55), axis: (x: 1, y: 0, z: 0))
                .position(x: w * 0.2, y: h * 0.82)
            prop("music.note", size: h * 0.08, color: Theme.lavender, at: CGPoint(x: w * 0.12, y: h * 0.56))
            prop("music.note", size: h * 0.06, color: Theme.pink, at: CGPoint(x: w * 0.28, y: h * 0.5))
            prop("photo.artframe", size: h * 0.12, color: Color(hex: 0xC48A5A), at: CGPoint(x: w * 0.82, y: h * 0.26))
        }
    }

    private func bubbles(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .background(Circle().fill(Color.white.opacity(0.3)))
                    .frame(width: CGFloat(8 + i * 3), height: CGFloat(8 + i * 3))
                    .position(x: w * (0.64 + CGFloat(i % 3) * 0.08), y: h * (0.5 - CGFloat(i) * 0.04))
            }
        }
    }

    private func prop(_ symbol: String, size: CGFloat, color: Color, at point: CGPoint) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size))
            .foregroundStyle(color.gradient)
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
            .position(point)
    }

    // MARK: Garden

    @ViewBuilder private func gardenScene(w: CGFloat, h: CGFloat) -> some View {
        LinearGradient(colors: [Color(hex: 0x9ED8FF), Color(hex: 0xE3F5FF)], startPoint: .top, endPoint: .bottom)
        Image(systemName: "sun.max.fill").font(.system(size: h * 0.16)).foregroundStyle(Theme.sun)
            .position(x: w * 0.86, y: h * 0.15)
        Image(systemName: "cloud.fill").font(.system(size: h * 0.12)).foregroundStyle(.white)
            .position(x: w * 0.22, y: h * 0.14)
        Image(systemName: "cloud.fill").font(.system(size: h * 0.08)).foregroundStyle(.white.opacity(0.9))
            .position(x: w * 0.55, y: h * 0.22)
        // Hills
        Ellipse().fill(Color(hex: 0xA6E39A)).frame(width: w * 0.9, height: h * 0.4).position(x: w * 0.2, y: h * 0.62)
        Ellipse().fill(Color(hex: 0x8DD982)).frame(width: w * 0.9, height: h * 0.4).position(x: w * 0.85, y: h * 0.64)
        // Fence
        HStack(spacing: 6) {
            ForEach(0..<14, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 8, height: h * 0.12)
            }
        }
        .position(x: w * 0.5, y: h * 0.53)
        // Lawn
        Rectangle().fill(LinearGradient(colors: [Color(hex: 0x7ED074), Color(hex: 0x5BBF5B)], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h * 0.42)
            .position(x: w * 0.5, y: h * 0.79)
        // Pool
        Ellipse().fill(LinearGradient(colors: [Color(hex: 0x7FDBFF), Color(hex: 0x3BB4F2)], startPoint: .top, endPoint: .bottom))
            .overlay(Ellipse().strokeBorder(Color.white, lineWidth: 4))
            .frame(width: w * 0.32, height: h * 0.14)
            .position(x: w * 0.6, y: h * 0.9)
        Image(systemName: "tree.fill").font(.system(size: h * 0.28)).foregroundStyle(Color(hex: 0x3E9E4F).gradient)
            .position(x: w * 0.1, y: h * 0.48)
        Image(systemName: "camera.macro").font(.system(size: h * 0.07)).foregroundStyle(Theme.pink)
            .position(x: w * 0.42, y: h * 0.68)
        Image(systemName: "camera.macro").font(.system(size: h * 0.06)).foregroundStyle(Theme.sun)
            .position(x: w * 0.94, y: h * 0.88)
        Image(systemName: "figure.play").font(.system(size: h * 0.12)).foregroundStyle(Theme.peach.gradient)
            .position(x: w * 0.3, y: h * 0.6)
    }
}

// MARK: - Room furniture

/// Where each furniture piece stands in its room (unit coordinates) and how
/// tall it is relative to the stage height.
enum FurnitureSpots {
    static func spot(for id: String) -> (point: CGPoint, size: CGFloat) {
        switch id {
        // Kitchen: appliances on the right around the snack bar, table on the left.
        case "kitchen.fridge":    return (CGPoint(x: 0.87, y: 0.50), 0.32)
        case "kitchen.oven":      return (CGPoint(x: 0.73, y: 0.57), 0.20)
        case "kitchen.pot":       return (CGPoint(x: 0.73, y: 0.42), 0.08)
        case "kitchen.sink":      return (CGPoint(x: 0.57, y: 0.57), 0.15)
        case "kitchen.cabinet":   return (CGPoint(x: 0.80, y: 0.17), 0.15)
        case "kitchen.pan":       return (CGPoint(x: 0.95, y: 0.19), 0.08)
        case "kitchen.table":     return (CGPoint(x: 0.24, y: 0.68), 0.20)
        case "kitchen.plate":     return (CGPoint(x: 0.24, y: 0.585), 0.05)
        // Living room
        case "living.tv":         return (CGPoint(x: 0.18, y: 0.30), 0.14)
        case "living.fireplace":  return (CGPoint(x: 0.50, y: 0.54), 0.18)
        case "living.clock":      return (CGPoint(x: 0.66, y: 0.14), 0.08)
        case "living.bookshelf":  return (CGPoint(x: 0.95, y: 0.46), 0.22)
        case "living.lamp":       return (CGPoint(x: 0.05, y: 0.46), 0.20)
        case "living.armchair":   return (CGPoint(x: 0.48, y: 0.75), 0.13)
        // Bedroom
        case "bedroom.wardrobe":  return (CGPoint(x: 0.08, y: 0.48), 0.26)
        case "bedroom.desk":      return (CGPoint(x: 0.62, y: 0.50), 0.09)
        case "bedroom.teddy":     return (CGPoint(x: 0.71, y: 0.61), 0.08)
        case "bedroom.pillow":    return (CGPoint(x: 0.87, y: 0.62), 0.06)
        case "bedroom.globe":     return (CGPoint(x: 0.37, y: 0.55), 0.10)
        case "bedroom.chair":     return (CGPoint(x: 0.52, y: 0.70), 0.12)
        // Bathroom
        case "bathroom.toilet":   return (CGPoint(x: 0.10, y: 0.62), 0.18)
        case "bathroom.sink":     return (CGPoint(x: 0.30, y: 0.60), 0.16)
        case "bathroom.mirror":   return (CGPoint(x: 0.30, y: 0.30), 0.13)
        case "bathroom.towel":    return (CGPoint(x: 0.12, y: 0.30), 0.11)
        case "bathroom.washer":   return (CGPoint(x: 0.48, y: 0.67), 0.16)
        case "bathroom.duck":     return (CGPoint(x: 0.74, y: 0.62), 0.06)
        // Garden
        case "garden.tent":       return (CGPoint(x: 0.88, y: 0.52), 0.16)
        case "garden.birdhouse":  return (CGPoint(x: 0.30, y: 0.38), 0.10)
        case "garden.ball":       return (CGPoint(x: 0.46, y: 0.80), 0.06)
        case "garden.umbrella":   return (CGPoint(x: 0.50, y: 0.58), 0.16)
        case "garden.bicycle":    return (CGPoint(x: 0.68, y: 0.64), 0.10)
        case "garden.carrot":     return (CGPoint(x: 0.94, y: 0.90), 0.06)
        default:                  return (CGPoint(x: 0.5, y: 0.6), 0.1)
        }
    }

    static func tint(for id: String) -> Color {
        switch id {
        case "kitchen.fridge": return Color(hex: 0x6BB8D9)
        case "kitchen.oven": return Color(hex: 0xFF8C69)
        case "kitchen.cabinet", "bedroom.wardrobe", "living.bookshelf", "kitchen.table": return Color(hex: 0xC48A5A)
        case "kitchen.pan", "kitchen.sink", "bathroom.sink", "bathroom.washer": return Color(hex: 0x8AA4C8)
        case "living.tv": return Theme.ink.opacity(0.75)
        case "living.fireplace": return Color(hex: 0xE0785A)
        case "living.clock", "bedroom.desk", "living.lamp": return Color(hex: 0xFFB84D)
        case "living.armchair", "bedroom.chair": return Theme.lavender
        case "bedroom.teddy": return Color(hex: 0xC48A5A)
        case "bedroom.globe": return Theme.sky
        case "bathroom.toilet": return Color(hex: 0x9FB6D6)
        case "garden.tent": return Theme.peach
        case "garden.birdhouse": return Color(hex: 0xC48A5A)
        case "garden.ball": return Theme.ink
        case "garden.umbrella": return Theme.pink
        case "garden.bicycle": return Theme.sky
        case "garden.carrot": return Color(hex: 0xFF8C3A)
        default: return Theme.pink
        }
    }
}

/// Draws one furniture piece: an SF Symbol, or a small hand-built vector for
/// items that have no symbol ("custom." icons).
struct FurnitureArt: View {
    let item: FurnitureItem
    let size: CGFloat

    var body: some View {
        Group {
            switch item.icon {
            case "custom.plate": plate
            case "custom.pot": pot
            case "custom.pillow": pillow
            case "custom.mirror": mirror
            case "custom.towel": towel
            case "custom.duck": duck
            case "custom.birdhouse": birdhouse
            default:
                Image(systemName: item.icon)
                    .font(.system(size: size))
                    .foregroundStyle(FurnitureSpots.tint(for: item.id).gradient)
            }
        }
        .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
    }

    private var plate: some View {
        ZStack {
            Ellipse().fill(Color.white).overlay(Ellipse().strokeBorder(Theme.pink, lineWidth: max(1.5, size * 0.08)))
            Ellipse().strokeBorder(Theme.pink.opacity(0.35), lineWidth: 1).padding(size * 0.22)
        }
        .frame(width: size * 1.6, height: size * 0.7)
    }

    private var pot: some View {
        let potColor = Color(hex: 0xE0785A)
        return VStack(spacing: size * 0.02) {
            Circle().fill(potColor.opacity(0.9)).frame(width: size * 0.18, height: size * 0.18)
            Capsule().fill(potColor.gradient).frame(width: size * 1.15, height: size * 0.16)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).fill(potColor.gradient)
                    .frame(width: size, height: size * 0.62)
                HStack { Capsule().fill(potColor).frame(width: size * 0.22, height: size * 0.12); Spacer(); Capsule().fill(potColor).frame(width: size * 0.22, height: size * 0.12) }
                    .frame(width: size * 1.38)
                Capsule().fill(Color.white.opacity(0.35)).frame(width: size * 0.5, height: size * 0.07).offset(y: -size * 0.1)
            }
        }
    }

    private var pillow: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(LinearGradient(colors: [Color.white, Theme.pinkSoft], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).strokeBorder(Theme.pink.opacity(0.6), lineWidth: 1.5))
            .frame(width: size * 1.7, height: size)
    }

    private var mirror: some View {
        ZStack {
            Ellipse().fill(LinearGradient(colors: [Color(hex: 0xE8F7FF), Color(hex: 0xB5E3FF)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Ellipse().strokeBorder(Color(hex: 0xF4C25B), lineWidth: max(2, size * 0.08))
            Capsule().fill(Color.white.opacity(0.8)).frame(width: size * 0.08, height: size * 0.4).rotationEffect(.degrees(25)).offset(x: -size * 0.14, y: -size * 0.12)
        }
        .frame(width: size * 0.72, height: size)
    }

    private var towel: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(hex: 0x8AA4C8)).frame(width: size * 1.1, height: size * 0.1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: size * 0.08).fill(Theme.mint.gradient)
                VStack(spacing: size * 0.06) {
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: size * 0.06)
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: size * 0.06)
                }
                .padding(.bottom, size * 0.12)
            }
            .frame(width: size * 0.8, height: size * 0.9)
        }
    }

    private var birdhouse: some View {
        let wood = Color(hex: 0xC48A5A)
        return VStack(spacing: 0) {
            TriangleShape().fill(Theme.pink.gradient).frame(width: size * 1.1, height: size * 0.45)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.08).fill(wood.gradient)
                Circle().fill(Theme.ink.opacity(0.8)).frame(width: size * 0.3, height: size * 0.3)
            }
            .frame(width: size * 0.85, height: size * 0.7)
            Rectangle().fill(wood.opacity(0.85)).frame(width: size * 0.12, height: size * 0.6)
        }
    }

    private var duck: some View {
        let yellow = Color(hex: 0xFFD23F)
        return ZStack {
            Ellipse().fill(yellow.gradient).frame(width: size * 1.3, height: size * 0.75).offset(y: size * 0.18)
            Circle().fill(yellow).frame(width: size * 0.62, height: size * 0.62).offset(x: size * 0.28, y: -size * 0.22)
            Circle().fill(Theme.ink).frame(width: size * 0.1, height: size * 0.1).offset(x: size * 0.38, y: -size * 0.28)
            Capsule().fill(Color(hex: 0xFF8C3A)).frame(width: size * 0.3, height: size * 0.14).offset(x: size * 0.66, y: -size * 0.18)
        }
        .frame(width: size * 1.6, height: size * 1.2)
    }
}
