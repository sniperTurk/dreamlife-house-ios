import Foundation

@main struct DreamLifeV241Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ result: @autoclosure () -> Bool, _ name: String) {
            guard result() else { fatalError("v2.41: \(name)") }
            checks += 1
        }
        func make(_ name: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v241.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        do {
            let (store, _) = make("locked")
            for id in ["outfit", "decorate", "cupcake", "dance", "unknown", ""] {
                check(!store.claimAdventureTask(id), "locked \(id)")
            }
            check(store.coins == 500, "no unearned coins")
            check(store.stars == 0, "no unearned stars")
            check(store.completedTasks.isEmpty, "no unearned claims")
        }
        do {
            let (store, defaults) = make("dance")
            for i in 1...2 {
                check(store.performInteraction("dance", in: "living"), "dance action \(i)")
                check(!store.claimAdventureTask("dance"), "dance locked at \(i)")
            }
            check(store.performInteraction("dance", in: "living"), "third dance")
            check(store.claimAdventureTask("dance"), "claim dance")
            check(!store.claimAdventureTask("dance"), "dance no double reward")
            check(store.coins == 620, "dance fixed amount")
            check(store.stars == 1, "dance star")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.completedTasks.contains("dance"), "dance claim persisted")
            check(restored.coins == 620, "dance currency persisted")
            check(!restored.claimAdventureTask("dance"), "dance cannot reclaim after reload")
        }
        do {
            let (store, _) = make("outfit")
            check(store.selectOutfit(store.outfits.first { $0.id == "party" }!), "buy outfit")
            check(store.claimAdventureTask("outfit"), "claim outfit")
            check(store.coins == 480, "outfit fixed amount")
            check(!store.claimAdventureTask("outfit"), "outfit cannot double claim")
        }
        do {
            let (store, _) = make("decor")
            check(store.selectRoomItem(store.roomItems.first { $0.id == "lamp" }!), "buy decor")
            check(store.claimAdventureTask("decorate"), "claim decor")
            check(store.coins == 460, "decor fixed amount")
        }
        do {
            let (store, _) = make("cupcake")
            store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
            check(store.claimAdventureTask("cupcake"), "claim cupcake")
            check(store.coins == 675, "cupcake fixed amount")
            check(store.stars == 2, "cupcake stars")
            check(!store.claimAdventureTask("cupcake"), "cupcake cannot double claim")
        }
        print("DreamLife House v2.41 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
