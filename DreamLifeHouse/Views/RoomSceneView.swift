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
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.5, width: 0.38, height: 0.42), zoneLabel: "Bed · drop here to rest",
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "kitchen":
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.42, width: 0.38, height: 0.5), zoneLabel: "Snack bar · drop here",
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "bathroom":
            return RoomLayout(actionZone: CGRect(x: 0.6, y: 0.4, width: 0.38, height: 0.52), zoneLabel: "Shower · drop here",
                              mainDecor: CGPoint(x: 0.36, y: 0.80), sideDecor: CGPoint(x: 0.12, y: 0.76),
                              friendSpot: CGPoint(x: 0.24, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        case "garden":
            return RoomLayout(actionZone: CGRect(x: 0.02, y: 0.42, width: 0.4, height: 0.5), zoneLabel: "Play area · drop here",
                              mainDecor: CGPoint(x: 0.64, y: 0.80), sideDecor: CGPoint(x: 0.88, y: 0.76),
                              friendSpot: CGPoint(x: 0.76, y: 0.52), petSpot: CGPoint(x: 0.5, y: 0.9))
        default: // living
            return RoomLayout(actionZone: CGRect(x: 0.02, y: 0.5, width: 0.38, height: 0.42), zoneLabel: "Dance floor · drop here",
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
            prop("refrigerator.fill", size: h * 0.34, color: Color(hex: 0x6BB8D9), at: CGPoint(x: w * 0.9, y: h * 0.58))
            prop("oven.fill", size: h * 0.22, color: Color(hex: 0xFF8C69), at: CGPoint(x: w * 0.71, y: h * 0.62))
            prop("cup.and.saucer.fill", size: h * 0.08, color: Theme.pink, at: CGPoint(x: w * 0.18, y: h * 0.48))
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
            prop("tv.fill", size: h * 0.14, color: Theme.ink.opacity(0.75), at: CGPoint(x: w * 0.18, y: h * 0.3))
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
