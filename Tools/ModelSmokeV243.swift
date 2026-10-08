import Foundation

@main struct DreamLifeV243Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ result: @autoclosure () -> Bool, _ message: String) {
            guard result() else { fatalError("v2.43: \(message)") }
            checks += 1
        }
        func fixture(_ name: String) -> (UserDefaults, String) {
            let suite = "dreamlife.v243.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 1)
            return (defaults, "save")
        }
        func change(_ defaults: UserDefaults, _ mutate: (inout [String:Any]) -> Void) {
            var json = try! JSONSerialization.jsonObject(with: defaults.data(forKey: "save")!) as! [String:Any]
            mutate(&json)
            defaults.set(try! JSONSerialization.data(withJSONObject: json), forKey: "save")
        }
        do {
            let (defaults, key) = fixture("extreme")
            change(defaults) { json in
                json["coins"] = Int.max
                json["stars"] = Int.max
                json["interactionCounts"] = ["living.dance": Int.max, "pet.feed": Int.max]
                json["dailyLifeProgress"] = ["day": Int.max, "phaseIndex": 2, "chainStep": 2, "streak": Int.max, "lastCompletedDay": Int.max, "phaseActionCounts": ["day1.shower": Int.max]]
                json["gardenProgress"] = ["poolVisits": Int.max, "loungeVisits": Int.max, "petPlayVisits": Int.max]
                json["socialProgress"] = ["friendshipXP": ["luna": Int.max], "hangouts": ["luna": Int.max], "activeFriendID": "luna", "partyWins": Int.max]
            }
            let store = GameStore(defaults: defaults, saveKey: key)
            check(store.coins == GameStore.maxSavedCurrency, "coins normalized")
            check(store.stars == GameStore.maxSavedCurrency, "stars normalized")
            check(store.interactionCount("dance", in: "living") == GameStore.maxSavedCounter, "interactions normalized")
            check(store.dailyLifeProgress.day == GameStore.maxSavedDay, "day normalized")
            check(store.dailyLifeProgress.streak == GameStore.maxSavedCounter, "streak normalized")
            check(store.dailyLifeProgress.lastCompletedDay == GameStore.maxSavedDay, "last day normalized")
            check(store.gardenProgress.poolVisits == GameStore.maxSavedCounter, "garden normalized")
            check(store.socialProgress.friendshipXP["luna"] == GameStore.maxSavedCounter, "friend XP normalized")
            check(store.socialProgress.partyWins == GameStore.maxSavedCounter, "party wins normalized")
            check(store.advanceDayPhase(), "advance final phase without integer overflow")
            check(store.dailyLifeProgress.day == GameStore.maxSavedDay, "day stays bounded")
            check(store.performInteraction("dance", in: "living"), "large counter increments safely")
            check(store.interactionCount("dance", in: "living") == GameStore.maxSavedCounter, "counter saturates")
            store.reward(coins: Int.max, stars: Int.max)
            check(store.coins == GameStore.maxSavedCurrency, "huge reward coin saturates")
            check(store.stars == GameStore.maxSavedCurrency, "huge reward star saturates")
            let restored = GameStore(defaults: defaults, saveKey: key)
            check(restored.dailyLifeProgress.day == GameStore.maxSavedDay, "normalized day persists")
            check(restored.coins == GameStore.maxSavedCurrency, "normalized currency persists")
        }
        do {
            let (defaults, key) = fixture("streak")
            change(defaults) { json in
                json["dailyLifeProgress"] = ["day": 12, "phaseIndex": 0, "chainStep": 2, "streak": Int.max, "lastCompletedDay": 11, "phaseActionCounts": [:]]
            }
            let store = GameStore(defaults: defaults, saveKey: key)
            check(store.performDailyChainAction("sleep"), "finish chain from extreme streak")
            check(store.coins == 701, "daily reward bounded calculation")
            check(store.dailyLifeProgress.streak == GameStore.maxSavedCounter, "streak does not exceed cap")
        }
        do {
            let (defaults, key) = fixture("negative")
            change(defaults) { json in
                json["coins"] = -1
                json["stars"] = -2
                json["interactionCounts"] = ["living.dance": -100]
                json["dailyLifeProgress"] = ["day": -100, "phaseIndex": -1, "chainStep": -2, "streak": -9, "lastCompletedDay": -7, "phaseActionCounts": [:]]
            }
            let store = GameStore(defaults: defaults, saveKey: key)
            check(store.coins == 0, "negative coins clamped")
            check(store.stars == 0, "negative stars clamped")
            check(store.interactionCount("dance", in: "living") == 0, "negative count clamped")
            check(store.dailyLifeProgress.day == 1, "negative day clamped")
            check(store.dailyLifeProgress.streak == 0, "negative streak clamped")
        }
        print("DreamLife House v2.43 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
