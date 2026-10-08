import Foundation

@main struct DreamLifeV236Smoke {
    @MainActor static func main() {
        var count = 0
        func check(_ predicate: @autoclosure () -> Bool, _ name: String) {
            guard predicate() else { fatalError("v2.36 smoke failure: \(name)") }
            count += 1
        }
        func make(_ suffix: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v236.\(suffix)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        func future(_ source: Data) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: source)) as! [String: Any]
            json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 3
            json["futureDecoration"] = "preserve-exact-bytes"
            return try! JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        }
        do {
            let (store, defaults) = make("compatible-primary")
            store.reward(coins: 25)
            let primary = defaults.data(forKey: "save")!
            let futureBackup = future(primary)
            defaults.set(futureBackup, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToNewerVersion, "compatible primary writable")
            check(restored.coins == 525, "compatible primary loaded")
            check(defaults.data(forKey: "save.backup") == futureBackup, "newer backup survives load")
            restored.reward(coins: 30)
            check(restored.coins == 555, "gameplay can continue")
            check(defaults.data(forKey: "save.backup") == futureBackup, "newer backup survives rotation")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 555, "primary still persists")
        }
        do {
            let (store, defaults) = make("corrupt-primary")
            store.reward(coins: 7)
            let futureBackup = future(defaults.data(forKey: "save")!)
            let corrupt = Data("invalid-json".utf8)
            defaults.set(corrupt, forKey: "save")
            defaults.set(futureBackup, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToNewerVersion, "corrupt primary future backup read-only")
            check(restored.coins == 500, "defaults used for preview")
            restored.reward(coins: 100)
            restored.resetProgress()
            check(defaults.data(forKey: "save") == corrupt, "corrupt primary untouched")
            check(defaults.data(forKey: "save.backup") == futureBackup, "future backup untouched")
        }
        do {
            let (store, defaults) = make("missing-primary")
            store.reward(coins: 5)
            let futureBackup = future(defaults.data(forKey: "save")!)
            defaults.removeObject(forKey: "save")
            defaults.set(futureBackup, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToNewerVersion, "missing primary future backup read-only")
            restored.completeOnboarding()
            check(defaults.data(forKey: "save") == nil, "no old primary written")
            check(defaults.data(forKey: "save.backup") == futureBackup, "backup retained")
        }
        do {
            let (store, defaults) = make("normal-rotation")
            store.reward(coins: 20)
            let oldPrimary = defaults.data(forKey: "save")
            store.reward(coins: 10)
            check(defaults.data(forKey: "save.backup") == oldPrimary, "compatible backup rotation works")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 530, "compatible primary reloads")
        }
        print("DreamLife House v2.36 model smoke: \(count)/\(count) assertions PASSED")
    }
}
