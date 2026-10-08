import Foundation

@main struct DreamLifeV246Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ ok: @autoclosure () -> Bool, _ name: String) {
            guard ok() else { fatalError("v2.46: \(name)") }
            checks += 1
        }
        func make(_ name: String) -> (GameStore, UserDefaults) {
            let suite = "dreamlife.v246.\(name)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = GameStore(defaults: defaults, saveKey: "save")
            store.reward(coins: 10)
            return (store, defaults)
        }
        func edit(_ source: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: source)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        do {
            let (healthy, _) = make("healthy")
            check(!healthy.isSaveReadOnlyDueToAmbiguousRecovery, "healthy state")
            check(healthy.exportAmbiguousRecoveryArchive() == nil, "no export from healthy game")
        }
        for kind in ["older", "missing", "corrupt"] {
            let (_, defaults) = make(kind)
            let source = defaults.data(forKey: "save")!
            let primary: Data?
            switch kind {
            case "older": primary = edit(source, sequence: 4, coins: 520)
            case "corrupt": primary = Data("invalid-raw-save".utf8)
            default: primary = nil
            }
            let backup = edit(source, sequence: 5, coins: 880)
            let pending = edit(source, sequence: 5, coins: 640)
            if let primary { defaults.set(primary, forKey: "save") }
            else { defaults.removeObject(forKey: "save") }
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "\(kind) locked")
            check(restored.coins == 880, "\(kind) previews backup")
            let data = restored.exportAmbiguousRecoveryArchive()
            check(data != nil, "\(kind) export exists")
            let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: data!)
            check(archive.formatVersion == 2, "\(kind) format")
            check(archive.reason == "ambiguous-equal-sequence", "\(kind) reason")
            check(archive.slots.map(\.name) == ["primary", "backup", "pending"], "\(kind) slot order")
            check(archive.slots.map(\.bytes) == [primary, backup, pending], "\(kind) exact payloads")
            check(data == restored.exportAmbiguousRecoveryArchive(), "\(kind) deterministic export")
            check(defaults.data(forKey: "save") == primary, "\(kind) primary unchanged")
            check(defaults.data(forKey: "save.backup") == backup, "\(kind) backup unchanged")
            check(defaults.data(forKey: "save.pending") == pending, "\(kind) pending unchanged")
            restored.reward(coins: 100)
            check(defaults.data(forKey: "save") == primary, "\(kind) cannot save after export")
            check(defaults.data(forKey: "save.pending") == pending, "\(kind) journal protected")
        }
        print("DreamLife House v2.46 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
