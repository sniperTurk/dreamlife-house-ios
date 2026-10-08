import Foundation

@main struct DreamLifeV252Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fatalError("v2.52: \(label)") }
            checks += 1
        }
        func edited(_ bytes: Data, sequence: Int, coins: Int) -> Data {
            var json = (try! JSONSerialization.jsonObject(with: bytes)) as! [String: Any]
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        let suite = "dreamlife.v252.inspection"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let initial = GameStore(defaults: defaults, saveKey: "save")
        check(initial.beginRecoveryInspection() == nil, "healthy game cannot inspect")
        initial.reward(coins: 10)
        let source = defaults.data(forKey: "save")!
        let primary = edited(source, sequence: 9, coins: 880)
        let backup = edited(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "fixture is ambiguous")
        let inspection = restored.beginRecoveryInspection()!
        check(inspection.previews.map(\.coins) == [880, 640, nil], "inspection preview matches candidates")
        check(inspection.previews.map(\.id) == ["primary", "backup", "pending"], "stable slot order")
        let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self,
            from: restored.exportAmbiguousRecoveryArchive(inspectionID: inspection.id)!)
        check(archive.integrityStatus == .verified, "archive integrity")
        check(archive.slots.map(\.bytes) == [primary, backup, nil], "archive matches reviewed bytes")
        check(restored.exportAmbiguousRecoveryArchive(inspectionID: UUID()) == nil, "random token denied")
        // Modify an invisible JSON field, leaving all summary totals unchanged.
        var json = (try! JSONSerialization.jsonObject(with: backup)) as! [String: Any]
        json["selectedOutfitID"] = "invisible-change"
        let modified = try! JSONSerialization.data(withJSONObject: json)
        check(modified != backup, "invisible edit changes bytes")
        defaults.set(modified, forKey: "save.backup")
        check(restored.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) == nil, "stale inspection denied")
        check(defaults.data(forKey: "save.backup") == modified, "changed backup not touched")
        let refresh = restored.beginRecoveryInspection()!
        check(refresh.previews == inspection.previews, "same visible totals after invisible change")
        check(refresh.id != inspection.id, "refresh issues new token")
        check(restored.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) == nil, "old token revoked")
        let updated = try! JSONDecoder().decode(SaveRecoveryArchive.self,
            from: restored.exportAmbiguousRecoveryArchive(inspectionID: refresh.id)!)
        check(updated.slots[1].bytes == modified, "refreshed export uses updated raw backup")
        let pending = edited(source, sequence: 10, coins: 950)
        defaults.set(pending, forKey: "save.pending")
        check(restored.exportAmbiguousRecoveryArchive(inspectionID: refresh.id) == nil, "new pending invalidates inspection")
        let refreshedAgain = restored.beginRecoveryInspection()!
        check(refreshedAgain.previews[2].coins == 950, "new pending visible on refresh")
        check(restored.exportAmbiguousRecoveryArchive(inspectionID: refreshedAgain.id) != nil, "new snapshot can export")
        check(defaults.data(forKey: "save") == primary, "primary unchanged")
        check(defaults.data(forKey: "save.backup") == modified, "backup unchanged")
        check(defaults.data(forKey: "save.pending") == pending, "pending unchanged")
        print("DreamLife House v2.52 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
