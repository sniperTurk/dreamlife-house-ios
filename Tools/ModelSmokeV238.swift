import Foundation

@main struct DreamLifeV238Smoke {
    @MainActor static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("v2.38: \(name)") }
            count += 1
        }
        func make(_ name: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v238.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        do {
            let (store, defaults) = make("pending-only")
            store.reward(coins: 35)
            let staged = defaults.data(forKey: "save")!
            defaults.removeObject(forKey: "save")
            defaults.set(staged, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 535, "pending-only coins")
            check(defaults.data(forKey: "save") != nil, "pending-only committed")
            check(defaults.data(forKey: "save.pending") == nil, "pending-only cleared")
        }
        do {
            let (store, defaults) = make("pending-before-rotate")
            store.reward(coins: 20)
            let previous = defaults.data(forKey: "save")!
            store.reward(coins: 40)
            let newest = defaults.data(forKey: "save")!
            defaults.set(previous, forKey: "save")
            defaults.removeObject(forKey: "save.backup")
            defaults.set(newest, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 560, "pending before rotate latest")
            check(defaults.data(forKey: "save.backup") == previous, "prior primary saved")
            check(defaults.data(forKey: "save.pending") == nil, "pending removed")
        }
        do {
            let (store, defaults) = make("pending-after-rotate")
            store.reward(coins: 15)
            let previous = defaults.data(forKey: "save")!
            store.reward(coins: 25)
            let newest = defaults.data(forKey: "save")!
            defaults.set(previous, forKey: "save")
            defaults.set(previous, forKey: "save.backup")
            defaults.set(newest, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 540, "pending after rotate latest")
            check(defaults.data(forKey: "save.backup") == previous, "prior backup preserved")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 540, "pending committed")
        }
        do {
            let (store, defaults) = make("already-committed")
            store.reward(coins: 5)
            let committed = defaults.data(forKey: "save")!
            defaults.set(committed, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 505, "already committed latest")
            check(defaults.data(forKey: "save.pending") == nil, "stale pending cleared")
        }
        do {
            let (store, defaults) = make("corrupt-primary")
            store.reward(coins: 20)
            let good = defaults.data(forKey: "save")!
            store.reward(coins: 40)
            defaults.set(Data("broken".utf8), forKey: "save")
            defaults.set(good, forKey: "save.backup")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 520, "corrupt primary recovered")
            loaded.reward(coins: 10)
            check(defaults.data(forKey: "save.backup") == good, "good backup preserved")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 530, "recovered save writable")
        }
        do {
            let (store, defaults) = make("protected-pending")
            store.reward(coins: 10)
            let original = defaults.data(forKey: "save")!
            var json = (try! JSONSerialization.jsonObject(with: original)) as! [String: Any]
            json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
            let future = try! JSONSerialization.data(withJSONObject: json)
            defaults.set(future, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.isSaveReadOnlyDueToNewerVersion, "future pending readonly")
            check(loaded.coins == 510, "compatible primary preview")
            loaded.reward(coins: 5)
            check(defaults.data(forKey: "save") == original, "primary preserved")
            check(defaults.data(forKey: "save.pending") == future, "future pending preserved")
        }
        do {
            let (store, defaults) = make("invalid-pending")
            store.reward(coins: 25)
            defaults.set(Data("{\"coins\":".utf8), forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 525, "invalid pending ignored")
            check(defaults.data(forKey: "save.pending") == nil, "invalid pending cleared")
        }
        do {
            let (store, defaults) = make("future-backup")
            store.reward(coins: 15)
            let old = defaults.data(forKey: "save")!
            store.reward(coins: 25)
            let newest = defaults.data(forKey: "save")!
            var json = (try! JSONSerialization.jsonObject(with: newest)) as! [String: Any]
            json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 2
            let future = try! JSONSerialization.data(withJSONObject: json)
            defaults.set(old, forKey: "save")
            defaults.set(future, forKey: "save.backup")
            defaults.set(newest, forKey: "save.pending")
            let loaded = GameStore(defaults: defaults, saveKey: "save")
            check(loaded.coins == 540, "latest staged restored")
            check(defaults.data(forKey: "save.backup") == future, "future backup preserved")
            check(defaults.data(forKey: "save.pending") == nil, "pending cleared")
        }
        print("DreamLife House v2.38 model smoke: \(count)/\(count) assertions PASSED")
    }
}
