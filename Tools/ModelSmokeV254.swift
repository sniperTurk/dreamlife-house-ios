import Foundation

@main struct DreamLifeV254Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.54: \(label)") }
            checks += 1
        }
        func edited(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        let suite = "dreamlife.v254.recovery"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let seed = GameStore(defaults: defaults, saveKey: "save")
        seed.reward(coins: 10)
        let source = defaults.data(forKey: "save")!
        let primary = edited(source, sequence: 9, coins: 880)
        let backup = edited(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        let store = GameStore(defaults: defaults, saveKey: "save")
        check(store.isSaveReadOnlyDueToAmbiguousRecovery, "read only conflict")
        var inspection = store.beginRecoveryInspection()!
        check(inspection.summary == "2 of 3 copies present · 2 distinct byte versions · 2 readable", "two distinct copies")
        check(inspection.previews.count == 3, "three previews")
        check(inspection.previews[2].state == .absent, "pending absent")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) != nil, "valid review exports")

        defaults.set(backup, forKey: "save.pending")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) == nil, "changed during confirmation rejected")
        inspection = store.beginRecoveryInspection()!
        check(inspection.summary == "3 of 3 copies present · 2 distinct byte versions · 3 readable", "duplicate counted once")
        check(inspection.previews[1].byteComparisonSummary == "Exact bytes match Pending copy", "duplicate hint")
        let exported = store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id)!
        let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: exported)
        check(archive.integrityStatus == .verified, "valid integrity")
        check(archive.slots.map(\.bytes) == [primary, backup, backup], "all original bytes preserved")

        let corrupt = Data("damaged".utf8)
        defaults.set(corrupt, forKey: "save")
        defaults.set(corrupt, forKey: "save.pending")
        inspection = store.beginRecoveryInspection()!
        check(inspection.summary == "3 of 3 copies present · 2 distinct byte versions · 1 readable · 2 unreadable", "damaged copies counted")
        check(inspection.previews[0].state == .unreadable, "primary unreadable")
        check(inspection.previews[2].state == .unreadable, "pending unreadable")
        check(defaults.data(forKey: "save") == corrupt, "corrupt primary untouched")
        check(defaults.data(forKey: "save.pending") == corrupt, "corrupt pending untouched")

        var futureJSON = (try! JSONSerialization.jsonObject(with: backup)) as! [String: Any]
        futureJSON["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        let future = try! JSONSerialization.data(withJSONObject: futureJSON)
        defaults.set(future, forKey: "save.pending")
        inspection = store.beginRecoveryInspection()!
        check(inspection.summary == "3 of 3 copies present · 3 distinct byte versions · 1 readable · 1 requires a newer app · 1 unreadable", "newer app separate from damage")
        check(inspection.previews[2].state == .needsNewerApp, "future pending recognized")
        check(defaults.data(forKey: "save.pending") == future, "future bytes untouched")
        let oldID = inspection.id
        let newer = store.beginRecoveryInspection()!
        check(oldID != newer.id, "refresh issues new token")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: oldID) == nil, "old token revoked")
        check(store.exportAmbiguousRecoveryArchive(inspectionID: newer.id) != nil, "new token works")
        check(defaults.data(forKey: "save.backup") == backup, "backup untouched")
        check(defaults.data(forKey: "save") == corrupt, "primary still untouched")
        print("DreamLife House v2.54 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
