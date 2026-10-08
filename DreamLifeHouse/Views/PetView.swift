import SwiftUI

struct PetView: View {
    @EnvironmentObject var store: GameStore
    @State private var petName = ""
    @State private var reaction = 0
    @State private var message = loc("Take good care of your pet!", "Evcil hayvanına iyi bak!")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white, Theme.peachSoft], center: .center, startRadius: 10, endRadius: 120))
                        .frame(width: 200, height: 200)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 6))
                        .shadow(color: Theme.peach.opacity(0.25), radius: 14, y: 8)
                    PetPortrait(species: store.petProfile.species, size: 150)
                        .scaleEffect(reaction % 2 == 1 && !store.playerSettings.reducedMotion ? 1.06 : 1)
                        .animation(store.motionAnimationDuration == 0 ? nil : .spring(duration: 0.3), value: reaction)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(loc("\(store.petProfile.name) the \(store.petProfile.species)", "\(store.petProfile.name) (\(trName(store.petProfile.species)))"))

                VStack(spacing: 2) {
                    Text(store.petProfile.name).font(.title2.weight(.black)).foregroundStyle(Theme.ink)
                    Text(message).font(.subheadline).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    NeedMeter(name: loc("Full", "Tok"), icon: "fork.knife", value: store.petNeeds.hunger, tint: Theme.mint)
                    NeedMeter(name: loc("Happy", "Mutlu"), icon: "heart.fill", value: store.petNeeds.happiness, tint: Theme.pink)
                    NeedMeter(name: loc("Energy", "Enerji"), icon: "bolt.fill", value: store.petNeeds.energy, tint: Theme.sun)
                }
                .padding(12)
                .dreamCard(cornerRadius: 20)
                .padding(.horizontal)

                HStack(spacing: 10) {
                    careButton(loc("Feed", "Besle"), icon: "fork.knife", tint: Theme.mint, action: "feed", text: loc("Yum! \(store.petProfile.name) is full.", "Nefis! \(store.petProfile.name) doydu."))
                    careButton(loc("Play", "Oyna"), icon: "tennisball.fill", tint: Theme.pink, action: "play", text: loc("\(store.petProfile.name) loves playing with you!", "\(store.petProfile.name) seninle oynamayı çok seviyor!"))
                    careButton(loc("Rest", "Dinlen"), icon: "moon.zzz.fill", tint: Theme.lavender, action: "rest", text: loc("\(store.petProfile.name) had a cozy nap.", "\(store.petProfile.name) güzel bir şekerleme yaptı."))
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: loc("Pet profile", "Evcil hayvan profili"), icon: "pawprint.fill")
                    Picker(loc("Pet", "Evcil hayvan"), selection: Binding(get: { store.petProfile.species }, set: { store.updatePet(species: $0) })) {
                        Text(loc("Cat", "Kedi")).tag("cat"); Text(loc("Dog", "Köpek")).tag("dog")
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 8) {
                        TextField(loc("Pet name", "Evcil hayvan adı"), text: $petName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                        Button(loc("Save name", "Adı kaydet")) { saveName() }
                            .buttonStyle(PillButtonStyle(color: Theme.peach))
                            .disabled(petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(14)
                .dreamCard()
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: loc("Follow to room", "Odaya götür"), icon: "house.fill")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(store.rooms) { room in
                            let here = store.petProfile.roomID == room.id
                            Button {
                                if store.movePet(to: room.id) {
                                    message = loc("\(store.petProfile.name) followed you to the \(room.name).", "\(store.petProfile.name) seninle geldi: \(trName(room.name)).")
                                    Feedback.play(.tap, settings: store.playerSettings)
                                }
                            } label: {
                                Label(trName(room.name), systemImage: room.icon)
                                    .font(.caption.weight(.heavy))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }
                            .buttonStyle(TileButtonStyle(selected: here, tint: Theme.roomTint(room.id)))
                            .accessibilityAddTraits(here ? .isSelected : [])
                        }
                    }
                }
                .padding(14)
                .dreamCard()
                .padding(.horizontal)
            }
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func careButton(_ title: String, icon: String, tint: Color, action: String, text: String) -> some View {
        Button {
            if store.careForPet(action) {
                reaction += 1
                message = text
                Feedback.play(.success, settings: store.playerSettings)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3.weight(.bold))
                Text(title).font(.caption.weight(.heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tint.gradient))
            .shadow(color: tint.opacity(0.3), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func saveName() {
        store.updatePet(name: petName)
        petName = ""
        Feedback.play(.tap, settings: store.playerSettings)
    }
}
