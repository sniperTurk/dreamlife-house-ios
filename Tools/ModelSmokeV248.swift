import Foundation

@main struct DreamLifeV248Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            guard value() else { fatalError("v2.48: \(message)") }
            checks += 1
        }
        let suite = "dreamlife.v248.preview"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        check(first.previewAmbiguousRecoverySlots() == nil, "healthy save has no preview")
        first.reward(coins: 10)
        let source = defaults.data(forKey: "save")!
        func edit(_ coins: Int) -> Data {
            var json = try! JSONSerialization.jsonObject(with: source) as! [String: Any]
            json["commitSequence"] = 5
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        let backup = edit(880), pending = edit(640)
        defaults.removeObject(forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let store = GameStore(defaults: defaults, saveKey: "save")
        check(store.isSaveReadOnlyDueToAmbiguousRecovery, "conflict is locked")
        let preview = store.previewAmbiguousRecoverySlots()!
        check(preview.count == 3, "three previews")
        check(preview.map(\.id) == ["primary", "backup", "pending"], "slot ordering")
        check(preview.map(\.state) == [.absent, .readable, .readable], "slot states")
        check(preview.map(\.coins) == [nil, 880, 640], "distinct balances")
        check(preview.map(\.sequence) == [nil, 5, 5], "journal numbers")
        check(preview[1].stars == 1, "stars")
        check(preview[1].completedTasks == 0, "task count")
        check(preview[0].summary == "No copy present", "missing copy label")
        check(preview[1].summary.contains("880 coins"), "backup label")
        check(preview[2].summary.contains("640 coins"), "pending label")
        check(defaults.data(forKey: "save") == nil, "no primary created")
        check(defaults.data(forKey: "save.backup") == backup, "backup preserved")
        check(defaults.data(forKey: "save.pending") == pending, "pending preserved")
        check(store.previewAmbiguousRecoverySlots() == preview, "repeatable")
        defaults.set(Data("invalid".utf8), forKey: "save")
        check(store.previewAmbiguousRecoverySlots()![0].state == .unreadable, "corrupt primary")
        check(store.previewAmbiguousRecoverySlots()![0].coins == nil, "no bogus currency")
        var future = try! JSONSerialization.jsonObject(with: backup) as! [String: Any]
        future["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        defaults.set(try! JSONSerialization.data(withJSONObject: future), forKey: "save.backup")
        check(store.previewAmbiguousRecoverySlots()![1].state == .needsNewerApp, "future backup")
        check(store.previewAmbiguousRecoverySlots()![1].coins == nil, "future not decoded")
        defaults.set(backup, forKey: "save.backup")
        var extreme = try! JSONSerialization.jsonObject(with: backup) as! [String: Any]
        extreme["coins"] = Int.max
        extreme["stars"] = -20
        defaults.set(try! JSONSerialization.data(withJSONObject: extreme), forKey: "save.backup")
        check(store.previewAmbiguousRecoverySlots()![1].coins == GameStore.maxSavedCurrency, "max clamp")
        check(store.previewAmbiguousRecoverySlots()![1].stars == 0, "negative clamp")
        check(store.isSaveReadOnlyDueToAmbiguousRecovery, "preview did not unlock writes")
        store.reward(coins: 100)
        check(defaults.data(forKey: "save.pending") == pending, "no pending writes")
        check(defaults.data(forKey: "save") == Data("invalid".utf8), "no primary writes")
        print("DreamLife House v2.48 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
