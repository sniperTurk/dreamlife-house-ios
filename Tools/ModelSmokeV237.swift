import Foundation

@main struct DreamLifeV237Smoke {
    @MainActor static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.37: \(label)") }
            count += 1
        }
        func make(_ id: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v237.\(id)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        func alter(_ data: Data, marker: Any?) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            if let marker { json["schemaVersion"] = marker }
            else { json.removeValue(forKey: "schemaVersion") }
            let encoded = try! JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            if let text = marker as? String, text == "__fractional__" {
                return Data(String(decoding: encoded, as: UTF8.self)
                    .replacingOccurrences(of: "\"__fractional__\"", with: "4.0").utf8)
            }
            return encoded
        }
        do {
            let (store, defaults) = make("unknown-primary")
            store.reward(coins: 25)
            let old = defaults.data(forKey: "save")!
            let malformed = alter(old, marker: "v-next")
            defaults.set(malformed, forKey: "save")
            defaults.set(old, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToNewerVersion, "unknown primary read only")
            check(restored.coins == 525, "backup preview")
            restored.reward(coins: 99)
            check(defaults.data(forKey: "save") == malformed, "unknown primary preserved")
            check(defaults.data(forKey: "save.backup") == old, "compatible backup preserved")
        }
        for (index, marker) in [NSNull(), NSNumber(value: true), "__fractional__", NSNumber(value: 0)].enumerated() {
            let (store, defaults) = make("invalid-\(index)")
            store.reward(coins: 1)
            let invalid = alter(defaults.data(forKey: "save")!, marker: marker)
            defaults.set(invalid, forKey: "save")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToNewerVersion, "invalid marker \(index) read only")
            restored.resetProgress()
            check(defaults.data(forKey: "save") == invalid, "invalid marker \(index) preserved")
        }
        do {
            let (store, defaults) = make("unknown-backup")
            store.reward(coins: 10)
            let unknown = alter(defaults.data(forKey: "save")!, marker: "unrecognized")
            defaults.set(unknown, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToNewerVersion, "compatible primary writable")
            restored.reward(coins: 20)
            check(defaults.data(forKey: "save.backup") == unknown, "unknown backup preserved")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 530, "compatible primary saved")
        }
        do {
            let (store, defaults) = make("unknown-backup-only")
            store.reward(coins: 15)
            let unknown = alter(defaults.data(forKey: "save")!, marker: NSNull())
            defaults.removeObject(forKey: "save")
            defaults.set(unknown, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToNewerVersion, "unknown backup only read only")
            restored.completeOnboarding()
            check(defaults.data(forKey: "save") == nil, "no empty primary")
            check(defaults.data(forKey: "save.backup") == unknown, "unknown backup intact")
        }
        do {
            let (store, defaults) = make("external")
            store.reward(coins: 30)
            let future = alter(defaults.data(forKey: "save")!, marker: GameStore.currentSaveSchemaVersion + 2)
            defaults.set(future, forKey: "save")
            let oldBackup = defaults.data(forKey: "save.backup")
            store.reward(coins: 50)
            check(store.isSaveReadOnlyDueToNewerVersion, "runtime external replacement read only")
            check(defaults.data(forKey: "save") == future, "runtime future save preserved")
            check(defaults.data(forKey: "save.backup") == oldBackup, "runtime backup unchanged")
        }
        do {
            let (store, defaults) = make("legacy")
            store.reward(coins: 45)
            defaults.set(alter(defaults.data(forKey: "save")!, marker: nil), forKey: "save")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToNewerVersion, "missing schema is legacy")
            check(restored.coins == 545, "legacy coins restored")
            restored.reward(coins: 5)
            check(GameStore(defaults: defaults, saveKey: "save").coins == 550, "legacy writable")
        }
        print("DreamLife House v2.37 model smoke: \(count)/\(count) assertions PASSED")
    }
}
