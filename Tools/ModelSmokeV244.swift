import Foundation

@main struct DreamLifeV244Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.44: \(label)") }
            checks += 1
        }
        func make(_ label: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v244.\(label)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return (GameStore(defaults: defaults, saveKey: "save"), defaults)
        }
        func edit(_ data: Data, sequence: Int, coins: Int? = nil) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            json["commitSequence"] = sequence
            if let coins { json["coins"] = coins }
            return try! JSONSerialization.data(withJSONObject: json)
        }
        func sequence(_ data: Data) -> Int {
            let json = (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
            return json["commitSequence"] as! Int
        }
        do {
            let (first, defaults) = make("terminal")
            first.reward(coins: 25)
            let terminal = edit(defaults.data(forKey: "save")!, sequence: Int.max)
            defaults.set(terminal, forKey: "save")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 525, "terminal primary loads")
            check(restored.isSaveReadOnlyDueToSequenceLimit, "terminal primary read-only")
            check(defaults.data(forKey: "save") == terminal, "terminal bytes retained on load")
            restored.reward(coins: 100)
            check(defaults.data(forKey: "save") == terminal, "terminal primary not overwritten")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 525, "terminal progress retained across reload")
        }
        do {
            let (first, defaults) = make("last-commit")
            first.reward(coins: 20)
            let near = edit(defaults.data(forKey: "save")!, sequence: Int.max - 1)
            defaults.set(near, forKey: "save")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(defaults.data(forKey: "save") == near, "load reserves last commit")
            check(!restored.isSaveReadOnlyDueToSequenceLimit, "near-terminal can still save")
            restored.reward(coins: 30)
            let final = defaults.data(forKey: "save")!
            check(sequence(final) == Int.max, "last commit is terminal sequence")
            check(restored.isSaveReadOnlyDueToSequenceLimit, "terminal commit locks writes")
            restored.reward(coins: 40)
            check(defaults.data(forKey: "save") == final, "post-terminal write cannot corrupt")
            check(GameStore(defaults: defaults, saveKey: "save").coins == 550, "last commit survives reload")
        }
        do {
            let (first, defaults) = make("pending")
            first.reward(coins: 10)
            let primary = edit(defaults.data(forKey: "save")!, sequence: Int.max - 1)
            let terminal = edit(primary, sequence: Int.max, coins: 777)
            defaults.set(primary, forKey: "save")
            defaults.set(terminal, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 777, "terminal journal replayed")
            check(restored.isSaveReadOnlyDueToSequenceLimit, "replayed journal locked")
            check(defaults.data(forKey: "save") == terminal, "replayed terminal committed")
            check(defaults.data(forKey: "save.pending") == nil, "replayed journal cleared")
        }
        do {
            let (first, defaults) = make("backup")
            first.reward(coins: 10)
            let primary = edit(defaults.data(forKey: "save")!, sequence: Int.max - 1)
            let terminal = edit(primary, sequence: Int.max, coins: 888)
            defaults.set(primary, forKey: "save")
            defaults.set(terminal, forKey: "save.backup")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.coins == 888, "terminal backup recovered")
            check(restored.isSaveReadOnlyDueToSequenceLimit, "terminal backup locked")
            check(defaults.data(forKey: "save") == terminal, "backup restored without rollback")
            check(defaults.data(forKey: "save.backup") == terminal, "backup retained")
        }
        print("DreamLife House v2.44 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
