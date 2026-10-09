import SwiftUI

@main
struct DreamLifeHouseApp: App {
    @StateObject private var store: GameStore

    init() {
        #if DEBUG
        // Dedicated UI-test save domain. Never reset or inject production saves.
        let arguments = ProcessInfo.processInfo.arguments
        let testFlags = ["--dreamlife-ui-test-fresh", "--dreamlife-ui-test-future",
                         "--dreamlife-ui-test-external", "--dreamlife-ui-test-task-ready",
                         "--dreamlife-ui-test-resume", "--dreamlife-ui-test-decor-side",
                         "--dreamlife-ui-test-extreme-save",
                         "--dreamlife-ui-test-sequence-limit",
                         "--dreamlife-ui-test-ambiguous-save",
                         "--dreamlife-ui-test-equal-primary-backup",
                         "--dreamlife-ui-test-equal-primary-pending",
                         "--dreamlife-ui-test-equal-backup-with-pending",
                         "--dreamlife-ui-test-matching-copies",
                         "--dreamlife-ui-test-showcase"]
        if arguments.contains(where: { testFlags.contains($0) }) {
            // Test-only, isolated suite; resume is the sole fixture that keeps
            // the previous test launch's progress for persistence assertions.
            let suite = "dreamlife.uiTests.fixture"
            let defaults = UserDefaults(suiteName: suite)!
            if !arguments.contains("--dreamlife-ui-test-resume") {
                defaults.removePersistentDomain(forName: suite)
            }
            if arguments.contains("--dreamlife-ui-test-future") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.reward(coins: 1)
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
                    if let future = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(future, forKey: "save")
                    }
                }
            }
            if arguments.contains("--dreamlife-ui-test-task-ready") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                for _ in 0..<3 { _ = fixture.performInteraction("dance", in: "living") }
            }
            if arguments.contains("--dreamlife-ui-test-decor-side") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let lamp = fixture.roomItems.first(where: { $0.id == "lamp" }) {
                    _ = fixture.selectRoomItem(lamp, in: "living", slot: "side")
                }
            }
            if arguments.contains("--dreamlife-ui-test-extreme-save") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["coins"] = Int.max
                    json["stars"] = Int.max
                    json["dailyLifeProgress"] = ["day": Int.max, "phaseIndex": 2,
                        "chainStep": 0, "streak": Int.max, "lastCompletedDay": Int.max,
                        "phaseActionCounts": [:]]
                    if let oversized = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(oversized, forKey: "save")
                    }
                }
            }
            if arguments.contains("--dreamlife-ui-test-sequence-limit") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["commitSequence"] = Int.max
                    if let terminal = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(terminal, forKey: "save")
                    }
                }
            }
            if arguments.contains("--dreamlife-ui-test-equal-backup-with-pending") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["commitSequence"] = 9
                    json["coins"] = 880
                    if let primary = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(primary, forKey: "save")
                    }
                    json["coins"] = 640
                    if let backup = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(backup, forKey: "save.backup")
                    }
                    json["commitSequence"] = 8
                    json["coins"] = 510
                    if let pending = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(pending, forKey: "save.pending")
                    }
                }
            }
            if arguments.contains("--dreamlife-ui-test-equal-primary-pending") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["commitSequence"] = 9
                    json["coins"] = 880
                    if let primary = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(primary, forKey: "save")
                    }
                    json["coins"] = 640
                    if let pending = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(pending, forKey: "save.pending")
                    }
                    defaults.removeObject(forKey: "save.backup")
                }
            }
            if arguments.contains("--dreamlife-ui-test-equal-primary-backup") ||
                arguments.contains("--dreamlife-ui-test-matching-copies") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["commitSequence"] = 9
                    json["coins"] = 880
                    if let primary = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(primary, forKey: "save")
                    }
                    json["coins"] = 640
                    if let backup = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(backup, forKey: "save.backup")
                    }
                    if arguments.contains("--dreamlife-ui-test-matching-copies") {
                        defaults.set(defaults.data(forKey: "save.backup"), forKey: "save.pending")
                    } else {
                        defaults.removeObject(forKey: "save.pending")
                    }
                }
            }
            if arguments.contains("--dreamlife-ui-test-ambiguous-save") {
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                if let data = defaults.data(forKey: "save"),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    json["commitSequence"] = 5
                    json["coins"] = 880
                    if let committed = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(committed, forKey: "save.backup")
                    }
                    json["coins"] = 640
                    if let pending = try? JSONSerialization.data(withJSONObject: json) {
                        defaults.set(pending, forKey: "save.pending")
                    }
                    defaults.removeObject(forKey: "save")
                }
            }
            if arguments.contains("--dreamlife-ui-test-showcase") {
                // App Store screenshot scene: a lived-in house, an invited friend and a pet.
                let fixture = GameStore(defaults: defaults, saveKey: "save")
                fixture.completeOnboarding()
                fixture.reward(coins: 400, stars: 6)
                fixture.updateCharacter(name: "Mia", hairStyleID: "curls", hairColorID: "honey",
                                        skinToneID: "warm", accessoryID: "star")
                if let party = fixture.outfits.first(where: { $0.id == "party" }) { _ = fixture.selectOutfit(party) }
                if let lamp = fixture.roomItems.first(where: { $0.id == "lamp" }) {
                    _ = fixture.selectRoomItem(lamp, in: "living", slot: "side")
                }
                if let plant = fixture.roomItems.first(where: { $0.id == "plant" }) {
                    _ = fixture.selectRoomItem(plant, in: "bedroom", slot: "main")
                }
                for id in ["living.tv", "living.bookshelf", "living.clock",
                           "kitchen.fridge", "kitchen.oven", "kitchen.pot", "kitchen.cabinet",
                           "kitchen.table", "kitchen.plate", "kitchen.pan", "kitchen.sink"] {
                    if let item = fixture.furniture.first(where: { $0.id == id }) { _ = fixture.placeFurniture(item) }
                }
                _ = fixture.inviteFriend("luna")
                _ = fixture.movePet(to: "living")
                fixture.updatePet(name: "Pip", species: "cat")
                for _ in 0..<2 { _ = fixture.performInteraction("dance", in: "living") }
                _ = fixture.socialActivity("dance", with: "luna")
            }
            let activeStore = GameStore(defaults: defaults, saveKey: "save")
            if arguments.contains("--dreamlife-ui-test-external") {
                // Simulate another session changing the same committed save.
                // Trigger a write from the stale session to show its warning.
                let other = GameStore(defaults: defaults, saveKey: "save")
                other.reward(coins: 20)
                activeStore.reward(coins: 5)
            }
            _store = StateObject(wrappedValue: activeStore)
            return
        }
        #endif
        _store = StateObject(wrappedValue: GameStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
