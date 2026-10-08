import Foundation

@main struct DreamLifeV239Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            guard value() else { fatalError("v2.39 failed: \(label)") }
            checks += 1
        }
        func make(_ suffix: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v239.\(suffix)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            return (GameStore(defaults: d, saveKey: "save"), d)
        }
        func sequence(_ data: Data) -> Int {
            let json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            return json["commitSequence"] as? Int ?? 0
        }
        func modify(_ data: Data, _ f: (inout [String: Any]) -> Void) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            f(&json)
            return try! JSONSerialization.data(withJSONObject: json)
        }
        do {
            let (store, d) = make("stale")
            store.reward(coins: 20)
            let old = d.data(forKey: "save")!
            store.reward(coins: 35)
            let newest = d.data(forKey: "save")!
            d.set(old, forKey: "save.pending")
            let reloaded = GameStore(defaults: d, saveKey: "save")
            check(reloaded.coins == 555, "stale journal cannot roll back coins")
            check(d.data(forKey: "save.pending") == nil, "stale journal removed")
            check(sequence(d.data(forKey: "save")!) > sequence(newest), "normalization advances sequence")
            check(sequence(newest) > sequence(old), "commits ordered")
        }
        do {
            let (store, d) = make("equal")
            store.reward(coins: 44)
            let primary = d.data(forKey: "save")!
            let sameSequenceButWrongCoins = modify(primary) { $0["coins"] = 1 }
            d.set(sameSequenceButWrongCoins, forKey: "save.pending")
            let restored = GameStore(defaults: d, saveKey: "save")
            check(restored.coins == 544, "equal sequence conflict preserves committed primary")
            // v2.50 supersedes the old discard policy: same-sequence bytes
            // cannot be ordered, so preserve the journal for parent export.
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "equal sequence conflict locked")
            check(d.data(forKey: "save.pending") == sameSequenceButWrongCoins, "equal sequence journal preserved")
            check(GameStore(defaults: d, saveKey: "save").isSaveReadOnlyDueToAmbiguousRecovery, "conflict remains protected")
        }
        do {
            let (store, d) = make("newer")
            store.reward(coins: 10)
            let previous = d.data(forKey: "save")!
            store.reward(coins: 20)
            let newest = d.data(forKey: "save")!
            d.set(previous, forKey: "save")
            d.removeObject(forKey: "save.backup")
            d.set(newest, forKey: "save.pending")
            let restored = GameStore(defaults: d, saveKey: "save")
            check(restored.coins == 530, "newer journal recovered")
            check(d.data(forKey: "save.backup") == previous, "previous primary saved as backup")
            check(d.data(forKey: "save.pending") == nil, "replayed journal removed")
            check(GameStore(defaults: d, saveKey: "save").coins == 530, "replay persisted")
        }
        do {
            let (store, d) = make("legacy")
            store.reward(coins: 11)
            let old = modify(d.data(forKey: "save")!) { $0.removeValue(forKey: "commitSequence") }
            let pending = modify(old) { $0["coins"] = 589 }
            d.set(old, forKey: "save")
            d.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: d, saveKey: "save")
            check(restored.coins == 589, "legacy pending replay")
            check(d.data(forKey: "save.pending") == nil, "legacy pending cleared")
            check(sequence(d.data(forKey: "save")!) > 0, "legacy migrated to numbered commits")
        }
        do {
            let (store, d) = make("invalid")
            store.reward(coins: 25)
            let primary = d.data(forKey: "save")!
            let bad = modify(primary) { $0["commitSequence"] = -7 }
            d.set(bad, forKey: "save.pending")
            let restored = GameStore(defaults: d, saveKey: "save")
            check(restored.coins == 525, "invalid negative sequence ignored")
            check(d.data(forKey: "save.pending") == nil, "invalid pending cleared")
            check(GameStore(defaults: d, saveKey: "save").coins == 525, "invalid journal cannot poison subsequent reload")
        }
        do {
            let (store, d) = make("restart")
            store.reward(coins: 12)
            let first = sequence(d.data(forKey: "save")!)
            let restored = GameStore(defaults: d, saveKey: "save")
            let second = sequence(d.data(forKey: "save")!)
            restored.reward(coins: 9)
            let third = sequence(d.data(forKey: "save")!)
            check(second > first, "restart advances sequence")
            check(third > second, "gameplay advances sequence")
            check(GameStore(defaults: d, saveKey: "save").coins == 521, "coins persist across restart")
        }
        do {
            let (store, d) = make("backup-newer")
            store.reward(coins: 10)
            let stale = d.data(forKey: "save")!
            store.reward(coins: 30)
            let latest = d.data(forKey: "save")!
            d.set(Data("broken".utf8), forKey: "save")
            d.set(latest, forKey: "save.backup")
            d.set(stale, forKey: "save.pending")
            let restored = GameStore(defaults: d, saveKey: "save")
            check(restored.coins == 540, "newer backup preferred over stale pending")
            check(d.data(forKey: "save.backup") == latest, "newer backup retained")
            check(d.data(forKey: "save.pending") == nil, "stale journal removed after backup recovery")
            check(GameStore(defaults: d, saveKey: "save").coins == 540, "backup recovery persists")
        }
        print("DreamLife House v2.39 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
