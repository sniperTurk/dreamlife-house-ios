import Foundation

@main struct DreamLifeV249Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.49: \(label)") }
            checks += 1
        }
        func make(_ label: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v249.\(label)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 10)
            return (store, defaults)
        }
        func edit(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        do {
            let (_, defaults) = make("primary-backup")
            let source = defaults.data(forKey: "save")!
            let primary = edit(source, sequence: 9, coins: 880)
            let backup = edit(source, sequence: 9, coins: 640)
            defaults.set(primary, forKey: "save")
            defaults.set(backup, forKey: "save.backup")
            defaults.removeObject(forKey: "save.pending")
            let store = GameStore(defaults: defaults, saveKey: "save")
            check(store.isSaveReadOnlyDueToAmbiguousRecovery, "same-sequence conflict locked")
            check(store.coins == 880, "primary is a preview only")
            check(store.previewAmbiguousRecoverySlots()?.map(\.id) == ["primary", "backup", "pending"], "all slots shown")
            check(store.previewAmbiguousRecoverySlots()?[0].coins == 880, "primary balance")
            check(store.previewAmbiguousRecoverySlots()?[1].coins == 640, "backup balance")
            check(store.previewAmbiguousRecoverySlots()?[2].state == .absent, "missing pending")
            let exported = store.exportAmbiguousRecoveryArchive()!
            let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: exported)
            check(archive.integrityStatus == .verified, "archive integrity")
            check(archive.slots[0].bytes == primary, "primary raw bytes exported")
            check(archive.slots[1].bytes == backup, "backup raw bytes exported")
            check(archive.slots[2].bytes == nil, "absent pending exported")
            store.reward(coins: 40)
            check(defaults.data(forKey: "save") == primary, "primary preserved")
            check(defaults.data(forKey: "save.backup") == backup, "backup preserved")
            check(defaults.data(forKey: "save.pending") == nil, "no journal staged")
            let reopened = GameStore(defaults: defaults, saveKey: "save")
            check(reopened.isSaveReadOnlyDueToAmbiguousRecovery, "reopen remains locked")
            check(reopened.coins == 880, "reopen same preview")
        }
        do {
            let (_, defaults) = make("identical")
            let source = defaults.data(forKey: "save")!
            let same = edit(source, sequence: 9, coins: 880)
            defaults.set(same, forKey: "save")
            defaults.set(same, forKey: "save.backup")
            let store = GameStore(defaults: defaults, saveKey: "save")
            check(!store.isSaveReadOnlyDueToAmbiguousRecovery, "identical not ambiguous")
            store.reward(coins: 5)
            check(GameStore(defaults: defaults, saveKey: "save").coins == 885, "identical writes persist")
        }
        do {
            let (_, defaults) = make("older")
            let source = defaults.data(forKey: "save")!
            defaults.set(edit(source, sequence: 9, coins: 880), forKey: "save")
            defaults.set(edit(source, sequence: 8, coins: 640), forKey: "save.backup")
            let store = GameStore(defaults: defaults, saveKey: "save")
            check(!store.isSaveReadOnlyDueToAmbiguousRecovery, "older backup safe")
            check(store.coins == 880, "newer primary preview")
        }
        do {
            let (store, defaults) = make("late-backup")
            let primary = defaults.data(forKey: "save")!
            var json = (try! JSONSerialization.jsonObject(with: primary)) as! [String: Any]
            json["coins"] = 222
            let backup = try! JSONSerialization.data(withJSONObject: json)
            defaults.set(backup, forKey: "save.backup")
            store.reward(coins: 50)
            check(store.isSaveReadOnlyDueToAmbiguousRecovery, "late conflict locks store")
            check(defaults.data(forKey: "save") == primary, "late conflict preserves primary")
            check(defaults.data(forKey: "save.backup") == backup, "late conflict preserves backup")
            check(defaults.data(forKey: "save.pending") == nil, "late conflict no journal")
            check(store.exportAmbiguousRecoveryArchive() != nil, "late conflict export enabled")
        }
        do {
            let (_, defaults) = make("corrupt")
            defaults.set(Data("bad".utf8), forKey: "save.backup")
            let store = GameStore(defaults: defaults, saveKey: "save")
            check(!store.isSaveReadOnlyDueToAmbiguousRecovery, "corrupt backup not equal-sequence")
            check(store.coins == 510, "healthy primary survives")
        }
        print("DreamLife House v2.49 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
