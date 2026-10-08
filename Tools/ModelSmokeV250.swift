import Foundation

@main struct DreamLifeV250Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.50: \(label)") }
            checks += 1
        }
        func make(_ label: String) -> (GameStore, UserDefaults, Data) {
            let suite = "dreamlife.v250.\(label)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 10)
            return (store, defaults, defaults.data(forKey: "save")!)
        }
        func edit(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        do {
            let (_, defaults, original) = make("pending-conflict")
            let primary = edit(original, sequence: 8, coins: 880)
            let pending = edit(original, sequence: 8, coins: 640)
            defaults.set(primary, forKey: "save")
            defaults.removeObject(forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "equal primary/pending conflict locked")
            check(restored.coins == 880, "primary only previewed")
            check(restored.previewAmbiguousRecoverySlots()?.map(\.coins) == [880, nil, 640], "both candidates visible")
            let exported = restored.exportAmbiguousRecoveryArchive()!
            let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: exported)
            check(archive.integrityStatus == .verified, "export verifies")
            check(archive.slots.map(\.bytes) == [primary, nil, pending], "export exact candidates")
            restored.reward(coins: 55)
            check(defaults.data(forKey: "save") == primary, "primary not overwritten")
            check(defaults.data(forKey: "save.pending") == pending, "pending not discarded")
            check(defaults.data(forKey: "save.backup") == nil, "missing backup stays missing")
            check(GameStore(defaults: defaults, saveKey: "save").isSaveReadOnlyDueToAmbiguousRecovery, "reopen stays protected")
        }
        do {
            let (_, defaults, original) = make("backup-older")
            let primary = edit(original, sequence: 9, coins: 880)
            let backup = edit(original, sequence: 8, coins: 710)
            let pending = edit(original, sequence: 9, coins: 640)
            defaults.set(primary, forKey: "save")
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "older backup cannot break tie")
            check(defaults.data(forKey: "save") == primary, "primary preserved with backup")
            check(defaults.data(forKey: "save.backup") == backup, "backup preserved with pending")
            check(defaults.data(forKey: "save.pending") == pending, "pending preserved with backup")
        }
        do {
            let (_, defaults, original) = make("identical-pending")
            let same = edit(original, sequence: 8, coins: 880)
            defaults.set(same, forKey: "save")
            defaults.set(same, forKey: "save.pending")
            defaults.removeObject(forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToAmbiguousRecovery, "identical pending is safe")
            check(defaults.data(forKey: "save.pending") == nil, "identical journal cleaned")
            restored.reward(coins: 5)
            check(GameStore(defaults: defaults, saveKey: "save").coins == 885, "normal save continues")
        }
        do {
            let (_, defaults, original) = make("older-pending")
            defaults.set(edit(original, sequence: 8, coins: 880), forKey: "save")
            defaults.set(edit(original, sequence: 7, coins: 640), forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToAmbiguousRecovery, "older pending not conflict")
            check(restored.coins == 880, "newer primary retained")
            check(defaults.data(forKey: "save.pending") == nil, "older journal cleaned")
        }
        do {
            let (active, defaults, primary) = make("external-pending")
            // A different session now introduces a same-sequence pending copy.
            let sequence = (try! JSONSerialization.jsonObject(with: primary) as! [String: Any])["commitSequence"] as! Int
            let replacement = edit(primary, sequence: sequence, coins: 700)
            defaults.set(replacement, forKey: "save.pending")
            active.reward(coins: 55)
            check(active.isSaveReadOnlyDueToAmbiguousRecovery,
                  "live same-sequence journal conflict locks recovery")
            check(defaults.data(forKey: "save.pending") == replacement, "external journal preserved")
            check(defaults.data(forKey: "save") == primary, "committed primary preserved")
        }
        print("DreamLife House v2.50 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
