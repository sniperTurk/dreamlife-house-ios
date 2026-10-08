import Foundation

@main struct DreamLifeV251Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.51: \(label)") }
            checks += 1
        }
        func fixture(_ label: String) -> (GameStore, UserDefaults, Data) {
            let suite = "dreamlife.v251.\(label)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 10)
            return (store, defaults, defaults.data(forKey: "save")!)
        }
        func edited(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        // Older journals must not suppress an existing primary/backup conflict.
        do {
            let (_, defaults, source) = fixture("stale-pending")
            let primary = edited(source, sequence: 9, coins: 880)
            let backup = edited(source, sequence: 9, coins: 640)
            let pending = edited(source, sequence: 8, coins: 510)
            defaults.set(primary, forKey: "save")
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "stale journal still locks ambiguous copies")
            check(restored.coins == 880, "primary is only previewed")
            check(defaults.data(forKey: "save") == primary, "primary untouched")
            check(defaults.data(forKey: "save.backup") == backup, "backup untouched")
            check(defaults.data(forKey: "save.pending") == pending, "stale pending also preserved")
            check(restored.previewAmbiguousRecoverySlots()?.map(\.coins) == [880, 640, 510], "all 3 candidates previewable")
            let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: restored.exportAmbiguousRecoveryArchive()!)
            check(archive.integrityStatus == .verified, "archive valid")
            check(archive.slots.map(\.bytes) == [primary, backup, pending], "all raw candidates exported")
            restored.reward(coins: 40)
            check(defaults.data(forKey: "save") == primary, "locked primary stays untouched")
            check(defaults.data(forKey: "save.backup") == backup, "locked backup stays untouched")
            check(defaults.data(forKey: "save.pending") == pending, "locked pending stays untouched")
        }
        // A newer pending journal must not cause the conflicting backup to be overwritten.
        do {
            let (_, defaults, source) = fixture("newer-pending")
            let primary = edited(source, sequence: 9, coins: 880)
            let backup = edited(source, sequence: 9, coins: 640)
            let pending = edited(source, sequence: 10, coins: 950)
            defaults.set(primary, forKey: "save")
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "newer journal does not bypass backup conflict")
            check(defaults.data(forKey: "save") == primary, "newer journal does not overwrite primary")
            check(defaults.data(forKey: "save.backup") == backup, "newer journal does not overwrite backup")
            check(defaults.data(forKey: "save.pending") == pending, "newer journal remains for export")
        }
        // An active session must not rotate over an equal-sequence backup even
        // when another session has left an older pending journal behind.
        do {
            let (active, defaults, primary) = fixture("active-session")
            let json = (try! JSONSerialization.jsonObject(with: primary)) as! [String: Any]
            let seq = json["commitSequence"] as! Int
            let backup = edited(primary, sequence: seq, coins: 640)
            let pending = edited(primary, sequence: max(0, seq - 1), coins: 450)
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            active.reward(coins: 55)
            check(active.isSaveReadOnlyDueToAmbiguousRecovery, "live session locks conflict with pending")
            check(defaults.data(forKey: "save") == primary, "live primary retained")
            check(defaults.data(forKey: "save.backup") == backup, "live backup retained")
            check(defaults.data(forKey: "save.pending") == pending, "live pending retained")
        }
        // Safe, byte-identical backups still permit normal journal replay.
        do {
            let (_, defaults, source) = fixture("identical-backup")
            let primary = edited(source, sequence: 9, coins: 880)
            let pending = edited(source, sequence: 10, coins: 950)
            defaults.set(primary, forKey: "save")
            defaults.set(primary, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToAmbiguousRecovery, "identical backup is not a conflict")
            check(restored.coins == 950, "newer journal replayed")
            check(defaults.data(forKey: "save.pending") == nil, "replayed journal cleared")
        }
        // Unequal sequences must not be misclassified as same-sequence ties.
        do {
            let (_, defaults, source) = fixture("older-backup")
            defaults.set(edited(source, sequence: 9, coins: 880), forKey: "save")
            defaults.set(edited(source, sequence: 8, coins: 640), forKey: "save.backup")
            defaults.set(edited(source, sequence: 7, coins: 450), forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(!restored.isSaveReadOnlyDueToAmbiguousRecovery, "older backup and pending safe")
            check(restored.coins == 880, "latest primary remains")
        }
        print("DreamLife House v2.51 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
