import SwiftUI

struct DressUpView: View {
    @EnvironmentObject var store: GameStore
    @State private var message = loc("Choose a look for your character.", "Karakterin için bir görünüm seç.")
    @State private var cometPreviewActive = false
    @State private var pendingOutfit: Outfit?

    private var look: AvatarLook { AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID) }

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var wide: Bool { vSize == .compact || hSize == .regular }

    var body: some View {
        Group {
            if wide {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView { VStack(spacing: 16) { mirrorSection }.padding(.vertical, 12) }
                        .frame(maxWidth: .infinity)
                    ScrollView { VStack(spacing: 16) { wardrobeSection(columns: 3) }.padding(.vertical, 12) }
                        .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        mirrorSection
                        wardrobeSection(columns: 2)
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .confirmationDialog(pendingOutfit.map { loc("Buy the \($0.name) look?", "\(trName($0.name)) görünümü alınsın mı?") } ?? loc("Buy outfit?", "Kıyafet alınsın mı?"),
                            isPresented: Binding(get: { pendingOutfit != nil }, set: { if !$0 { pendingOutfit = nil } }),
                            titleVisibility: .visible, presenting: pendingOutfit) { outfit in
            Button(loc("Buy for \(outfit.cost) coins", "\(outfit.cost) jetona al")) { wear(outfit) }
            Button(loc("Not now", "Şimdi değil"), role: .cancel) { }
        } message: { outfit in
            Text(loc("\(outfit.name) costs \(outfit.cost) coins. You have \(store.coins) coins.", "\(trName(outfit.name)) \(outfit.cost) jeton. Sende \(store.coins) jeton var."))
        }
    }

    @ViewBuilder private var mirrorSection: some View {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.lavenderSoft, Theme.pinkSoft], startPoint: .top, endPoint: .bottom))
                        .frame(height: 230)
                        .overlay(alignment: .bottom) {
                            Ellipse().fill(Color.white.opacity(0.7)).frame(width: 190, height: 34).padding(.bottom, 16)
                        }
                    // Wardrobe mirror sparkle
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(Theme.lavender.opacity(0.6))
                        .offset(x: -110, y: -70)
                    AvatarView(look: look, size: 150)
                        .scaleEffect(cometPreviewActive && !store.playerSettings.reducedMotion ? 1.06 : 1.0)
                        .shadow(color: store.isCometVeilEquipped && cometPreviewActive ? Color(hex: 0x7FD8FF).opacity(0.9) : .clear, radius: 18)
                        .animation(store.playerSettings.reducedMotion ? nil : .easeInOut(duration: store.motionAnimationDuration), value: cometPreviewActive)
                }
                .padding(.horizontal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(avatarDescription)

                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if store.hasLightkeeperStreakCrown {
                    QuestCard(icon: "crown.fill", tint: Theme.sun, title: loc("Starlight Crown", "Yıldız Işığı Tacı"),
                              detail: loc("Wear it, then visit Lumen Canopy for a daily Crown Spark · +35 coins · +1 star", "Tak ve günlük Taç Kıvılcımı için Işık Gölgeliği\'ne git · +35 jeton · +1 yıldız")) {
                        Button(store.isStarlightCrownEquipped ? loc("Equipped", "Takılı") : loc("Wear", "Tak")) { store.updateCharacter(accessoryID:"starlightCrown"); message=loc("Starlight Crown equipped!", "Yıldız Işığı Tacı takıldı!") }.disabled(store.isStarlightCrownEquipped)
                    }
                    .padding(.horizontal)
                }

                if store.isCometVeilUnlocked {
                    QuestCard(icon: "sparkles", tint: Color(hex: 0x4FC9E0), title: loc("Comet Veil", "Kuyruklu Yıldız Peçesi"),
                              detail: loc("A shimmering original accessory earned at 7 Crown Spark moments.", "7 Taç Kıvılcımı anında kazanılan parıltılı, özgün bir aksesuar.")) {
                        VStack(spacing: 4) {
                            Button(store.isCometVeilEquipped ? loc("Equipped", "Takılı") : loc("Wear", "Tak")) {
                                store.updateCharacter(accessoryID:"cometVeil")
                                message=loc("Comet Veil equipped!", "Kuyruklu Yıldız Peçesi takıldı!")
                            }.disabled(store.isCometVeilEquipped)
                            if store.isCometVeilEquipped {
                                Button(loc("Preview glow", "Işıltıyı gör")) {
                                    cometPreviewActive.toggle()
                                    message=loc("Comet Veil glimmers around your character!", "Kuyruklu Yıldız Peçesi karakterinin etrafında parlıyor!")
                                }
                                .accessibilityIdentifier("dressUp.cometVeilPreview")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
    }

    @ViewBuilder private func wardrobeSection(columns: Int) -> some View {
                SectionTitle(title: loc("Outfits", "Kıyafetler"), icon: "tshirt.fill").padding(.horizontal)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                    ForEach(store.outfits) { outfit in
                        let owned = store.ownsOutfit(outfit)
                        let selected = store.selectedOutfitID == outfit.id
                        Button { choose(outfit) } label: {
                            VStack(spacing: 6) {
                                AvatarView(look: AvatarLook(skinToneID: look.skinToneID, hairStyleID: look.hairStyleID,
                                                            hairColorID: look.hairColorID, outfitID: outfit.id), size: 70)
                                    .frame(height: 90)
                                Text(trName(outfit.name)).font(.subheadline.weight(.heavy))
                                if owned {
                                    Text(selected ? loc("Wearing ✓", "Giyiliyor ✓") : loc("Owned", "Sende var"))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(selected ? Theme.mint : Theme.inkSoft)
                                } else {
                                    HStack(spacing: 3) {
                                        Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Theme.peach)
                                        Text(loc("\(outfit.cost) coins", "\(outfit.cost) jeton"))
                                    }
                                    .font(.caption.weight(.heavy))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(TileButtonStyle(selected: selected, tint: AvatarLook(outfitID: outfit.id).outfit))
                        .accessibilityLabel(owned ? loc("\(outfit.name) outfit, \(selected ? "wearing" : "owned")", "\(trName(outfit.name)) kıyafeti, \(selected ? "giyiliyor" : "sende var")") : loc("\(outfit.name) outfit, \(outfit.cost) coins", "\(trName(outfit.name)) kıyafeti, \(outfit.cost) jeton"))
                    }
                }
                .padding(.horizontal)
    }

    private var avatarDescription: String {
        var parts = [loc("Your character wearing the \(store.outfits.first { $0.id == store.selectedOutfitID }?.name ?? "Sunny") look", "Karakterin \(trName(store.outfits.first { $0.id == store.selectedOutfitID }?.name ?? "Sunny")) görünümünde")]
        if store.isStarlightCrownEquipped { parts.append(loc("Starlight Crown equipped", "Yıldız Işığı Tacı takılı")) }
        if store.isCometVeilEquipped { parts.append(loc("Comet Veil equipped", "Kuyruklu Yıldız Peçesi takılı")) }
        return parts.joined(separator: ", ")
    }

    private func choose(_ outfit: Outfit) {
        if store.ownsOutfit(outfit) { wear(outfit); return }
        guard store.coins >= outfit.cost else {
            message = loc("Not enough coins yet — you need \(outfit.cost - store.coins) more.", "Henüz yeterli jeton yok; \(outfit.cost - store.coins) jeton daha gerekiyor.")
            Feedback.play(.warning, settings: store.playerSettings)
            return
        }
        if store.playerSettings.purchaseConfirmation && outfit.cost > 0 { pendingOutfit = outfit } else { wear(outfit) }
    }

    private func wear(_ outfit: Outfit) {
        let wasOwned = store.ownsOutfit(outfit)
        if store.selectOutfit(outfit) {
            message = loc("\(outfit.name) look selected!", "\(trName(outfit.name)) görünümü seçildi!")
            Feedback.play(wasOwned ? .tap : .purchase, settings: store.playerSettings)
        } else {
            message = loc("Not enough coins yet.", "Henüz yeterli jeton yok.")
            Feedback.play(.warning, settings: store.playerSettings)
        }
    }
}
