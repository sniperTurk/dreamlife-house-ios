import Foundation

@main struct DreamLifeV253Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.53: \(label)") }
            checks += 1
        }
        func edited(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        let suite = "dreamlife.v253.matches"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let initial = GameStore(defaults: defaults, saveKey: "save")
        initial.reward(coins: 10)
        let source = defaults.data(forKey: "save")!
        let primary = edited(source, sequence: 9, coins: 880)
        let backup = edited(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        let store = GameStore(defaults: defaults, saveKey: "save")
        check(store.isSaveReadOnlyDueToAmbiguousRecovery, "fixture is read only")
        var inspection = store.beginRecoveryInspection()!
        check(inspection.previews.count == 3, "three slots")
        check(inspection.previews[0].byteComparisonSummary == "No other copy has identical bytes", "primary differs")
        check(inspection.previews[1].byteComparisonSummary == "No other copy has identical bytes", "backup differs")
        check(inspection.previews[2].byteComparisonSummary == nil, "absent is not a duplicate")
        check(inspection.previews[2].state == .absent, "pending absent")
        check(inspection.previews[0].coins == 880, "primary coins")
        check(inspection.previews[1].coins == 640, "backup coins")
        defaults.set(backup, forKey: "save.pending")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) == nil, "stale inspection denied")
        inspection = store.beginRecoveryInspection()!
        check(inspection.previews[0].byteComparisonSummary == "No other copy has identical bytes", "primary still unique")
        check(inspection.previews[1].byteComparisonSummary == "Exact bytes match Pending copy", "backup matches pending")
        check(inspection.previews[2].byteComparisonSummary == "Exact bytes match Backup copy", "pending matches backup")
        check(inspection.previews[2].coins == 640, "matching pending totals")
        let encoded = store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id)!
        let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: encoded)
        check(archive.integrityStatus == .verified, "archive verified")
        check(archive.slots.map(\.bytes) == [primary, backup, backup], "all bytes preserved")
        var json = (try! JSONSerialization.jsonObject(with: backup)) as! [String: Any]
        json["selectedOutfitID"] = "hidden-difference"
        let changed = try! JSONSerialization.data(withJSONObject: json)
        check(changed != backup, "hidden field changes bytes")
        defaults.set(changed, forKey: "save.pending")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) == nil, "hidden edit invalidates export")
        inspection = store.beginRecoveryInspection()!
        check(inspection.previews[1].coins == inspection.previews[2].coins, "visible totals identical")
        check(inspection.previews[1].byteComparisonSummary == "No other copy has identical bytes", "backup now unique")
        check(inspection.previews[2].byteComparisonSummary == "No other copy has identical bytes", "hidden difference visible as byte comparison")
        let bad = Data("broken-json".utf8)
        defaults.set(bad, forKey: "save")
        defaults.set(bad, forKey: "save.pending")
        inspection = store.beginRecoveryInspection()!
        check(inspection.previews[0].state == .unreadable, "corrupt primary preview")
        check(inspection.previews[2].state == .unreadable, "corrupt pending preview")
        check(inspection.previews[0].byteComparisonSummary == "Exact bytes match Pending copy", "corrupt bytes still compared")
        check(inspection.previews[2].byteComparisonSummary == "Exact bytes match Primary copy", "corrupt copy symmetry")
        check(defaults.data(forKey: "save") == bad, "primary untouched")
        check(defaults.data(forKey: "save.backup") == backup, "backup untouched")
        check(defaults.data(forKey: "save.pending") == bad, "pending untouched")
        print("DreamLife House v2.53 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
