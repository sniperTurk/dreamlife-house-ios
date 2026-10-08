import Foundation

@main struct DreamLifeV240Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.40: \(label)") }
            checks += 1
        }
        func make(_ name: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v240.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        func edit(_ data: Data, _ change: (inout [String: Any]) -> Void) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            change(&json)
            return try! JSONSerialization.data(withJSONObject: json)
        }
        do {
            let (store, d) = make("backup-no-pending")
            store.reward(coins: 10)
            let old = d.data(forKey: "save")!
            store.reward(coins: 30)
            let latest = d.data(forKey: "save")!
            d.set(old, forKey: "save")
            d.set(latest, forKey: "save.backup")
            let recovered = GameStore(defaults: d, saveKey: "save")
            check(recovered.coins == 540, "newer backup without journal")
            check(d.data(forKey: "save.backup") == latest, "newer backup preserved")
            check(GameStore(defaults: d, saveKey: "save").coins == 540, "recovery remains durable")
        }
        do {
            let (store, d) = make("backup-bad-pending")
            store.reward(coins: 20)
            let old = d.data(forKey: "save")!
            store.reward(coins: 40)
            let latest = d.data(forKey: "save")!
            d.set(old, forKey: "save")
            d.set(latest, forKey: "save.backup")
            d.set(Data("broken".utf8), forKey: "save.pending")
            check(GameStore(defaults: d, saveKey: "save").coins == 560, "newer backup with corrupt journal")
            check(d.data(forKey: "save.pending") == nil, "corrupt journal cleared")
            check(d.data(forKey: "save.backup") == latest, "backup preserved on bad journal")
        }
        do {
            let (store, d) = make("pending-keep-backup")
            store.reward(coins: 10)
            let old = d.data(forKey: "save")!
            store.reward(coins: 20)
            let middle = d.data(forKey: "save")!
            store.reward(coins: 30)
            let latest = d.data(forKey: "save")!
            d.set(old, forKey: "save")
            d.set(middle, forKey: "save.backup")
            d.set(latest, forKey: "save.pending")
            check(GameStore(defaults: d, saveKey: "save").coins == 560, "newer pending replayed")
            check(d.data(forKey: "save.backup") == middle, "intermediate backup not rolled back")
            check(d.data(forKey: "save.pending") == nil, "replayed pending cleared")
        }
        do {
            let (first, d) = make("concurrent")
            first.reward(coins: 10)
            let second = GameStore(defaults: d, saveKey: "save")
            second.reward(coins: 25)
            let latest = d.data(forKey: "save")!
            first.reward(coins: 80)
            check(first.isSaveReadOnlyDueToExternalChanges, "stale writer locked")
            check(d.data(forKey: "save") == latest, "newer primary not overwritten")
            check(GameStore(defaults: d, saveKey: "save").coins == 535, "newer progress retained")
        }
        do {
            let (store, d) = make("same-sequence")
            store.reward(coins: 10)
            let changed = edit(d.data(forKey: "save")!) { $0["coins"] = 770 }
            d.set(changed, forKey: "save")
            store.reward(coins: 15)
            check(store.isSaveReadOnlyDueToExternalChanges, "same-sequence edit locks stale writer")
            check(d.data(forKey: "save") == changed, "edited primary retained")
            check(GameStore(defaults: d, saveKey: "save").coins == 770, "same-sequence edit reloads")
        }
        do {
            let (store, d) = make("external-journal")
            store.reward(coins: 10)
            let primary = d.data(forKey: "save")!
            let staged = edit(primary) {
                $0["coins"] = 710
                $0["commitSequence"] = (($0["commitSequence"] as? Int) ?? 0) + 1
            }
            d.set(staged, forKey: "save.pending")
            store.reward(coins: 60)
            check(store.isSaveReadOnlyDueToExternalChanges, "external journal locks writer")
            check(d.data(forKey: "save") == primary, "primary unchanged by stale writer")
            check(d.data(forKey: "save.pending") == staged, "journal not destroyed")
            check(GameStore(defaults: d, saveKey: "save").coins == 710, "journal recovered on reload")
        }
        print("DreamLife House v2.40 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
