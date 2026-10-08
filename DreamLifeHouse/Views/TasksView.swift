import SwiftUI

struct AdventureTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let reward: Int
    let isReady: (GameStore) -> Bool
}

struct TasksView: View {
    @EnvironmentObject var store: GameStore

    private var tasks: [AdventureTask] {[
        AdventureTask(id:"outfit", title:loc("Create a party outfit", "Parti kıyafeti hazırla"), detail:loc("Unlock and wear the Party outfit.", "Parti kıyafetini aç ve giy."), icon:"sparkles", reward:60, isReady:{ $0.selectedOutfitID == "party" }),
        AdventureTask(id:"decorate", title:loc("Decorate a room", "Bir odayı dekore et"), detail:loc("Place any decoration besides the starter sofa.", "Başlangıç kanepesi dışında bir dekorasyon yerleştir."), icon:"sofa.fill", reward:80, isReady:{ $0.hasPlacedAdventureDecoration }),
        AdventureTask(id:"cupcake", title:loc("Bake a cupcake", "Kek pişir"), detail:loc("Finish the Rainbow Cupcake recipe.", "Gökkuşağı Keki tarifini tamamla."), icon:"birthday.cake.fill", reward:100, isReady:{ $0.cookedRecipes.contains("Rainbow Cupcake") }),
        AdventureTask(id:"dance", title:loc("Dance challenge", "Dans görevi"), detail:loc("Dance in the living room three times.", "Oturma odasında üç kez dans et."), icon:"music.note", reward:120, isReady:{ $0.interactionCount("dance", in:"living") >= 3 })
    ]}

    private let tints: [String: Color] = ["outfit": Theme.lavender, "decorate": Theme.peach, "cupcake": Theme.pink, "dance": Theme.sky]

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(loc("House Adventures", "Ev Maceraları"))
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                    Text(loc("Complete each house challenge once and earn rewards.", "Her ev görevini bir kez tamamla ve ödül kazan."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)

                    dayCard

                    ForEach(tasks) { task in
                        let done = store.completedTasks.contains(task.id)
                        let ready = task.isReady(store)
                        let tint = tints[task.id] ?? Theme.pink
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                IconBadge(icon: done ? "checkmark" : task.icon, tint: done ? Theme.mint : tint, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(Theme.ink)
                                    Text(task.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            HStack {
                                Label(loc("Reward: \(task.reward) coins", "Ödül: \(task.reward) jeton"), systemImage: "circle.hexagongrid.fill")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Button(done ? loc("Done", "Tamam") : (ready ? loc("Claim", "Al") : loc("Locked", "Kilitli"))) {
                                    if store.claimAdventureTask(task.id) {
                                        Feedback.play(.success, settings: store.playerSettings)
                                    }
                                }
                                .buttonStyle(PillButtonStyle(color: ready && !done ? tint : Theme.mint))
                                .disabled(done || !ready)
                                .accessibilityIdentifier("adventures.claim.\(task.id)")
                                .accessibilityLabel(done ? loc("\(task.title) reward claimed", "\(task.title) ödülü alındı")
                                    : (ready ? loc("Claim \(task.title) reward", "\(task.title) ödülünü al") : loc("\(task.title) reward locked", "\(task.title) ödülü kilitli")))
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dreamCard()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .accessibilityIdentifier("adventures.scrollContent")
        }
        .background(AppBackground())
    }

    private var dayCard: some View {
        let complete = store.dailyLifeProgress.lastCompletedDay == store.dailyLifeProgress.day
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(icon: phaseIcon, tint: Theme.sun, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("Day \(store.dailyLifeProgress.day) • \(store.dayPhase)", "\(store.dailyLifeProgress.day). Gün • \(trName(store.dayPhase))"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text(complete ? loc("Daily chain complete!", "Günlük zincir tamamlandı!") : trName(store.dailyChainDetail))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Label("\(store.dailyLifeProgress.streak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.peach)
                    .accessibilityLabel(loc("Streak: \(store.dailyLifeProgress.streak) days", "Seri: \(store.dailyLifeProgress.streak) gün"))
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(complete || i < store.dailyLifeProgress.chainStep ? AnyShapeStyle(Theme.mint.gradient) : AnyShapeStyle(Theme.mint.opacity(0.18)))
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            Text(loc("Streak: \(store.dailyLifeProgress.streak) days", "Seri: \(store.dailyLifeProgress.streak) gün"))
                .font(.caption.bold())
                .foregroundStyle(Theme.inkSoft)
            // v2.56: the button used to read "Next Morning" while it was already morning.
            Button(nextPhaseLabel) {
                _ = store.advanceDayPhase()
                Feedback.play(.tap, settings: store.playerSettings)
            }
            .buttonStyle(PillButtonStyle(color: Theme.sun))
            .accessibilityIdentifier("adventures.nextPhase")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dreamCard()
    }

    private var nextPhaseLabel: String {
        switch store.dailyLifeProgress.phaseIndex {
        case 0: return loc("Go to Afternoon", "Öğleden sonraya geç")
        case 1: return loc("Go to Evening", "Akşama geç")
        default: return loc("Sleep until Day \(store.dailyLifeProgress.day + 1)", "\(store.dailyLifeProgress.day + 1). güne kadar uyu")
        }
    }

    private var phaseIcon: String {
        switch store.dailyLifeProgress.phaseIndex {
        case 1: return "sun.max.fill"
        case 2: return "moon.stars.fill"
        default: return "sunrise.fill"
        }
    }
}
