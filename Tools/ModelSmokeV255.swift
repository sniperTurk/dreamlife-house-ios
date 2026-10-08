import Foundation

private final class InterleavingDefaults: UserDefaults {
    var onPendingWrite: (() -> Void)?
    var onBackupWrite: (() -> Void)?
    override func set(_ value: Any?, forKey defaultName: String) {
        super.set(value, forKey: defaultName)
        if defaultName == "save.pending", let action = onPendingWrite {
            onPendingWrite = nil
            action()
        }
        if defaultName == "save.backup", let action = onBackupWrite {
            onBackupWrite = nil
            action()
        }
    }
}

@main struct DreamLifeV255Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ ok: @autoclosure () -> Bool, _ reason: String) {
            guard ok() else { fatalError("v2.55: \(reason)") }
            checks += 1
        }
        func edit(_ source: Data, sequence: Int, coins: Int) -> Data {
            var object = (try! JSONSerialization.jsonObject(with: source)) as! [String: Any]
            object["commitSequence"] = sequence
            object["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: object)
        }
        func fixture(_ name: String) -> (GameStore, InterleavingDefaults, Data, Data?) {
            let suite = "dreamlife.v255.\(name)"
            let defaults = InterleavingDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let seed = GameStore(defaults: defaults, saveKey: "save")
            seed.reward(coins: 10)
            let live = GameStore(defaults: defaults, saveKey: "save")
            return (live, defaults, defaults.data(forKey: "save")!, defaults.data(forKey: "save.backup"))
        }
        do {
            let (live, defaults, primary, backup) = fixture("preexisting")
            let journal = edit(primary, sequence: 999, coins: 999)
            defaults.set(journal, forKey: "save.pending")
            live.reward(coins: 1)
            check(live.isSaveReadOnlyDueToExternalChanges, "preexisting journal locks writes")
            check(defaults.data(forKey: "save.pending") == journal, "foreign journal preserved")
            check(defaults.data(forKey: "save") == primary, "primary preserved")
            check(defaults.data(forKey: "save.backup") == backup, "backup preserved")
        }
        do {
            let (live, defaults, primary, backup) = fixture("primary-race")
            let external = edit(primary, sequence: 777, coins: 777)
            defaults.onPendingWrite = { defaults.set(external, forKey: "save") }
            live.reward(coins: 1)
            check(live.isSaveReadOnlyDueToExternalChanges, "primary changed during stage")
            check(defaults.data(forKey: "save") == external, "external primary not overwritten")
            check(defaults.data(forKey: "save.pending") == nil, "own staged journal removed")
            check(defaults.data(forKey: "save.backup") == backup, "backup untouched")
        }
        do {
            let (live, defaults, primary, _) = fixture("backup-race")
            let external = edit(primary, sequence: 888, coins: 888)
            defaults.onPendingWrite = { defaults.set(external, forKey: "save.backup") }
            live.reward(coins: 1)
            check(live.isSaveReadOnlyDueToExternalChanges, "backup changed during stage")
            check(defaults.data(forKey: "save") == primary, "primary unchanged")
            check(defaults.data(forKey: "save.backup") == external, "external backup not overwritten")
            check(defaults.data(forKey: "save.pending") == nil, "own pending cleaned")
        }
        do {
            let (live, defaults, primary, _) = fixture("commit-race")
            let external = edit(primary, sequence: 999, coins: 999)
            defaults.onBackupWrite = { defaults.set(external, forKey: "save") }
            live.reward(coins: 1)
            check(live.isSaveReadOnlyDueToExternalChanges, "primary changed during rotation")
            check(defaults.data(forKey: "save") == external, "external primary survives rotation")
            check(defaults.data(forKey: "save.backup") == primary, "old primary remains as backup")
            check(defaults.data(forKey: "save.pending") == nil, "own pending removed after rotation")
        }
        do {
            let (live, defaults, primary, _) = fixture("foreign-pending-race")
            let foreign = edit(primary, sequence: 777, coins: 777)
            defaults.onBackupWrite = { defaults.set(foreign, forKey: "save.pending") }
            live.reward(coins: 1)
            check(live.isSaveReadOnlyDueToExternalChanges, "foreign pending detected before commit")
            check(defaults.data(forKey: "save") == primary, "primary not committed over foreign journal")
            check(defaults.data(forKey: "save.pending") == foreign, "foreign journal not deleted")
            check(defaults.data(forKey: "save.backup") == primary, "backup remains valid")
        }
        do {
            let (live, defaults, _, _) = fixture("normal-save")
            let before = live.coins
            live.reward(coins: 7)
            check(!live.isSaveReadOnlyDueToExternalChanges, "normal writes remain enabled")
            check(defaults.data(forKey: "save.pending") == nil, "normal commit clears journal")
            let reopened = GameStore(defaults: defaults, saveKey: "save")
            check(reopened.coins == before + 7, "normal commit reloads")
            check(!reopened.isSaveReadOnlyDueToAmbiguousRecovery, "normal save is unambiguous")
        }
        print("DreamLife House v2.55 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
