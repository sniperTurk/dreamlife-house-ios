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
        AdventureTask(id:"outfit", title:"Create a party outfit", detail:"Unlock and wear the Party outfit.", icon:"sparkles", reward:60, isReady:{ $0.selectedOutfitID == "party" }),
        AdventureTask(id:"decorate", title:"Decorate a room", detail:"Place any decoration besides the starter sofa.", icon:"sofa.fill", reward:80, isReady:{ $0.hasPlacedAdventureDecoration }),
        AdventureTask(id:"cupcake", title:"Bake a cupcake", detail:"Finish the Rainbow Cupcake recipe.", icon:"birthday.cake.fill", reward:100, isReady:{ $0.cookedRecipes.contains("Rainbow Cupcake") }),
        AdventureTask(id:"dance", title:"Dance challenge", detail:"Dance in the living room three times.", icon:"music.note", reward:120, isReady:{ $0.interactionCount("dance", in:"living") >= 3 })
    ]}

    private let tints: [String: Color] = ["outfit": Theme.lavender, "decorate": Theme.peach, "cupcake": Theme.pink, "dance": Theme.sky]

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("House Adventures")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                    Text("Complete each house challenge once and earn rewards.")
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
                                Label("Reward: \(task.reward) coins", systemImage: "circle.hexagongrid.fill")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Button(done ? "Done" : (ready ? "Claim" : "Locked")) {
                                    if store.claimAdventureTask(task.id) {
                                        Feedback.play(.success, settings: store.playerSettings)
                                    }
                                }
                                .buttonStyle(PillButtonStyle(color: ready && !done ? tint : Theme.mint))
                                .disabled(done || !ready)
                                .accessibilityIdentifier("adventures.claim.\(task.id)")
                                .accessibilityLabel(done ? "\(task.title) reward claimed"
                                    : (ready ? "Claim \(task.title) reward" : "\(task.title) reward locked"))
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
                    Text("Day \(store.dailyLifeProgress.day) • \(store.dayPhase)")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text(complete ? "Daily chain complete!" : store.dailyChainDetail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Label("\(store.dailyLifeProgress.streak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.peach)
                    .accessibilityLabel("Streak: \(store.dailyLifeProgress.streak) days")
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(complete || i < store.dailyLifeProgress.chainStep ? AnyShapeStyle(Theme.mint.gradient) : AnyShapeStyle(Theme.mint.opacity(0.18)))
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            Text("Streak: \(store.dailyLifeProgress.streak) days")
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
        case 0: return "Go to Afternoon"
        case 1: return "Go to Evening"
        default: return "Sleep until Day \(store.dailyLifeProgress.day + 1)"
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
