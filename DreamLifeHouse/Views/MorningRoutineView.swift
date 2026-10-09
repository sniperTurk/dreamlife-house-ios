import SwiftUI

// MARK: - Start card (House and Adventures)

/// Shows today's morning routine and opens it full screen.
struct RoutineLauncherCard: View {
    @EnvironmentObject var store: GameStore
    var showWhenDone = false
    @State private var open = false

    private var detail: String {
        let name = store.characterProfile.name
        switch store.routine.step {
        case 0: return loc("\(name) just woke up. Say good morning!", "\(name) uyandı. Ona günaydın de!")
        case 1: return loc("Help \(name) out of pajamas and into sportswear.", "\(name) pijamalarını çıkarıp spor giyinmek istiyor.")
        case 2: return loc("\(name) is hungry. Make breakfast!", "\(name) acıktı. Kahvaltı hazırla!")
        case 3: return loc("Pick fruit and feed the animals in the garden.", "Bahçede meyve topla ve hayvanları besle.")
        default: return loc("All done today. Come back tomorrow morning!", "Bugünkü rutin tamam. Yarın sabah görüşürüz!")
        }
    }

    var body: some View {
        // The cover is attached outside the condition so finishing the routine
        // (which hides the House card) does not close the screen mid-celebration.
        VStack(spacing: 0) { card }
            .fullScreenCover(isPresented: $open) { MorningRoutineView().environmentObject(store) }
    }

    @ViewBuilder private var card: some View {
        if !store.isRoutineDone || showWhenDone {
            QuestCard(icon: store.isRoutineDone ? "checkmark" : "sun.max.fill", tint: store.isRoutineDone ? Theme.mint : Theme.sun,
                      title: loc("Morning routine", "Sabah rutini") + "  " + RoutineSteps.emojis.enumerated().map { $0.offset < store.routine.step ? "✅" : $0.element }.joined(),
                      detail: detail) {
                Button(store.routine.step == 0 ? loc("Start", "Başla") : (store.isRoutineDone ? loc("Garden", "Bahçe") : loc("Continue", "Devam"))) {
                    open = true
                    Feedback.play(.tap, settings: store.playerSettings)
                }
                .buttonStyle(PillButtonStyle(color: Theme.sun))
                .accessibilityIdentifier("routine.start")
            }
            .padding(.horizontal)
        }
    }
}

enum RoutineSteps {
    static let emojis = ["☀️", "👕", "🍳", "🌳"]
}

// MARK: - Morning routine

struct MorningRoutineView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var bubbleMain = ""
    @State private var bubbleSub = ""
    @State private var eating = false
    @State private var chewing: String?
    @State private var inGarden = false
    @State private var sparkle = false

    private var step: Int { store.routine.step }
    private var look: AvatarLook {
        AvatarLook(profile: store.characterProfile, outfitID: step <= 1 ? "pajamas" : store.selectedOutfitID)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 8) {
                header
                if inGarden {
                    GardenFarmView(standalone: false, onFinish: { dismiss() })
                } else {
                    scene
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal)
                    if step == 1 || step == 2 { tray }
                    actionButton
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear(perform: start)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.weight(.black)).foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.9)))
            }
            .accessibilityLabel(loc("Close", "Kapat"))
            .accessibilityIdentifier("routine.close")
            Text(loc("Morning routine", "Sabah rutini"))
                .font(.title3.weight(.black)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(Array(RoutineSteps.emojis.enumerated()), id: \.offset) { index, emoji in
                    Text(index < step ? "✅" : emoji)
                        .font(.system(size: 20))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(index == min(step, 3) ? Theme.sun.opacity(0.35) : Color.white.opacity(0.8)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(loc("Step \(min(step + 1, 4)) of 4", "Adım \(min(step + 1, 4)) / 4"))
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: Scene

    private var scene: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let avatarSize = min(h * 0.5, w * 0.36, 190)
            let center = CGPoint(x: w * (step == 2 ? 0.3 : 0.45), y: h * 0.6)
            ZStack {
                RoomBackdrop(roomID: step <= 1 ? "bedroom" : "kitchen")
                if step == 2 || (step == 3 && !inGarden) { breakfastTable(w: w, h: h) }
                ZStack {
                    AvatarView(look: look, size: avatarSize)
                    if step == 1 { wornClothes(size: avatarSize) }
                    if sparkle {
                        Text("✨").font(.system(size: avatarSize * 0.3)).offset(x: avatarSize * 0.4, y: -avatarSize * 0.4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(chewing != nil && !store.playerSettings.reducedMotion ? 1.05 : 1)
                .animation(.spring(duration: 0.3), value: chewing)
                .position(center)
                if !bubbleMain.isEmpty {
                    RoutineBubble(main: bubbleMain, sub: bubbleSub)
                        .frame(maxWidth: w * 0.8)
                        .position(x: w * 0.5, y: max(34, center.y - avatarSize * 0.85))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .id(bubbleMain)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white, lineWidth: 4))
        .shadow(color: Theme.lavender.opacity(0.25), radius: 12, y: 6)
        .animation(store.motionAnimationDuration == 0 ? nil : .spring(duration: 0.35), value: bubbleMain)
    }

    /// Emoji clothes appear on the character as they are put on.
    private func wornClothes(size: CGFloat) -> some View {
        let u = size / 100
        let spots: [String: CGSize] = [
            "cap": CGSize(width: 0, height: -58 * u), "tshirt": CGSize(width: 0, height: 26 * u),
            "shorts": CGSize(width: 0, height: 44 * u), "socks": CGSize(width: -14 * u, height: 56 * u),
            "sneakers": CGSize(width: 14 * u, height: 60 * u)
        ]
        return ZStack {
            ForEach(store.routineClothes.filter { store.routine.worn.contains($0.id) }) { item in
                Text(item.emoji)
                    .font(.system(size: (item.id == "tshirt" ? 40 : 26) * u))
                    .offset(spots[item.id] ?? .zero)
                    .transition(.scale(scale: 2.5).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: store.routine.worn)
    }

    private func breakfastTable(w: CGFloat, h: CGFloat) -> some View {
        let tableW = min(w * 0.42, 260)
        return ZStack {
            // Table
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xC48A5A).gradient).frame(width: tableW, height: 14)
                HStack { Rectangle().fill(Color(hex: 0xA8724A)).frame(width: 10); Spacer(); Rectangle().fill(Color(hex: 0xA8724A)).frame(width: 10) }
                    .frame(width: tableW * 0.85, height: h * 0.22)
            }
            .position(x: w * 0.7, y: h * 0.72 + h * 0.11)
            // Plate with food
            ZStack {
                Ellipse().fill(Color.white).overlay(Ellipse().strokeBorder(Theme.pink, lineWidth: 3))
                    .frame(width: tableW * 0.8, height: 38)
                HStack(spacing: -4) {
                    ForEach(store.routine.plate, id: \.self) { id in
                        let food = store.breakfastFoods.first { $0.id == id }
                        Button {
                            if !eating, store.removeFromBreakfastPlate(id) { Feedback.play(.tap, settings: store.playerSettings) }
                        } label: {
                            Text(food?.emoji ?? "")
                                .font(.system(size: min(34, tableW * 0.14)))
                                .scaleEffect(chewing == id ? 1.5 : 1)
                                .opacity(chewing == id ? 0.6 : 1)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                        .accessibilityLabel(loc("\(food?.name ?? id) on the plate", "Tabakta \(food?.nameTR ?? id)"))
                    }
                }
                .offset(y: -12)
            }
            .position(x: w * 0.7, y: h * 0.72 - 6)
            .animation(.spring(duration: 0.35, bounce: 0.35), value: store.routine.plate)
            .animation(.easeInOut(duration: 0.3), value: chewing)
        }
    }

    // MARK: Tray and actions

    private var trayItems: [RoutineThing] { step == 1 ? store.routineClothes : store.breakfastFoods }

    private var tray: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step == 1 ? loc("Tap a piece of clothing to put it on", "Giydirmek için bir kıyafete dokun")
                           : loc("Tap food to put it on the plate (up to 5)", "Tabağa koymak için yiyeceğe dokun (en fazla 5)"))
                .font(.caption.weight(.bold)).foregroundStyle(Theme.inkSoft)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(trayItems) { item in
                        let used = step == 1 ? store.routine.worn.contains(item.id) : store.routine.plate.contains(item.id)
                        Button { tapTray(item) } label: {
                            VStack(spacing: 2) {
                                Text(item.emoji).font(.system(size: 38))
                                Text(item.nameTR).font(.caption.weight(.heavy)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                                Text(item.name).font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(width: 84, height: 92)
                            .opacity(used ? 0.45 : 1)
                            .overlay(alignment: .topTrailing) {
                                if used { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint).padding(5) }
                            }
                        }
                        .buttonStyle(TileButtonStyle(selected: used, tint: step == 1 ? Theme.sky : Theme.peach))
                        .disabled(eating || (step == 1 && used))
                        .accessibilityIdentifier("routine.item.\(item.id)")
                        .accessibilityLabel(loc("\(item.name)", "\(item.nameTR)"))
                    }
                }
                .padding(.horizontal).padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder private var actionButton: some View {
        switch step {
        case 0:
            Button(loc("👋 Good morning!", "👋 Günaydın!")) { goodMorning() }
                .buttonStyle(CandyButtonStyle(color: Theme.sun))
                .padding(.horizontal)
                .accessibilityIdentifier("routine.goodMorning")
        case 2:
            Button(loc("🍽️ Breakfast is ready!", "🍽️ Kahvaltı hazır!")) { eatBreakfast() }
                .buttonStyle(CandyButtonStyle(color: Theme.peach))
                .disabled(store.routine.plate.isEmpty || eating)
                .opacity(store.routine.plate.isEmpty || eating ? 0.6 : 1)
                .padding(.horizontal)
                .accessibilityIdentifier("routine.eat")
        case 3, 4:
            Button(loc("🌳 Go to the garden!", "🌳 Bahçeye çık!")) {
                withAnimation(.easeInOut(duration: 0.35)) { inGarden = true }
            }
            .buttonStyle(CandyButtonStyle(color: Theme.mint))
            .padding(.horizontal)
            .accessibilityIdentifier("routine.garden")
        default:
            EmptyView()
        }
    }

    // MARK: Story beats

    private func say(_ main: String, _ sub: String, speak parts: [(String, String)]) {
        bubbleMain = main; bubbleSub = sub
        Speaker.shared.say(parts, settings: store.playerSettings)
    }

    private func sayLine(tr: String, en: String) {
        say(L10n.isTurkish ? tr : en, L10n.isTurkish ? en : tr,
            speak: L10n.isTurkish ? [(tr, "tr-TR"), (en, "en-US")] : [(en, "en-US"), (tr, "tr-TR")])
    }

    private func start() {
        if step >= 3 && store.isRoutineDone { inGarden = true; return }
        switch step {
        case 0: sayLine(tr: "Günaydın! ☀️", en: "Good morning! ☀️")
        case 1: askToDress()
        case 2: sayLine(tr: "Acıktım! 🍽️", en: "I'm hungry! 🍽️")
        default: sayLine(tr: "Doydum! Hadi bahçeye çıkalım!", en: "I'm full! Let's go to the garden!")
        }
    }

    private func askToDress() {
        sayLine(tr: "Pijamalarımı çıkar! Bugün spor giyinmek istiyorum.", en: "Take off my pajamas! I want to wear sportswear today.")
    }

    private func goodMorning() {
        guard store.sayGoodMorning() else { return }
        Feedback.play(.success, settings: store.playerSettings)
        askToDress()
    }

    private func tapTray(_ item: RoutineThing) {
        if step == 1 {
            guard store.wearRoutineClothing(item.id) else { return }
            Feedback.play(.tap, settings: store.playerSettings)
            if store.routine.step == 2 {
                withAnimation(.spring(duration: 0.4)) { sparkle = true }
                Feedback.play(.success, settings: store.playerSettings)
                sayLine(tr: "\(item.nameTR)! Hazırım! Şimdi acıktım! 🍽️", en: "\(item.name)! I'm ready! Now I'm hungry! 🍽️")
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { sparkle = false }
                }
            } else {
                say("\(item.emoji) \(L10n.isTurkish ? item.nameTR : item.name)!", L10n.isTurkish ? item.name : item.nameTR,
                    speak: L10n.isTurkish ? [(item.nameTR, "tr-TR"), (item.name, "en-US")] : [(item.name, "en-US"), (item.nameTR, "tr-TR")])
            }
        } else if step == 2 {
            if store.routine.plate.contains(item.id) {
                _ = store.removeFromBreakfastPlate(item.id)
            } else if store.addToBreakfastPlate(item.id) {
                Feedback.play(.tap, settings: store.playerSettings)
                say("\(item.emoji) \(L10n.isTurkish ? item.nameTR : item.name)", L10n.isTurkish ? item.name : item.nameTR,
                    speak: L10n.isTurkish ? [(item.nameTR, "tr-TR"), (item.name, "en-US")] : [(item.name, "en-US"), (item.nameTR, "tr-TR")])
            } else {
                Feedback.play(.warning, settings: store.playerSettings)
            }
        }
    }

    /// The character eats everything on the plate one by one, naming each
    /// food in English.
    private func eatBreakfast() {
        guard !eating, !store.routine.plate.isEmpty else { return }
        eating = true
        Task { @MainActor in
            for id in store.routine.plate {
                guard let food = store.breakfastFoods.first(where: { $0.id == id }) else { continue }
                chewing = id
                say("😋 \(food.name)! \(food.emoji)", food.nameTR, speak: [("\(food.name)! Yummy!", "en-US")])
                try? await Task.sleep(for: .seconds(1.8))
                _ = store.eatFromPlate(id)
                chewing = nil
                try? await Task.sleep(for: .seconds(0.25))
            }
            eating = false
            Feedback.play(.success, settings: store.playerSettings)
            sayLine(tr: "Doydum! Hadi bahçeye çıkalım! 🌳", en: "I'm full! Let's go to the garden! 🌳")
        }
    }
}

/// Two-line speech bubble: what the character says, and the other language below.
struct RoutineBubble: View {
    let main: String
    let sub: String
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(main)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(3).minimumScaleFactor(0.7)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.pink.opacity(0.55), lineWidth: 2))
            TriangleShape().fill(Color.white).frame(width: 14, height: 8).rotationEffect(.degrees(180))
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sub.isEmpty ? main : "\(main), \(sub)")
        .accessibilityIdentifier("routine.bubble")
    }
}

// MARK: - Garden farm

/// Fruit trees to pick from and farm animals to feed. Fruit and animal names
/// are spoken in English. Used as the routine's last step and from the Garden.
struct GardenFarmView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var standalone = true
    var onFinish: (() -> Void)? = nil
    @State private var selectedFood = "corn"
    @State private var bubbleMain = ""
    @State private var bubbleSub = ""
    @State private var happyAnimal: String?
    @State private var shakingAnimal: String?

    private var feedChoices: [RoutineThing] {
        store.animalFoods + store.fruits.filter { store.fruitBasket[$0.id, default: 0] > 0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            if standalone {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline.weight(.black)).foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.9)))
                    }
                    .accessibilityLabel(loc("Close", "Kapat"))
                    Text(loc("Farm garden", "Çiftlik bahçesi")).font(.title3.weight(.black)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal).padding(.top, 6)
            }
            talkStrip
            scene
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
            if store.routine.step == 3 || store.isRoutineDone { goalRow }
            feedTray
        }
        .background(standalone ? AnyView(AppBackground()) : AnyView(Color.clear))
        .onAppear {
            if bubbleMain.isEmpty {
                say(loc("Let's pick fruit and feed the animals!", "Hadi meyve toplayalım ve hayvanları besleyelim!"), "",
                    speak: [(L10n.isTurkish ? "Hadi meyve toplayalım ve hayvanları besleyelim!" : "Let's pick fruit and feed the animals!", L10n.isTurkish ? "tr-TR" : "en-US")])
            }
        }
    }

    private var talkStrip: some View {
        HStack(spacing: 8) {
            AvatarView(look: AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID), size: 44)
                .frame(width: 48, height: 56)
            VStack(alignment: .leading, spacing: 1) {
                Text(bubbleMain).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(Theme.ink)
                if !bubbleSub.isEmpty { Text(bubbleSub).font(.caption.weight(.bold)).foregroundStyle(Theme.inkSoft) }
            }
            .lineLimit(2).minimumScaleFactor(0.7)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("farm.bubble")
            basket
        }
        .padding(.horizontal)
        .animation(.spring(duration: 0.3), value: bubbleMain)
    }

    private var basket: some View {
        VStack(spacing: 0) {
            Text("🧺").font(.system(size: 26))
            HStack(spacing: 2) {
                ForEach(store.fruits.filter { store.fruitBasket[$0.id, default: 0] > 0 }) { fruit in
                    Text("\(fruit.emoji)\(store.fruitBasket[fruit.id, default: 0])").font(.system(size: 11, weight: .heavy))
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.85)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc("Basket", "Sepet") + ": " + store.fruits.map { "\($0.name) \(store.fruitBasket[$0.id, default: 0])" }.joined(separator: ", "))
    }

    private var scene: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let canopy = min(w * 0.2, h * 0.34)
            ZStack {
                LinearGradient(colors: [Color(hex: 0x9ED8FF), Color(hex: 0xE3F5FF)], startPoint: .top, endPoint: .bottom)
                Image(systemName: "sun.max.fill").font(.system(size: h * 0.1)).foregroundStyle(Theme.sun).position(x: w * 0.94, y: h * 0.08)
                Rectangle().fill(LinearGradient(colors: [Color(hex: 0x8DD982), Color(hex: 0x5BBF5B)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.5).position(x: w / 2, y: h * 0.75)
                HStack(spacing: 6) {
                    ForEach(0..<18, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 7, height: h * 0.08) }
                }
                .position(x: w / 2, y: h * 0.5)
                ForEach(Array(store.fruits.enumerated()), id: \.element.id) { index, fruit in
                    tree(fruit, canopy: canopy).position(x: w * (0.13 + CGFloat(index) * 0.245), y: h * 0.3)
                }
                ForEach(Array(store.farmAnimals.enumerated()), id: \.element.id) { index, animal in
                    animalView(animal, size: min(h * 0.17, w * 0.11))
                        .position(x: w * (0.1 + CGFloat(index) * 0.16), y: h * (index % 2 == 0 ? 0.68 : 0.86))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white, lineWidth: 4))
        .shadow(color: Theme.mint.opacity(0.25), radius: 12, y: 6)
    }

    private func tree(_ fruit: RoutineThing, canopy: CGFloat) -> some View {
        let left = store.fruitsLeft(on: fruit.id)
        let spots: [CGSize] = [CGSize(width: -0.24, height: -0.08), CGSize(width: 0.22, height: 0.02), CGSize(width: -0.02, height: 0.24)]
        return ZStack {
            Capsule().fill(Color(hex: 0x9B6A43)).frame(width: canopy * 0.16, height: canopy * 0.75).offset(y: canopy * 0.55)
            Circle().fill(Color(hex: 0x4CAF50)).frame(width: canopy * 0.7).offset(x: -canopy * 0.2, y: canopy * 0.06)
            Circle().fill(Color(hex: 0x43A047)).frame(width: canopy * 0.7).offset(x: canopy * 0.2, y: canopy * 0.08)
            Circle().fill(Color(hex: 0x66BB6A)).frame(width: canopy * 0.78).offset(y: -canopy * 0.12)
            ForEach(0..<left, id: \.self) { i in
                Button { pick(fruit) } label: {
                    Text(fruit.emoji).font(.system(size: canopy * 0.26))
                }
                .buttonStyle(.plain)
                .offset(x: spots[i].width * canopy, y: spots[i].height * canopy)
                .transition(.asymmetric(insertion: .scale, removal: .move(edge: .bottom).combined(with: .opacity)))
                .accessibilityLabel(loc("Pick \(fruit.name)", "\(fruit.nameTR) topla"))
                .accessibilityIdentifier("farm.fruit.\(fruit.id)")
            }
            Text(fruit.name)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.9)))
                .offset(y: canopy * 0.95)
        }
        .animation(.spring(duration: 0.4), value: left)
    }

    private func animalView(_ animal: RoutineThing, size: CGFloat) -> some View {
        let happy = happyAnimal == animal.id
        let fed = store.routine.fed.contains(animal.id)
        return Button { feed(animal) } label: {
            VStack(spacing: 0) {
                Text(happy ? "❤️" : (fed ? "💚" : " ")).font(.system(size: size * 0.35))
                Text(animal.emoji).font(.system(size: size))
                    .scaleEffect(happy && !store.playerSettings.reducedMotion ? 1.2 : 1)
                    .rotationEffect(.degrees(shakingAnimal == animal.id ? 12 : 0))
                Text(animal.name)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3, bounce: 0.5), value: happyAnimal)
        .animation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true), value: shakingAnimal)
        .accessibilityLabel(loc("Feed the \(animal.name)", "\(animal.nameTR) besle"))
        .accessibilityIdentifier("farm.animal.\(animal.id)")
    }

    private var goalRow: some View {
        let picked = min(store.routinePickedCount, store.routineGardenGoal.fruits)
        let fed = min(store.routine.fed.count, store.routineGardenGoal.animals)
        return HStack(spacing: 10) {
            if store.isRoutineDone {
                Text(loc("🎉 Great morning! +40 coins · +2 stars", "🎉 Harika bir sabah! +40 jeton · +2 yıldız"))
                    .font(.subheadline.weight(.heavy)).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if let onFinish {
                    Button(loc("Done", "Bitti")) { onFinish() }
                        .buttonStyle(PillButtonStyle(color: Theme.mint))
                        .accessibilityIdentifier("routine.finish")
                }
            } else {
                Label(loc("Fruit \(picked)/\(store.routineGardenGoal.fruits)", "Meyve \(picked)/\(store.routineGardenGoal.fruits)"), systemImage: "basket.fill")
                Label(loc("Animals fed \(fed)/\(store.routineGardenGoal.animals)", "Beslenen \(fed)/\(store.routineGardenGoal.animals)"), systemImage: "pawprint.fill")
                Spacer(minLength: 0)
            }
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(Theme.ink)
        .padding(10)
        .dreamCard(cornerRadius: 16)
        .padding(.horizontal)
    }

    private var feedTray: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc("Pick food, then tap an animal", "Bir yem seç, sonra hayvana dokun"))
                .font(.caption.weight(.bold)).foregroundStyle(Theme.inkSoft)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(feedChoices) { food in
                        let selected = selectedFood == food.id
                        let count = store.fruitBasket[food.id]
                        Button {
                            selectedFood = food.id
                            Feedback.play(.tap, settings: store.playerSettings)
                            say("\(food.emoji) \(food.name)", food.nameTR, speak: [(food.name, "en-US")])
                        } label: {
                            VStack(spacing: 1) {
                                Text(food.emoji).font(.system(size: 32))
                                Text(food.name).font(.caption.weight(.heavy)).foregroundStyle(Theme.ink)
                                Text(count.map { "\(food.nameTR) ×\($0)" } ?? food.nameTR).font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                            }
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: 80, height: 80)
                        }
                        .buttonStyle(TileButtonStyle(selected: selected, tint: Theme.mint))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("farm.food.\(food.id)")
                    }
                }
                .padding(.horizontal).padding(.vertical, 4)
            }
        }
        .onChange(of: feedChoices.map(\.id)) { _, ids in
            if !ids.contains(selectedFood) { selectedFood = "corn" }
        }
    }

    private func say(_ main: String, _ sub: String, speak parts: [(String, String)]) {
        bubbleMain = main; bubbleSub = sub
        Speaker.shared.say(parts, settings: store.playerSettings)
    }

    private func pick(_ fruit: RoutineThing) {
        guard store.pickFruit(fruit.id) else { return }
        Feedback.play(.success, settings: store.playerSettings)
        say("\(fruit.emoji) \(fruit.name)!", fruit.nameTR, speak: [("\(fruit.name)!", "en-US")])
        celebrateIfDone()
    }

    private func feed(_ animal: RoutineThing) {
        let wasDone = store.isRoutineDone
        switch store.feedAnimal(animal.id, with: selectedFood) {
        case .happy:
            Feedback.play(.success, settings: store.playerSettings)
            happyAnimal = animal.id
            say("\(animal.emoji) \(animal.name)!", animal.nameTR, speak: [("\(animal.name)!", "en-US")])
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                if happyAnimal == animal.id { happyAnimal = nil }
            }
            if !wasDone { celebrateIfDone() }
        case .wrongFood:
            Feedback.play(.warning, settings: store.playerSettings)
            shakingAnimal = animal.id
            let likes = store.animalLikes(animal.id).map(\.emoji).joined(separator: " ")
            say(loc("\(animal.emoji) \(animal.name) wants \(likes)", "\(animal.emoji) \(animal.nameTR) \(likes) istiyor"), animal.name,
                speak: [("\(animal.name)!", "en-US")])
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                shakingAnimal = nil
            }
        case .noFruit:
            say(loc("Pick some fruit from the trees first!", "Önce ağaçtan meyve topla!"), "", speak: [])
        case .unknown:
            break
        }
    }

    private func celebrateIfDone() {
        guard store.isRoutineDone else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            say(loc("🎉 What a great morning!", "🎉 Harika bir sabah!"), loc("Harika bir sabah!", "What a great morning!"),
                speak: L10n.isTurkish ? [("Harika bir sabah!", "tr-TR"), ("What a great morning!", "en-US")] : [("What a great morning!", "en-US"), ("Harika bir sabah!", "tr-TR")])
        }
    }
}
