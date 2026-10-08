import Foundation

@main struct DreamLifeV245Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.45: \(label)") }
            checks += 1
        }
        func make(_ label: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v245.\(label)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 10)
            return (store, defaults)
        }
        func edit(_ data: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        func run(_ label: String, primary: Int?, backup: Int, pending: Int,
                 backupSeq: Int = 5, pendingSeq: Int = 5,
                 corruptPrimary: Bool = false, expect: Int) {
            let (_, defaults) = make(label)
            let source = defaults.data(forKey: "save")!
            if corruptPrimary { defaults.set(Data("broken-primary".utf8), forKey: "save") }
            else if let primary { defaults.set(edit(source, sequence: 4, coins: primary), forKey: "save") }
            else { defaults.removeObject(forKey: "save") }
            let committed = edit(source, sequence: backupSeq, coins: backup)
            let staged = backupSeq == pendingSeq && backup == pending
                ? committed : edit(source, sequence: pendingSeq, coins: pending)
            let primaryBefore = defaults.data(forKey: "save")
            defaults.set(committed, forKey: "save.backup")
            defaults.set(staged, forKey: "save.pending")
            let conflict = backupSeq == pendingSeq && committed != staged
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == expect, "\(label): correct candidate")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery == conflict, "\(label): correct read-only status")
            check(defaults.data(forKey: "save.pending") == (conflict ? staged : nil), "\(label): journal preserved or replayed")
            check(defaults.data(forKey: "save.backup") == committed, "\(label): committed backup retained")
            if conflict {
                check(defaults.data(forKey: "save") == primaryBefore, "\(label): primary untouched")
                restored.reward(coins: 100)
                check(defaults.data(forKey: "save") == primaryBefore, "\(label): writes blocked")
                check(defaults.data(forKey: "save.pending") == staged, "\(label): pending untouched")
            }
            check(GameStore(defaults: defaults, saveKey: "save").coins == expect, "\(label): relaunch keeps preview")
        }
        run("missing-primary-equal-seq", primary: nil, backup: 880, pending: 640, expect: 880)
        run("older-primary-equal-seq", primary: 520, backup: 880, pending: 640, expect: 880)
        run("corrupt-primary-equal-seq", primary: nil, backup: 880, pending: 640, corruptPrimary: true, expect: 880)
        run("newer-journal-wins", primary: 520, backup: 880, pending: 940, pendingSeq: 6, expect: 940)
        // Same payload at the same sequence is not a conflict; replay is safe.
        run("identical-backup-pending", primary: nil, backup: 880, pending: 880, expect: 880)
        // v2.50: even a committed primary cannot prove that a distinct
        // equal-sequence journal is stale; keep both for parent inspection.
        do {
            let (_, defaults) = make("committed-primary")
            let source = defaults.data(forKey: "save")!
            let committed = edit(source, sequence: 5, coins: 777)
            defaults.set(committed, forKey: "save")
            defaults.set(edit(source, sequence: 5, coins: 888), forKey: "save.backup")
            let pending = edit(source, sequence: 5, coins: 999)
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 777, "same-sequence committed primary wins")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "same-sequence pending conflict locked")
            check(defaults.data(forKey: "save.pending") == pending, "same-sequence pending preserved")
            check(GameStore(defaults: defaults, saveKey: "save").isSaveReadOnlyDueToAmbiguousRecovery, "primary remains a protected preview")
        }
        print("DreamLife House v2.45 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
