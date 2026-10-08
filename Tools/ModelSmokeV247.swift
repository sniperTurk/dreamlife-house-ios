import Foundation

@main struct DreamLifeV247Smoke {
    @MainActor static func main() {
        var checks = 0
        func check(_ ok: @autoclosure () -> Bool, _ message: String) {
            guard ok() else { fatalError("v2.47: \(message)") }
            checks += 1
        }
        check(SaveRecoveryArchive.checksum(for: nil) == "absent", "missing slot")
        check(SaveRecoveryArchive.checksum(for: Data()) == "crc32:00000000:0", "empty slot")
        check(SaveRecoveryArchive.checksum(for: Data("123456789".utf8)) == "crc32:CBF43926:9", "CRC32 reference vector")
        let suite = "dreamlife.v247.integrity"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        first.reward(coins: 10)
        let source = defaults.data(forKey: "save")!
        func edited(_ coins: Int) -> Data {
            var json = try! JSONSerialization.jsonObject(with: source) as! [String: Any]
            json["commitSequence"] = 5
            json["coins"] = coins
            return try! JSONSerialization.data(withJSONObject: json)
        }
        let backup = edited(880)
        let pending = edited(640)
        defaults.removeObject(forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        check(restored.isSaveReadOnlyDueToAmbiguousRecovery, "conflict remains locked")
        let bytes = restored.exportAmbiguousRecoveryArchive()!
        if let path = ProcessInfo.processInfo.environment["DREAMLIFE_TEST_ARCHIVE_PATH"] {
            try! bytes.write(to: URL(fileURLWithPath: path))
        }
        let archive = try! JSONDecoder().decode(SaveRecoveryArchive.self, from: bytes)
        check(archive.formatVersion == 2, "format v2")
        check(archive.integrityStatus == .verified, "export verifies")
        check(archive.slots.map(\.name) == ["primary", "backup", "pending"], "slot order")
        check(archive.slots.map(\.bytes) == [nil, backup, pending], "lossless raw bytes")
        check(archive.slots[0].checksum == "absent", "missing primary marker")
        check(archive.slots[1].checksum == SaveRecoveryArchive.checksum(for: backup), "backup fingerprint")
        check(archive.slots[2].checksum == SaveRecoveryArchive.checksum(for: pending), "pending fingerprint")
        check(bytes == restored.exportAmbiguousRecoveryArchive(), "deterministic output")
        check(defaults.data(forKey: "save.backup") == backup, "backup not mutated")
        check(defaults.data(forKey: "save.pending") == pending, "pending not mutated")
        for index in 0..<3 {
            var tampered = archive.slots
            let original = tampered[index]
            tampered[index] = .init(name: original.name, bytes: Data("tampered".utf8), checksum: original.checksum)
            check(SaveRecoveryArchive(formatVersion: 2, reason: archive.reason, slots: tampered).integrityStatus == .invalid, "slot \(index) damaged")
        }
        let noChecksum = archive.slots.enumerated().map { index, slot in
            SaveRecoveryArchive.Slot(name: slot.name, bytes: slot.bytes, checksum: index == 1 ? nil : slot.checksum)
        }
        check(SaveRecoveryArchive(formatVersion: 2, reason: archive.reason, slots: noChecksum).integrityStatus == .invalid, "missing checksum")
        check(SaveRecoveryArchive(formatVersion: 2, reason: "other", slots: archive.slots).integrityStatus == .invalid, "wrong reason")
        check(SaveRecoveryArchive(formatVersion: 3, reason: archive.reason, slots: archive.slots).integrityStatus == .invalid, "unknown format")
        check(SaveRecoveryArchive(formatVersion: 2, reason: archive.reason, slots: Array(archive.slots.reversed())).integrityStatus == .invalid, "reordered slots")
        check(SaveRecoveryArchive(formatVersion: 2, reason: archive.reason, slots: Array(archive.slots.prefix(2))).integrityStatus == .invalid, "truncated slots")
        let v1 = SaveRecoveryArchive(formatVersion: 1, reason: archive.reason, slots: archive.slots)
        check(v1.integrityStatus == .legacyUnverified, "v1 cannot be certified")
        check(try! JSONDecoder().decode(SaveRecoveryArchive.self, from: JSONEncoder().encode(v1)).integrityStatus == .legacyUnverified, "v1 backward decoding")
        restored.reward(coins: 100)
        check(defaults.data(forKey: "save.backup") == backup, "write protection after export")
        print("DreamLife House v2.47 model smoke: \(checks)/\(checks) assertions PASSED")
    }
}
