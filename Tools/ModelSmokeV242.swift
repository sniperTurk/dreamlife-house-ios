import Foundation

@main struct DreamLifeV242Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ description: String) {
            guard condition() else { fatalError("v2.42: \(description)") }
            checks += 1
        }
        func make(_ name: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v242.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        do {
            let (store, defaults) = make("side")
            let lamp = store.roomItems.first { $0.id == "lamp" }!
            check(!store.hasPlacedAdventureDecoration, "initial decor locked")
            check(!store.claimAdventureTask("decorate"), "cannot claim before placement")
            check(store.selectRoomItem(lamp, in: "living", slot: "side"), "side lamp placement")
            check(store.selectedItemsByRoom["living"] == "sofa", "legacy main unchanged")
            check(store.hasPlacedAdventureDecoration, "side placement qualifies")
            check(store.claimAdventureTask("decorate"), "side decor reward")
            check(!store.claimAdventureTask("decorate"), "side decor cannot double claim")
            check(store.coins == 460, "side decor fixed reward")
            check(store.stars == 1, "side decor star")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.hasPlacedAdventureDecoration, "side decoration persists")
            check(restored.completedTasks.contains("decorate"), "side reward persists")
            check(restored.coins == 460, "side currency persists")
        }
        do {
            let (store, defaults) = make("fake-catalog")
            let fakeLamp = RoomItem(id: "lamp", name: "Star Lamp", icon: "lamp.table.fill", cost: 0)
            let unknown = RoomItem(id: "secret", name: "Secret", icon: "star", cost: 0)
            let fakeParty = Outfit(id: "party", name: "Party", icon: "sparkles", cost: 0)
            let unknownOutfit = Outfit(id: "secret", name: "Secret", icon: "star", cost: 0)
            check(!store.selectRoomItem(fakeLamp), "reject forged room price")
            check(!store.selectRoomItem(unknown), "reject unknown room item")
            check(!store.selectOutfit(fakeParty), "reject forged outfit price")
            check(!store.selectOutfit(unknownOutfit), "reject unknown outfit")
            check(store.coins == 500, "invalid purchases do not spend")
            check(!store.ownedRoomItemIDs.contains("lamp"), "invalid room item not owned")
            check(!store.ownedOutfitIDs.contains("party"), "invalid outfit not owned")
            check(!store.hasPlacedAdventureDecoration, "invalid room does not unlock task")
            check(!store.claimAdventureTask("decorate"), "invalid room cannot claim")
            check(!store.claimAdventureTask("outfit"), "invalid outfit cannot claim")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 500, "invalid purchases cannot persist")
        }
        do {
            let (store, defaults) = make("recipe")
            store.recordRecipe("Unknown", rewardCoins: 100000)
            store.recordRecipe("Rainbow Cupcake", rewardCoins: 100000)
            store.recordRecipe("Rainbow Cupcake", rewardCoins: 75, rewardStars: 1000)
            check(store.cookedRecipes.isEmpty, "reject untrusted recipe grants")
            check(store.coins == 500, "invalid recipe cannot mint coins")
            check(store.stars == 0, "invalid recipe cannot mint stars")
            check(!store.claimAdventureTask("cupcake"), "invalid recipe cannot unlock task")
            store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
            check(store.coins == 575, "real recipe fixed coins")
            check(store.stars == 1, "real recipe fixed star")
            store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
            check(store.coins == 575, "real recipe no repeat reward")
            check(store.claimAdventureTask("cupcake"), "real recipe unlocks task")
            check(store.coins == 675, "real task fixed reward")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 675, "recipe and claim persist")
        }
        print("DreamLife House v2.42 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
