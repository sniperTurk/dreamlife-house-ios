import SwiftUI

struct CharacterCreatorView: View {
    @EnvironmentObject var store: GameStore
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var look: AvatarLook { AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white, Theme.pinkSoft], center: .center, startRadius: 10, endRadius: 130))
                        .frame(width: 230, height: 230)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 6))
                        .shadow(color: Theme.pink.opacity(0.2), radius: 14, y: 8)
                    AvatarView(look: look, size: 150)
                        .offset(y: 4)
                }
                .padding(.top, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(loc("Your character \(store.characterProfile.name)", "Karakterin \(store.characterProfile.name)"))

                HStack(spacing: 10) {
                    Image(systemName: "pencil").foregroundStyle(Theme.pink).font(.headline)
                    TextField(loc("Character name", "Karakter adı"), text: $name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { saveName() }
                    if nameFocused || name != store.characterProfile.name {
                        Button(loc("Save", "Kaydet")) { saveName() }.buttonStyle(PillButtonStyle())
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .dreamCard(cornerRadius: 18)
                .padding(.horizontal)

                optionRow(loc("Hair", "Saç"), options: store.hairStyles, selected: store.characterProfile.hairStyleID) { store.updateCharacter(hairStyleID: $0) } preview: { option in
                    AvatarView(look: AvatarLook(skinToneID: look.skinToneID, hairStyleID: option.id, hairColorID: look.hairColorID, outfitID: look.outfitID), size: 44)
                        .frame(height: 50)
                }
                optionRow(loc("Hair color", "Saç rengi"), options: store.hairColors, selected: store.characterProfile.hairColorID) { store.updateCharacter(hairColorID: $0) } preview: { option in
                    Circle().fill(AvatarLook(hairColorID: option.id).hair)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .frame(height: 50)
                }
                optionRow(loc("Skin tone", "Ten rengi"), options: store.skinTones, selected: store.characterProfile.skinToneID) { store.updateCharacter(skinToneID: $0) } preview: { option in
                    Circle().fill(AvatarLook(skinToneID: option.id).skin)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .frame(height: 50)
                }
                optionRow(loc("Accessory", "Aksesuar"), options: store.accessories, selected: store.characterProfile.accessoryID) { store.updateCharacter(accessoryID: $0) } preview: { option in
                    Image(systemName: option.icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.lavender.gradient)
                        .frame(height: 50)
                }
            }
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { name = store.characterProfile.name }
    }

    private func saveName() {
        store.updateCharacter(name: name)
        name = store.characterProfile.name
        nameFocused = false
        Feedback.play(.tap, settings: store.playerSettings)
    }

    private func optionRow<Preview: View>(_ title: String, options: [CharacterOption], selected: String,
                                          action: @escaping (String) -> Void,
                                          @ViewBuilder preview: @escaping (CharacterOption) -> Preview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options) { item in
                        Button {
                            action(item.id)
                            Feedback.play(.tap, settings: store.playerSettings)
                        } label: {
                            VStack(spacing: 4) {
                                preview(item)
                                Text(trName(item.name)).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(width: 88, height: 84)
                        }
                        .buttonStyle(TileButtonStyle(selected: selected == item.id))
                        .accessibilityLabel("\(title): \(trName(item.name))")
                        .accessibilityAddTraits(selected == item.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal).padding(.vertical, 4)
            }
        }
    }
}
