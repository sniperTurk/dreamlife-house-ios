import SwiftUI

struct DressUpView: View {
    @EnvironmentObject var store: GameStore
    @State private var message = "Choose a look for your character."
    @State private var cometPreviewActive = false
    @State private var pendingOutfit: Outfit?

    private var look: AvatarLook { AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                    QuestCard(icon: "crown.fill", tint: Theme.sun, title: "Starlight Crown",
                              detail: "Wear it, then visit Lumen Canopy for a daily Crown Spark · +35 coins · +1 star") {
                        Button(store.isStarlightCrownEquipped ? "Equipped" : "Wear") { store.updateCharacter(accessoryID:"starlightCrown"); message="Starlight Crown equipped!" }.disabled(store.isStarlightCrownEquipped)
                    }
                    .padding(.horizontal)
                }

                if store.isCometVeilUnlocked {
                    QuestCard(icon: "sparkles", tint: Color(hex: 0x4FC9E0), title: "Comet Veil",
                              detail: "A shimmering original accessory earned at 7 Crown Spark moments.") {
                        VStack(spacing: 4) {
                            Button(store.isCometVeilEquipped ? "Equipped" : "Wear") {
                                store.updateCharacter(accessoryID:"cometVeil")
                                message="Comet Veil equipped!"
                            }.disabled(store.isCometVeilEquipped)
                            if store.isCometVeilEquipped {
                                Button("Preview glow") {
                                    cometPreviewActive.toggle()
                                    message="Comet Veil glimmers around your character!"
                                }
                                .accessibilityIdentifier("dressUp.cometVeilPreview")
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                SectionTitle(title: "Outfits", icon: "tshirt.fill").padding(.horizontal)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.outfits) { outfit in
                        let owned = store.ownsOutfit(outfit)
                        let selected = store.selectedOutfitID == outfit.id
                        Button { choose(outfit) } label: {
                            VStack(spacing: 6) {
                                AvatarView(look: AvatarLook(skinToneID: look.skinToneID, hairStyleID: look.hairStyleID,
                                                            hairColorID: look.hairColorID, outfitID: outfit.id), size: 70)
                                    .frame(height: 90)
                                Text(outfit.name).font(.subheadline.weight(.heavy))
                                if owned {
                                    Text(selected ? "Wearing ✓" : "Owned")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(selected ? Theme.mint : Theme.inkSoft)
                                } else {
                                    HStack(spacing: 3) {
                                        Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Theme.peach)
                                        Text("\(outfit.cost) coins")
                                    }
                                    .font(.caption.weight(.heavy))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(TileButtonStyle(selected: selected, tint: AvatarLook(outfitID: outfit.id).outfit))
                        .accessibilityLabel(owned ? "\(outfit.name) outfit, \(selected ? "wearing" : "owned")" : "\(outfit.name) outfit, \(outfit.cost) coins")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 28)
        }
        .confirmationDialog(pendingOutfit.map { "Buy the \($0.name) look?" } ?? "Buy outfit?",
                            isPresented: Binding(get: { pendingOutfit != nil }, set: { if !$0 { pendingOutfit = nil } }),
                            titleVisibility: .visible, presenting: pendingOutfit) { outfit in
            Button("Buy for \(outfit.cost) coins") { wear(outfit) }
            Button("Not now", role: .cancel) { }
        } message: { outfit in
            Text("\(outfit.name) costs \(outfit.cost) coins. You have \(store.coins) coins.")
        }
    }

    private var avatarDescription: String {
        var parts = ["Your character wearing the \(store.outfits.first { $0.id == store.selectedOutfitID }?.name ?? "Sunny") look"]
        if store.isStarlightCrownEquipped { parts.append("Starlight Crown equipped") }
        if store.isCometVeilEquipped { parts.append("Comet Veil equipped") }
        return parts.joined(separator: ", ")
    }

    private func choose(_ outfit: Outfit) {
        if store.ownsOutfit(outfit) { wear(outfit); return }
        guard store.coins >= outfit.cost else {
            message = "Not enough coins yet — you need \(outfit.cost - store.coins) more."
            Feedback.play(.warning, settings: store.playerSettings)
            return
        }
        if store.playerSettings.purchaseConfirmation && outfit.cost > 0 { pendingOutfit = outfit } else { wear(outfit) }
    }

    private func wear(_ outfit: Outfit) {
        let wasOwned = store.ownsOutfit(outfit)
        if store.selectOutfit(outfit) {
            message = "\(outfit.name) look selected!"
            Feedback.play(wasOwned ? .tap : .purchase, settings: store.playerSettings)
        } else {
            message = "Not enough coins yet."
            Feedback.play(.warning, settings: store.playerSettings)
        }
    }
}
