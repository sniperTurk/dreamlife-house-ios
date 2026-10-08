import Foundation
import CoreFoundation
#if canImport(Combine)
import Combine
#else
// Minimal model-only fallback for running gameplay tests on Linux.
// iOS builds always use Apple's Combine implementation.
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
#endif

struct RoomItem: Identifiable, Equatable { let id: String; let name: String; let icon: String; let cost: Int }
struct Outfit: Identifiable, Equatable { let id: String; let name: String; let icon: String; let cost: Int }
struct HouseRoom: Identifiable, Equatable { let id: String; let name: String; let icon: String; let accentIcon: String }
struct CharacterOption: Identifiable, Equatable { let id: String; let name: String; let icon: String }
struct CharacterPosition: Codable, Equatable { var x: Double = 0.5; var y: Double = 0.58 }
struct PetNeeds: Codable, Equatable { var hunger: Int = 70; var happiness: Int = 70; var energy: Int = 75 }
struct PetProfile: Codable, Equatable { var name: String = "Pip"; var species: String = "cat"; var roomID: String = "living" }
struct GardenProgress: Codable, Equatable { var poolVisits: Int = 0; var loungeVisits: Int = 0; var petPlayVisits: Int = 0 }
struct FriendProfile: Identifiable, Equatable { let id: String; let name: String; let icon: String; let favoriteActivity: String }
struct FriendKeepsake: Identifiable, Equatable { let id: String; let name: String; let icon: String; let friendID: String }
struct SurpriseBadge: Identifiable, Equatable { let id: String; let name: String; let icon: String; let roomID: String }
struct SocialProgress: Codable, Equatable { var friendshipXP: [String:Int] = [:]; var hangouts: [String:Int] = [:]; var activeFriendID: String? = nil; var friendRoomID: String? = nil; var partyWins: Int = 0 }
struct PlayerSettings: Codable, Equatable {
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var reducedMotion: Bool = false
    var purchaseConfirmation: Bool = true
    var hasCompletedOnboarding: Bool = false
}

struct DailyLifeProgress: Codable, Equatable {
    var day: Int = 1
    var phaseIndex: Int = 0
    var chainStep: Int = 0
    var streak: Int = 0
    var lastCompletedDay: Int = 0
    var phaseActionCounts: [String:Int] = [:]
}

struct CharacterNeeds: Codable, Equatable {
    var energy: Int = 70
    var fun: Int = 65
    var hygiene: Int = 75
    var hunger: Int = 60
}

struct CharacterProfile: Codable, Equatable {
    var name: String = "Mia"
    var hairStyleID: String = "waves"
    var hairColorID: String = "chestnut"
    var skinToneID: String = "warm"
    var accessoryID: String = "none"
}

private struct SaveGame: Codable {
    var schemaVersion: Int?
    // Monotonic journal ordering. Nil means a save created before v2.39.
    var commitSequence: Int?
    var coins: Int; var stars: Int; var selectedOutfitID: String
    var cookedRecipes: Set<String>; var completedTasks: Set<String>
    var ownedRoomItemIDs: Set<String>; var ownedOutfitIDs: Set<String>
    var selectedItemsByRoom: [String:String]?
    var characterProfile: CharacterProfile?
    var characterNeeds: CharacterNeeds?
    var interactionCounts: [String:Int]?
    var selectedItemsByRoomSlot: [String:[String:String]]?
    var characterPositionsByRoom: [String:CharacterPosition]?
    var petProfile: PetProfile?
    var petNeeds: PetNeeds?
    var gardenProgress: GardenProgress?
    var dailyLifeProgress: DailyLifeProgress?
    var socialProgress: SocialProgress?
    var playerSettings: PlayerSettings?
    var claimedFriendQuestIDs: Set<String>?
    var displayedKeepsakeIDsByRoom: [String:Set<String>]?
}

// A lossless, local-only package for parents to preserve conflicting save
// candidates. Data is encoded as Base64 by JSONEncoder, preserving exact bytes.
// This is an export format, not a save import or automatic conflict resolver.
struct SaveRecoveryArchive: Codable {
    struct Slot: Codable {
        let name: String
        let bytes: Data?
        // Optional for backwards-compatible decoding of v1 exports.
        let checksum: String?
    }
    enum IntegrityStatus: Equatable {
        case verified
        case legacyUnverified
        case invalid
    }
    let formatVersion: Int
    let reason: String
    let slots: [Slot]

    // CRC32 detects accidental truncation/corruption, NOT deliberate tampering.
    // An absent slot and an empty slot intentionally have different markers.
    static func checksum(for bytes: Data?) -> String {
        guard let bytes else { return "absent" }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(0) &- (crc & 1)
                crc = (crc >> 1) ^ (0xEDB8_8320 & mask)
            }
        }
        return String(format: "crc32:%08X", ~crc) + ":\(bytes.count)"
    }

    var integrityStatus: IntegrityStatus {
        guard reason == "ambiguous-equal-sequence",
              slots.map(\.name) == ["primary", "backup", "pending"] else { return .invalid }
        switch formatVersion {
        case 1:
            // v1 exports have no checksums; they remain readable, but cannot
            // be certified as intact. No import or automatic restore occurs.
            return .legacyUnverified
        case 2:
            return slots.allSatisfy { $0.checksum == Self.checksum(for: $0.bytes) }
                ? .verified : .invalid
        default:
            return .invalid
        }
    }
}

// Read-only, parent-facing summary of one raw save candidate. Never exposes
// raw save bytes or chooses a winner for an ambiguous journal conflict.
struct SaveRecoverySlotPreview: Identifiable, Equatable {
    enum State: Equatable {
        case absent
        case readable
        case needsNewerApp
        case unreadable
    }
    let id: String
    let state: State
    let sequence: Int?
    let coins: Int?
    let stars: Int?
    let completedTasks: Int?
    // Compares exact raw save bytes, not decoded gameplay fields. This helps
    // parents distinguish candidates with identical visible totals.
    let byteComparisonSummary: String?

    var title: String {
        switch id {
        case "primary": return "Primary copy"
        case "backup": return "Backup copy"
        case "pending": return "Pending copy"
        default: return "Unknown copy"
        }
    }
    var summary: String {
        switch state {
        case .absent: return "No copy present"
        case .needsNewerApp: return "Requires a newer app or has an unrecognized save format"
        case .unreadable: return "Damaged or unreadable copy"
        case .readable:
            let journal = sequence.map(String.init) ?? "legacy"
            return "Journal \(journal) · \(coins ?? 0) coins · \(stars ?? 0) stars · \(completedTasks ?? 0) tasks"
        }
    }
}

// A single read-only inspection session. The token is opaque to the UI;
// raw save bytes remain inside GameStore, never in SwiftUI view state.
struct SaveRecoveryInspection: Equatable {
    let id: UUID
    let previews: [SaveRecoverySlotPreview]
    // Summary is derived from the SAME captured bytes as the individual rows.
    // Counts never identify a preferred copy or reveal the underlying save data.
    let summary: String
}

@MainActor final class GameStore: ObservableObject {
    static let currentSaveSchemaVersion = 4
    // Defensive bounds for locally restored/edited JSON. These limits are far
    // above normal gameplay but leave headroom for arithmetic and week ranges.
    static let maxSavedCurrency = 1_000_000_000
    static let maxSavedCounter = 1_000_000_000
    static let maxSavedDay = 1_000_000
    private static func bounded(_ value: Int, maximum: Int) -> Int {
        min(maximum, max(0, value))
    }
    private static func saturatedAdd(_ current: Int, _ amount: Int) -> Int {
        let (sum, overflow) = current.addingReportingOverflow(max(0, amount))
        return overflow ? maxSavedCurrency : min(maxSavedCurrency, sum)
    }
    @Published private(set) var coins = 500
    @Published private(set) var stars = 0
    @Published private(set) var selectedOutfitID = "sunny"
    @Published private(set) var cookedRecipes: Set<String> = []
    @Published private(set) var completedTasks: Set<String> = []
    @Published private(set) var ownedRoomItemIDs: Set<String> = ["sofa"]
    @Published private(set) var ownedOutfitIDs: Set<String> = ["sunny"]
    @Published private(set) var selectedItemsByRoom: [String:String] = ["living":"sofa"]
    @Published private(set) var characterProfile = CharacterProfile()
    #if DEBUG
    @Published var characterNeeds = CharacterNeeds()
    #else
    @Published private(set) var characterNeeds = CharacterNeeds()
    #endif
    #if DEBUG
    @Published var interactionCounts: [String:Int] = [:]
    #else
    @Published private(set) var interactionCounts: [String:Int] = [:]
    #endif
    @Published private(set) var selectedItemsByRoomSlot: [String:[String:String]] = ["living":["main":"sofa"]]
    @Published private(set) var characterPositionsByRoom: [String:CharacterPosition] = [:]
    @Published private(set) var petProfile = PetProfile()
    @Published private(set) var petNeeds = PetNeeds()
    @Published private(set) var gardenProgress = GardenProgress()
    #if DEBUG
    @Published var dailyLifeProgress = DailyLifeProgress()
    #else
    @Published private(set) var dailyLifeProgress = DailyLifeProgress()
    #endif
    @Published private(set) var socialProgress = SocialProgress()
    @Published private(set) var playerSettings = PlayerSettings()
    #if DEBUG
    @Published var claimedFriendQuestIDs: Set<String> = []
    #else
    @Published private(set) var claimedFriendQuestIDs: Set<String> = []
    #endif
    @Published private(set) var displayedKeepsakeIDsByRoom: [String:Set<String>] = [:]
    // A future-version or unrecognized-schema save must never be overwritten.
    // Gameplay remains available as a non-persistent preview, with a visible warning.
    @Published private(set) var isSaveReadOnlyDueToNewerVersion = false
    // A different store/session changed the committed save after this instance loaded.
    // Keep the on-disk progress intact rather than silently overwriting it.
    @Published private(set) var isSaveReadOnlyDueToExternalChanges = false
    // Int.max is the terminal journal sequence. Never wrap or overwrite it.
    @Published private(set) var isSaveReadOnlyDueToSequenceLimit = false
    // Conflicting valid snapshots share a journal number; ordering is unknowable.
    // Preserve every on-disk candidate and allow only a read-only preview.
    @Published private(set) var isSaveReadOnlyDueToAmbiguousRecovery = false
    private let defaults: UserDefaults; private let saveKey: String
    private var backupKey: String { "\(saveKey).backup" }
    private var pendingKey: String { "\(saveKey).pending" }
    private var preserveBackupAfterRecovery = false
    private var lastCommittedSequence = 0
    private var lastCommittedData: Data?
    // Capture exact bytes shown to a parent. A later export must match all
    // three copies byte-for-byte, even if visible coin totals stay the same.
    private var inspectedRecoverySlots: (id: UUID, bytes: [Data?])?

    let rooms = [
        HouseRoom(id:"living", name:"Living Room", icon:"sofa.fill", accentIcon:"tv.fill"),
        HouseRoom(id:"bedroom", name:"Bedroom", icon:"bed.double.fill", accentIcon:"moon.stars.fill"),
        HouseRoom(id:"kitchen", name:"Kitchen", icon:"fork.knife", accentIcon:"cup.and.saucer.fill"),
        HouseRoom(id:"bathroom", name:"Bathroom", icon:"shower.fill", accentIcon:"drop.fill"),
        HouseRoom(id:"garden", name:"Garden", icon:"leaf.fill", accentIcon:"sun.max.fill")
    ]
    let roomItems = [
        RoomItem(id:"sofa", name:"Pastel Sofa", icon:"sofa.fill", cost:0), RoomItem(id:"lamp", name:"Star Lamp", icon:"lamp.table.fill", cost:120),
        RoomItem(id:"flowers", name:"Flower Corner", icon:"camera.macro", cost:90), RoomItem(id:"music", name:"Music Spot", icon:"music.note.house.fill", cost:150),
        RoomItem(id:"beanbag", name:"Cloud Seat", icon:"chair.lounge.fill", cost:110), RoomItem(id:"plant", name:"Happy Plant", icon:"leaf.fill", cost:70)
    ]
    let hairStyles = [CharacterOption(id:"waves",name:"Waves",icon:"wind"),CharacterOption(id:"bob",name:"Bob",icon:"scissors"),CharacterOption(id:"curls",name:"Curls",icon:"scribble.variable"),CharacterOption(id:"ponytail",name:"Ponytail",icon:"figure.dance")]
    let hairColors = [CharacterOption(id:"chestnut",name:"Chestnut",icon:"circle.fill"),CharacterOption(id:"midnight",name:"Midnight",icon:"moon.fill"),CharacterOption(id:"honey",name:"Honey",icon:"sun.max.fill"),CharacterOption(id:"berry",name:"Berry",icon:"heart.fill")]
    let skinTones = [CharacterOption(id:"light",name:"Light",icon:"circle.fill"),CharacterOption(id:"warm",name:"Warm",icon:"circle.fill"),CharacterOption(id:"deep",name:"Deep",icon:"circle.fill")]
    var accessories:[CharacterOption] {
        var values = [CharacterOption(id:"none",name:"None",icon:"minus.circle"),CharacterOption(id:"glasses",name:"Glasses",icon:"eyeglasses"),CharacterOption(id:"star",name:"Star Clip",icon:"star.fill"),CharacterOption(id:"flower",name:"Flower Clip",icon:"camera.macro")]
        if hasLightkeeperStreakCrown { values.append(CharacterOption(id:"starlightCrown",name:"Starlight Crown",icon:"crown.fill")) }
        if isCometVeilUnlocked { values.append(CharacterOption(id:"cometVeil",name:"Comet Veil",icon:"sparkles")) }
        return values
    }
    let friends = [
        FriendProfile(id:"luna",name:"Luna",icon:"sparkles",favoriteActivity:"dance"),
        FriendProfile(id:"rio",name:"Rio",icon:"paintpalette.fill",favoriteActivity:"decorate"),
        FriendProfile(id:"ivy",name:"Ivy",icon:"leaf.fill",favoriteActivity:"garden"),
        FriendProfile(id:"nova",name:"Nova",icon:"tshirt.fill",favoriteActivity:"style"),
        FriendProfile(id:"milo",name:"Milo",icon:"fork.knife",favoriteActivity:"cook")
    ]
    let outfits = [Outfit(id:"sunny",name:"Sunny",icon:"sun.max.fill",cost:0),Outfit(id:"party",name:"Party",icon:"sparkles",cost:80),Outfit(id:"sport",name:"Sport",icon:"figure.run",cost:100),Outfit(id:"creative",name:"Creative",icon:"paintpalette.fill",cost:120)]

    init(defaults: UserDefaults = .standard, saveKey: String = "dreamlife.save.v2") { self.defaults=defaults; self.saveKey=saveKey; load() }
    var selectedOutfitIcon:String { outfits.first{$0.id==selectedOutfitID}?.icon ?? "sun.max.fill" }
    func selectedItem(in roomID:String)->RoomItem { selectedItem(in: roomID, slot: "main") }
    func selectedItem(in roomID:String, slot:String)->RoomItem { let id=selectedItemsByRoomSlot[roomID]?[slot] ?? (slot == "main" ? selectedItemsByRoom[roomID] : nil); return roomItems.first{$0.id == id} ?? roomItems[0] }
    func characterPosition(in roomID:String)->CharacterPosition { characterPositionsByRoom[roomID] ?? CharacterPosition() }
    func ownsRoomItem(_ item:RoomItem)->Bool { ownedRoomItemIDs.contains(item.id) }
    func ownsOutfit(_ outfit:Outfit)->Bool { ownedOutfitIDs.contains(outfit.id) }
    @discardableResult func selectRoomItem(_ item:RoomItem, in roomID:String = "living", slot:String = "main")->Bool {
        // Only catalog items at catalog prices may be purchased or placed.
        // Do not trust an arbitrary RoomItem supplied by another caller.
        guard rooms.contains(where: { $0.id == roomID }), ["main", "side"].contains(slot),
              let catalogItem = roomItems.first(where: { $0.id == item.id }), catalogItem == item,
              unlockRoomItem(catalogItem) else { return false }
        selectedItemsByRoomSlot[roomID, default: [:]][slot] = catalogItem.id
        if slot == "main" { selectedItemsByRoom[roomID] = catalogItem.id }
        _ = advanceDailyChainIfMatching("decorate")
        save()
        return true
    }
    // Side-slot decorations also satisfy the House Adventure. The legacy
    // main-slot dictionary is retained for older save compatibility.
    var hasPlacedAdventureDecoration: Bool {
        let decorated: (String) -> Bool = { itemID in
            itemID != "sofa" && self.ownedRoomItemIDs.contains(itemID)
                && self.roomItems.contains(where: { $0.id == itemID })
        }
        return selectedItemsByRoom.values.contains(where: decorated)
            || selectedItemsByRoomSlot.values.contains(where: { $0.values.contains(where: decorated) })
    }
    func moveCharacter(in roomID:String, x:Double, y:Double) { guard rooms.contains(where:{$0.id==roomID}) else{return}; characterPositionsByRoom[roomID]=CharacterPosition(x:min(1,max(0,x)),y:min(1,max(0,y))); save() }
    @discardableResult func dropCharacter(in roomID:String, x:Double, y:Double)->String? {
        guard rooms.contains(where:{$0.id==roomID}) else{return nil}
        let px=min(1,max(0,x)), py=min(1,max(0,y))
        moveCharacter(in:roomID,x:px,y:py)
        let action:String?
        switch roomID {
        case "bedroom": action = (px > 0.58 && py > 0.35) ? "sleep" : nil
        case "living": action = (px < 0.42 && py > 0.35) ? "dance" : nil
        case "kitchen": action = (px > 0.58 && py > 0.30) ? "snack" : nil
        case "bathroom": action = (px > 0.58 && py > 0.28) ? "shower" : nil
        case "garden": action = (px < 0.45 && py > 0.30) ? "play" : nil
        default: action=nil
        }
        guard let action, performInteraction(action,in:roomID) else{return nil}
        return action
    }
    @discardableResult func selectOutfit(_ outfit:Outfit)->Bool {
        guard let catalogOutfit = outfits.first(where: { $0.id == outfit.id }),
              catalogOutfit == outfit, unlockOutfit(catalogOutfit) else { return false }
        selectedOutfitID = catalogOutfit.id
        save()
        return true
    }
    func updateCharacter(name:String?=nil, hairStyleID:String?=nil, hairColorID:String?=nil, skinToneID:String?=nil, accessoryID:String?=nil) {
        if let name { let clean=name.trimmingCharacters(in:.whitespacesAndNewlines); if !clean.isEmpty { characterProfile.name=String(clean.prefix(18)) } }
        if let id=hairStyleID, hairStyles.contains(where:{$0.id==id}) { characterProfile.hairStyleID=id }
        if let id=hairColorID, hairColors.contains(where:{$0.id==id}) { characterProfile.hairColorID=id }
        if let id=skinToneID, skinTones.contains(where:{$0.id==id}) { characterProfile.skinToneID=id }
        if let id=accessoryID, accessories.contains(where:{$0.id==id}) { characterProfile.accessoryID=id }
        save()
    }
    @discardableResult func performInteraction(_ id:String, in roomID:String)->Bool {
        guard rooms.contains(where:{$0.id==roomID}) else{return false}
        switch (roomID,id) {
        case ("bedroom","sleep"): characterNeeds.energy=min(100,characterNeeds.energy+25); characterNeeds.hunger=max(0,characterNeeds.hunger-5)
        case ("living","dance"): characterNeeds.fun=min(100,characterNeeds.fun+20); characterNeeds.energy=max(0,characterNeeds.energy-5)
        case ("bathroom","shower"): characterNeeds.hygiene=min(100,characterNeeds.hygiene+25)
        case ("kitchen","snack"): characterNeeds.hunger=min(100,characterNeeds.hunger+25)
        case ("garden","play"): characterNeeds.fun=min(100,characterNeeds.fun+15); characterNeeds.energy=max(0,characterNeeds.energy-3)
        default:return false
        }
        let key = "\(roomID).\(id)"
        interactionCounts[key, default: 0] = min(Self.maxSavedCounter, interactionCounts[key, default: 0] + 1)
        if roomID == dailyRoomSurpriseRoomID && id == dailyRoomSurpriseAction { interactionCounts["roomSurprise.day\(dailyLifeProgress.day)"] = 1 }
        if id == "shower" || id == "sleep" { _ = advanceDailyChainIfMatching(id) }
        save(); return true
    }
    func interactionCount(_ id:String, in roomID:String)->Int { interactionCounts["\(roomID).\(id)", default:0] }
    var dayPhase: String { ["Morning","Afternoon","Evening"][min(2,max(0,dailyLifeProgress.phaseIndex))] }
    var dailyChainTitle: String { ["Fresh Start","Home Time","Cozy Finish"][min(2,max(0,dailyLifeProgress.chainStep))] }
    @discardableResult func advanceDayPhase()->Bool {
        if dailyLifeProgress.phaseIndex < 2 { dailyLifeProgress.phaseIndex += 1 }
        else { dailyLifeProgress.phaseIndex = 0; dailyLifeProgress.day = min(Self.maxSavedDay, dailyLifeProgress.day + 1); applyDailyNeedDecay() }
        save(); return true
    }
    var dailyChainAction: String { ["shower","decorate","sleep"][min(2,max(0,dailyLifeProgress.chainStep))] }
    var dailyChainDetail: String {
        switch dailyChainAction {
        case "shower": return "Take a shower in the bathroom"
        case "decorate": return "Place a decoration in any room"
        default: return "Sleep in the bedroom"
        }
    }
    @discardableResult func performDailyChainAction(_ action:String)->Bool {
        guard advanceDailyChainIfMatching(action) else{return false}
        save(); return true
    }
    @discardableResult private func advanceDailyChainIfMatching(_ action:String)->Bool {
        guard dailyLifeProgress.lastCompletedDay != dailyLifeProgress.day, action == dailyChainAction else{return false}
        dailyLifeProgress.phaseActionCounts["day\(dailyLifeProgress.day).\(action)",default:0] = min(Self.maxSavedCounter, dailyLifeProgress.phaseActionCounts["day\(dailyLifeProgress.day).\(action)",default:0] + 1)
        dailyLifeProgress.chainStep += 1
        if dailyLifeProgress.chainStep >= 3 {
            dailyLifeProgress.chainStep = 0
            let consecutive = dailyLifeProgress.lastCompletedDay == dailyLifeProgress.day - 1
            dailyLifeProgress.streak = consecutive ? min(Self.maxSavedCounter, dailyLifeProgress.streak + 1) : 1
            dailyLifeProgress.lastCompletedDay = dailyLifeProgress.day
            coins = Self.saturatedAdd(coins, 100 + min(100,min(10, dailyLifeProgress.streak) * 10)); stars = Self.saturatedAdd(stars, 2)
        }
        return true
    }
    private func applyDailyNeedDecay() {
        characterNeeds.energy=max(0,characterNeeds.energy-8); characterNeeds.fun=max(0,characterNeeds.fun-6)
        characterNeeds.hygiene=max(0,characterNeeds.hygiene-7); characterNeeds.hunger=max(0,characterNeeds.hunger-10)
        petNeeds.hunger=max(0,petNeeds.hunger-8); petNeeds.happiness=max(0,petNeeds.happiness-5); petNeeds.energy=max(0,petNeeds.energy-6)
    }
    func updatePet(name:String?=nil, species:String?=nil) {
        if let name { let clean=name.trimmingCharacters(in:.whitespacesAndNewlines); if !clean.isEmpty { petProfile.name=String(clean.prefix(14)) } }
        if let species, ["cat","dog"].contains(species) { petProfile.species=species }
        save()
    }
    @discardableResult func movePet(to roomID:String)->Bool { guard rooms.contains(where:{$0.id==roomID}) else{return false}; petProfile.roomID=roomID; save(); return true }
    @discardableResult func performGardenActivity(_ action:String)->Bool {
        switch action {
        case "swim":
            characterNeeds.fun=min(100,characterNeeds.fun+18); characterNeeds.hygiene=min(100,characterNeeds.hygiene+5); characterNeeds.energy=max(0,characterNeeds.energy-6); gardenProgress.poolVisits = min(Self.maxSavedCounter, gardenProgress.poolVisits + 1)
        case "lounge":
            characterNeeds.energy=min(100,characterNeeds.energy+18); gardenProgress.loungeVisits = min(Self.maxSavedCounter, gardenProgress.loungeVisits + 1)
        case "petPlay":
            guard petProfile.roomID == "garden" else{return false}
            characterNeeds.fun=min(100,characterNeeds.fun+10); petNeeds.happiness=min(100,petNeeds.happiness+18); petNeeds.energy=max(0,petNeeds.energy-4); gardenProgress.petPlayVisits = min(Self.maxSavedCounter, gardenProgress.petPlayVisits + 1)
        default:return false
        }
        interactionCounts["garden.\(action)",default:0] = min(Self.maxSavedCounter, interactionCounts["garden.\(action)",default:0] + 1); save(); return true
    }
    @discardableResult func careForPet(_ action:String)->Bool {
        switch action {
        case "feed": petNeeds.hunger=min(100,petNeeds.hunger+25)
        case "play": petNeeds.happiness=min(100,petNeeds.happiness+25); petNeeds.energy=max(0,petNeeds.energy-5)
        case "rest": petNeeds.energy=min(100,petNeeds.energy+25)
        default:return false
        }
        interactionCounts["pet.\(action)",default:0] = min(Self.maxSavedCounter, interactionCounts["pet.\(action)",default:0] + 1); save(); return true
    }

    func friendshipLevel(for friendID:String)->Int { max(1, min(10, friendshipXP(for: friendID) / 50 + 1)) }
    func friendshipXP(for friendID:String)->Int { max(0, socialProgress.friendshipXP[friendID, default:0]) }
    func hangoutCount(for friendID:String)->Int { max(0, socialProgress.hangouts[friendID, default:0]) }
    func friendQuestID(for friendID:String)->String { "friendquest.\(friendID).favorite3" }
    func friendQuestProgress(for friendID:String)->Int {
        guard let friend=friends.first(where:{$0.id==friendID}) else{return 0}
        return min(3, interactionCounts["social.\(friendID).\(friend.favoriteActivity)",default:0])
    }
    func isFriendQuestClaimed(_ friendID:String)->Bool { claimedFriendQuestIDs.contains(friendQuestID(for:friendID)) }
    @discardableResult func claimFriendQuest(_ friendID:String)->Bool {
        guard friends.contains(where:{$0.id==friendID}), friendQuestProgress(for:friendID)>=3, !isFriendQuestClaimed(friendID) else{return false}
        claimedFriendQuestIDs.insert(friendQuestID(for:friendID)); coins = Self.saturatedAdd(coins, 60); stars = Self.saturatedAdd(stars, 2); save(); return true
    }
    func friendStoryPartyID(for friendID:String)->String { "friendstory.\(friendID).party2" }
    func friendStoryPartyProgress(for friendID:String)->Int {
        guard friends.contains(where:{$0.id==friendID}), isFriendQuestClaimed(friendID) else{return 0}
        let tea=interactionCounts["social.\(friendID).teaParty",default:0]
        let talent=interactionCounts["social.\(friendID).talentShow",default:0]
        return min(2, tea + talent)
    }
    func isFriendStoryPartyClaimed(_ friendID:String)->Bool { claimedFriendQuestIDs.contains(friendStoryPartyID(for:friendID)) }
    @discardableResult func claimFriendStoryParty(_ friendID:String)->Bool {
        guard friends.contains(where:{$0.id==friendID}), isFriendQuestClaimed(friendID), friendStoryPartyProgress(for:friendID)>=2, !isFriendStoryPartyClaimed(friendID) else{return false}
        claimedFriendQuestIDs.insert(friendStoryPartyID(for:friendID)); coins = Self.saturatedAdd(coins, 80); stars = Self.saturatedAdd(stars, 3); save(); return true
    }
    func friendStoryRoomID(for friendID:String)->String { "friendstory.\(friendID).room3" }
    func friendStoryRoomTarget(for friendID:String)->String {
        switch friendID { case "luna": return "living"; case "rio": return "bedroom"; case "ivy": return "garden"; case "nova": return "bathroom"; case "milo": return "kitchen"; default: return "living" }
    }
    func friendStoryRoomProgress(for friendID:String)->Int {
        guard isFriendStoryPartyClaimed(friendID) else{return 0}
        return min(2, interactionCounts["storyroom.\(friendID)",default:0])
    }
    func isFriendStoryRoomClaimed(_ friendID:String)->Bool { claimedFriendQuestIDs.contains(friendStoryRoomID(for:friendID)) }
    @discardableResult func claimFriendStoryRoom(_ friendID:String)->Bool {
        guard friends.contains(where:{$0.id==friendID}), isFriendStoryPartyClaimed(friendID), friendStoryRoomProgress(for:friendID)>=2, !isFriendStoryRoomClaimed(friendID) else{return false}
        claimedFriendQuestIDs.insert(friendStoryRoomID(for:friendID)); coins = Self.saturatedAdd(coins, 100); stars = Self.saturatedAdd(stars, 4); save(); return true
    }
    func friendKeepsake(for friendID:String)->FriendKeepsake? {
        let values:[String:(String,String)] = [
            "luna":("Moonlight Music Box","music.note.house.fill"), "rio":("Rainbow Sketchbook","paintpalette.fill"),
            "ivy":("Tiny Garden Terrarium","leaf.circle.fill"), "nova":("Starlight Style Pin","sparkles"),
            "milo":("Sunny Recipe Tin","fork.knife.circle.fill")
        ]
        guard let value=values[friendID] else{return nil}
        return FriendKeepsake(id:"keepsake.\(friendID)",name:value.0,icon:value.1,friendID:friendID)
    }
    func isFriendKeepsakeClaimed(_ friendID:String)->Bool { claimedFriendQuestIDs.contains("keepsake.\(friendID)") }
    @discardableResult func claimFriendKeepsake(_ friendID:String)->Bool {
        guard friendKeepsake(for:friendID) != nil, isFriendStoryRoomClaimed(friendID), !isFriendKeepsakeClaimed(friendID) else{return false}
        claimedFriendQuestIDs.insert("keepsake.\(friendID)"); save(); return true
    }
    var ownedFriendKeepsakes:[FriendKeepsake] { friends.compactMap { isFriendKeepsakeClaimed($0.id) ? friendKeepsake(for:$0.id) : nil } }
    func displayedFriendKeepsakes(in roomID:String)->[FriendKeepsake] {
        guard rooms.contains(where:{$0.id==roomID}) else{return []}
        let ids=displayedKeepsakeIDsByRoom[roomID,default:[]]
        return ownedFriendKeepsakes.filter{ids.contains($0.id)}
    }
    func roomForDisplayedKeepsake(_ keepsakeID:String)->String? {
        displayedKeepsakeIDsByRoom.first(where: { $0.value.contains(keepsakeID) })?.key
    }
    @discardableResult func interactWithDisplayedKeepsake(_ keepsakeID:String, in roomID:String)->Bool {
        guard displayedKeepsakeIDsByRoom[roomID,default:[]].contains(keepsakeID),
              let keepsake=ownedFriendKeepsakes.first(where:{$0.id==keepsakeID}) else{return false}
        interactionCounts["keepsakeInteraction.\(keepsakeID)",default:0] = min(Self.maxSavedCounter, interactionCounts["keepsakeInteraction.\(keepsakeID)",default:0] + 1)
        interactionCounts[keepsakeDailyPrefix + keepsakeID] = 1
        // A small social payoff makes earned keepsakes feel alive without creating an economy exploit.
        socialProgress.friendshipXP[keepsake.friendID,default:0] = min(Self.maxSavedCounter, socialProgress.friendshipXP[keepsake.friendID,default:0] + 1)
        save(); return true
    }
    func keepsakeInteractionCount(_ keepsakeID:String)->Int { interactionCounts["keepsakeInteraction.\(keepsakeID)",default:0] }
    private var keepsakeDailyPrefix:String { "keepsakeDaily.day\(dailyLifeProgress.day)." }
    var dailyKeepsakeMemoryProgress:Int {
        min(2, ownedFriendKeepsakes.filter { interactionCounts[keepsakeDailyPrefix + $0.id, default:0] > 0 }.count)
    }
    var isDailyKeepsakeMemoryClaimed:Bool { interactionCounts["keepsakeDailyClaim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func claimDailyKeepsakeMemory()->Bool {
        guard dailyKeepsakeMemoryProgress >= 2, !isDailyKeepsakeMemoryClaimed else{return false}
        interactionCounts["keepsakeDailyClaim.day\(dailyLifeProgress.day)"] = 1; coins = Self.saturatedAdd(coins, 40); stars = Self.saturatedAdd(stars, 1); save(); return true
    }
    // A rotating daily spotlight gives the collection a changing purpose without relying on real-world time.
    var dailyMemorySpotlightKeepsake:FriendKeepsake? {
        let owned=ownedFriendKeepsakes.sorted{$0.id < $1.id}; guard !owned.isEmpty else{return nil}
        return owned[(dailyLifeProgress.day - 1) % owned.count]
    }
    var isDailyMemorySpotlightReady:Bool {
        guard let keepsake=dailyMemorySpotlightKeepsake else{return false}
        return interactionCounts[keepsakeDailyPrefix + keepsake.id,default:0] > 0
    }
    var isDailyMemorySpotlightClaimed:Bool { interactionCounts["keepsakeSpotlightClaim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func claimDailyMemorySpotlight()->Bool {
        guard isDailyMemorySpotlightReady, !isDailyMemorySpotlightClaimed else{return false}
        interactionCounts["keepsakeSpotlightClaim.day\(dailyLifeProgress.day)"] = 1; coins = Self.saturatedAdd(coins, 20); save(); return true
    }
    // After visiting today's keepsake, reunite with its friend in that keepsake's room and do their favorite activity.
    var dailyMemorySpotlightFriend:FriendProfile? {
        guard let keepsake=dailyMemorySpotlightKeepsake else{return nil}
        return friends.first(where:{$0.id==keepsake.friendID})
    }
    // v2.12 adds a lightweight room surprise that rotates through the house and rewards ordinary room play.
    var dailyRoomSurpriseRoomID:String { ["living","bedroom","kitchen","bathroom","garden"][(dailyLifeProgress.day - 1) % 5] }
    var dailyRoomSurpriseAction:String { ["dance","sleep","snack","shower","play"][(dailyLifeProgress.day - 1) % 5] }
    var dailyRoomSurpriseRoomName:String { rooms.first(where:{$0.id==dailyRoomSurpriseRoomID})?.name ?? "Room" }
    var isDailyRoomSurpriseReady:Bool { interactionCounts["roomSurprise.day\(dailyLifeProgress.day)",default:0] > 0 }
    var isDailyRoomSurpriseClaimed:Bool { interactionCounts["roomSurpriseClaim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func claimDailyRoomSurprise()->Bool {
        guard isDailyRoomSurpriseReady, !isDailyRoomSurpriseClaimed else{return false}
        interactionCounts["roomSurpriseClaim.day\(dailyLifeProgress.day)"] = 1; coins = Self.saturatedAdd(coins, 25); stars = Self.saturatedAdd(stars, 1); save(); return true
    }
    // v2.13 links the room discovery to a friend moment: discover it, bring today's buddy there, then do their favorite activity.
    var dailyRoomSurpriseBuddy:FriendProfile { friends[(dailyLifeProgress.day - 1) % friends.count] }
    var isDailyRoomSurpriseBuddyReady:Bool { interactionCounts["roomSurpriseBuddy.day\(dailyLifeProgress.day)",default:0] > 0 }
    var isDailyRoomSurpriseBuddyClaimed:Bool { interactionCounts["roomSurpriseBuddyClaim.day\(dailyLifeProgress.day)",default:0] > 0 }
    // v2.14 gives every surprise room its own story-flavoured buddy event and reward mix.
    var dailyRoomSurpriseBuddyEventTitle:String { ["Living Room Dance-Off","Bedroom Pillow Fort","Kitchen Taste Test","Bathroom Bubble Beats","Garden Treasure Hunt"][(dailyLifeProgress.day - 1) % 5] }
    var dailyRoomSurpriseBuddyReward:(coins:Int,stars:Int) { [(30,2),(45,1),(40,1),(35,2),(50,1)][(dailyLifeProgress.day - 1) % 5] }
    var dailyRoomSurpriseBuddyDetail:String { "\(dailyRoomSurpriseBuddyEventTitle): after finding the surprise, bring \(dailyRoomSurpriseBuddy.name) here and do \(dailyRoomSurpriseBuddy.favoriteActivity)." }
    let surpriseBadges = [
        SurpriseBadge(id:"badge.living",name:"Dance-Off Star",icon:"music.note",roomID:"living"),
        SurpriseBadge(id:"badge.bedroom",name:"Cozy Fort Builder",icon:"moon.stars.fill",roomID:"bedroom"),
        SurpriseBadge(id:"badge.kitchen",name:"Taste-Test Hero",icon:"fork.knife",roomID:"kitchen"),
        SurpriseBadge(id:"badge.bathroom",name:"Bubble Beat",icon:"drop.fill",roomID:"bathroom"),
        SurpriseBadge(id:"badge.garden",name:"Garden Explorer",icon:"leaf.fill",roomID:"garden")
    ]
    var earnedSurpriseBadges:[SurpriseBadge] { surpriseBadges.filter{claimedFriendQuestIDs.contains($0.id)} }
    var surpriseBadgeProgress:Int { earnedSurpriseBadges.count }
    var isSurpriseBadgeCollectionComplete:Bool { surpriseBadgeProgress == surpriseBadges.count }
    var isSurpriseBadgeCollectionRewardClaimed:Bool { claimedFriendQuestIDs.contains("badge.collection.complete") }
    func hasSurpriseBadge(for roomID:String)->Bool { claimedFriendQuestIDs.contains("badge.\(roomID)") }
    @discardableResult func claimSurpriseBadgeCollectionReward()->Bool {
        guard isSurpriseBadgeCollectionComplete, !isSurpriseBadgeCollectionRewardClaimed else { return false }
        claimedFriendQuestIDs.insert("badge.collection.complete"); coins = Self.saturatedAdd(coins, 150); stars = Self.saturatedAdd(stars, 5); save(); return true
    }
    // v2.17 turns the completed badge collection into a permanent, interactive house trophy.
    var isDreamHouseTrophyUnlocked:Bool { isSurpriseBadgeCollectionRewardClaimed }
    var dreamHouseTrophyVisitCount:Int { interactionCounts["trophy.dreamhouse.visits",default:0] }
    // v2.18 rewards repeated trophy visits with visible collection mastery milestones.
    var dreamHouseTrophyLevel:String {
        switch dreamHouseTrophyVisitCount { case 30...: return "Diamond"; case 15...: return "Gold"; case 5...: return "Silver"; default: return "Bronze" }
    }
    var dreamHouseTrophyNextMilestone:Int? { [5,15,30].first{ dreamHouseTrophyVisitCount < $0 } }
    var unlockedTrophyDecorations:[String] {
        var items:[String]=[]
        if dreamHouseTrophyVisitCount >= 5 { items.append("Sparkle Garland") }
        if dreamHouseTrophyVisitCount >= 15 { items.append("Memory Pedestal") }
        if dreamHouseTrophyVisitCount >= 30 { items.append("Dreamlight Crown") }
        return items
    }
    @discardableResult func interactWithDreamHouseTrophy(in roomID:String)->Bool {
        guard isDreamHouseTrophyUnlocked, roomID == "living" else { return false }
        interactionCounts["trophy.dreamhouse.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.dreamhouse.visits",default:0] + 1)
        characterNeeds.fun = min(100, characterNeeds.fun + 4)
        save(); return true
    }
    // v2.19 makes Trophy Mastery rewards tangible, interactive Living Room decorations.
    var trophyDecorationIcons:[String:String] { ["Sparkle Garland":"sparkles","Memory Pedestal":"photo.on.rectangle.angled","Dreamlight Crown":"crown.fill"] }
    @discardableResult func interactWithTrophyDecoration(_ name:String,in roomID:String)->Bool {
        guard roomID == "living", unlockedTrophyDecorations.contains(name) else { return false }
        let dailyBaselineKey = "trophy.daily.baseline.day\(dailyLifeProgress.day).\(name)"
        if interactionCounts[dailyBaselineKey] == nil { interactionCounts[dailyBaselineKey] = trophyDecorationVisitCount(name) }
        interactionCounts["trophy.decor.\(name).visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.decor.\(name).visits",default:0] + 1)
        interactionCounts["trophy.combo.touch.day\(dailyLifeProgress.day).\(name)"] = 1
        switch name {
        case "Sparkle Garland": characterNeeds.fun = min(100,characterNeeds.fun + 2)
        case "Memory Pedestal": characterNeeds.energy = min(100,characterNeeds.energy + 2)
        case "Dreamlight Crown": characterNeeds.fun = min(100,characterNeeds.fun + 3); characterNeeds.energy = min(100,characterNeeds.energy + 1)
        default: return false
        }
        save(); return true
    }
    func trophyDecorationVisitCount(_ name:String)->Int { interactionCounts["trophy.decor.\(name).visits",default:0] }
    // v2.20 links Trophy decorations into a lightweight daily collection loop.
    var dailyTrophyDecorationName:String? {
        guard !unlockedTrophyDecorations.isEmpty else { return nil }
        return unlockedTrophyDecorations[(dailyLifeProgress.day - 1) % unlockedTrophyDecorations.count]
    }
    var isDailyTrophyDecorationClaimed:Bool { interactionCounts["trophy.daily.claim.day\(dailyLifeProgress.day)",default:0] > 0 }
    var dailyTrophyDecorationDetail:String {
        guard let name=dailyTrophyDecorationName else { return "Unlock a Trophy Mastery decoration to begin daily collection moments." }
        return "Interact with \(name) in the Living Room for today's collection bonus."
    }
    @discardableResult func claimDailyTrophyDecorationBonus()->Bool {
        guard let name=dailyTrophyDecorationName, !isDailyTrophyDecorationClaimed, trophyDecorationVisitCount(name) > interactionCounts["trophy.daily.baseline.day\(dailyLifeProgress.day).\(name)",default:0] else { return false }
        interactionCounts["trophy.daily.claim.day\(dailyLifeProgress.day)"] = 1
        coins = Self.saturatedAdd(coins, 20); stars = Self.saturatedAdd(stars, 1); save(); return true
    }
    // v2.21 adds rotating two-decoration Combo Moments for long-term Trophy Mastery play.
    var dailyTrophyComboDecorations:[String] {
        let available=unlockedTrophyDecorations
        guard available.count >= 2 else { return [] }
        let start=(dailyLifeProgress.day - 1) % available.count
        return [available[start], available[(start + 1) % available.count]]
    }
    var dailyTrophyComboTitle:String {
        let pair=dailyTrophyComboDecorations
        guard pair.count == 2 else { return "Unlock two Trophy decorations to discover Combo Moments." }
        return "\(pair[0]) + \(pair[1]) Combo Moment"
    }
    var isDailyTrophyComboReady:Bool {
        let pair=dailyTrophyComboDecorations
        return pair.count == 2 && pair.allSatisfy { interactionCounts["trophy.combo.touch.day\(dailyLifeProgress.day).\($0)",default:0] > 0 }
    }
    var isDailyTrophyComboClaimed:Bool { interactionCounts["trophy.combo.claim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func claimDailyTrophyComboBonus()->Bool {
        guard isDailyTrophyComboReady, !isDailyTrophyComboClaimed else { return false }
        interactionCounts["trophy.combo.claim.day\(dailyLifeProgress.day)"] = 1
        coins = Self.saturatedAdd(coins, 35); stars = Self.saturatedAdd(stars, 1); characterNeeds.fun=min(100,characterNeeds.fun+2); save(); return true
    }
    // v2.22 adds a weekly three-decoration finale after three daily Combo Moments.
    var weeklyTrophyChainWeek:Int { max(1,(dailyLifeProgress.day - 1) / 7 + 1) }
    var weeklyTrophyChainProgress:Int {
        let first=(weeklyTrophyChainWeek - 1) * 7 + 1
        return (first...min(first + 6,dailyLifeProgress.day)).filter { interactionCounts["trophy.combo.claim.day\($0)",default:0] > 0 }.count
    }
    var isWeeklyTrophyFinaleReady:Bool { unlockedTrophyDecorations.count == 3 && weeklyTrophyChainProgress >= 3 }
    var isWeeklyTrophyFinaleClaimed:Bool { interactionCounts["trophy.weekly.claim.week\(weeklyTrophyChainWeek)",default:0] > 0 }
    var isAuroraMobileUnlocked:Bool { interactionCounts["trophy.auroraMobile.unlocked",default:0] > 0 }
    @discardableResult func claimWeeklyTrophyFinale()->Bool {
        guard isWeeklyTrophyFinaleReady, !isWeeklyTrophyFinaleClaimed else { return false }
        interactionCounts["trophy.weekly.claim.week\(weeklyTrophyChainWeek)"] = 1
        interactionCounts["trophy.auroraMobile.unlocked"] = 1
        coins = Self.saturatedAdd(coins, 100); stars = Self.saturatedAdd(stars, 3); characterNeeds.fun=min(100,characterNeeds.fun+5); save(); return true
    }
    @discardableResult func interactWithAuroraMobile(in roomID:String)->Bool {
        guard isAuroraMobileUnlocked, roomID == "living" else { return false }
        interactionCounts["trophy.auroraMobile.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.auroraMobile.visits",default:0] + 1)
        characterNeeds.energy=min(100,characterNeeds.energy+2); characterNeeds.fun=min(100,characterNeeds.fun+2); save(); return true
    }
    // v2.23 turns Aurora Mobile into a three-day weekly interaction chain.
    var auroraWeeklyInteractionProgress:Int {
        let first=(weeklyTrophyChainWeek - 1) * 7 + 1
        return (first...min(first + 6,dailyLifeProgress.day)).filter { interactionCounts["trophy.auroraMobile.day\($0)",default:0] > 0 }.count
    }
    var isAuroraWeeklyRewardReady:Bool { isAuroraMobileUnlocked && auroraWeeklyInteractionProgress >= 3 }
    var isAuroraWeeklyRewardClaimed:Bool { interactionCounts["trophy.auroraMobile.weekly.claim.week\(weeklyTrophyChainWeek)",default:0] > 0 }
    var isPrismCharmUnlocked:Bool { interactionCounts["trophy.prismCharm.unlocked",default:0] > 0 }
    var auroraCharacterReaction:String {
        switch auroraWeeklyInteractionProgress { case 0: return "The mobile is waiting for its first shimmer."; case 1: return "A soft rainbow dances across the room."; case 2: return "The colors swirl brighter together."; default: return "A prism sparkle fills the whole room!" }
    }
    @discardableResult func recordAuroraDailyInteraction()->Bool {
        guard isAuroraMobileUnlocked else { return false }
        let key="trophy.auroraMobile.day\(dailyLifeProgress.day)"
        guard interactionCounts[key,default:0] == 0 else { return false }
        interactionCounts[key]=1; save(); return true
    }
    @discardableResult func claimAuroraWeeklyReward()->Bool {
        guard isAuroraWeeklyRewardReady, !isAuroraWeeklyRewardClaimed else { return false }
        interactionCounts["trophy.auroraMobile.weekly.claim.week\(weeklyTrophyChainWeek)"]=1
        interactionCounts["trophy.prismCharm.unlocked"]=1
        coins = Self.saturatedAdd(coins, 60); stars = Self.saturatedAdd(stars, 2); save(); return true
    }
    // v2.24 makes Prism Charm interactive and adds a daily Aurora + Prism combo moment.
    var prismCharmVisitCount:Int { interactionCounts["trophy.prismCharm.visits",default:0] }
    var isAuroraPrismComboReady:Bool {
        isPrismCharmUnlocked && interactionCounts["trophy.auroraMobile.day\(dailyLifeProgress.day)",default:0] > 0 && interactionCounts["trophy.prismCharm.day\(dailyLifeProgress.day)",default:0] > 0
    }
    var isAuroraPrismComboClaimed:Bool { interactionCounts["trophy.auroraPrism.claim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func interactWithPrismCharm(in roomID:String)->Bool {
        guard isPrismCharmUnlocked, roomID == "living" else { return false }
        interactionCounts["trophy.prismCharm.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.prismCharm.visits",default:0] + 1)
        interactionCounts["trophy.prismCharm.day\(dailyLifeProgress.day)"] = 1
        characterNeeds.fun=min(100,characterNeeds.fun+2); save(); return true
    }
    @discardableResult func claimAuroraPrismCombo()->Bool {
        guard isAuroraPrismComboReady, !isAuroraPrismComboClaimed else { return false }
        interactionCounts["trophy.auroraPrism.claim.day\(dailyLifeProgress.day)"] = 1
        interactionCounts["trophy.auroraPrism.achievement"] = 1
        coins = Self.saturatedAdd(coins, 45); stars = Self.saturatedAdd(stars, 2); characterNeeds.energy=min(100,characterNeeds.energy+2); save(); return true
    }
    // v2.25 expands Aurora + Prism into a persistent collection series and weekly chain.
    var auroraPrismCollectionCount:Int {
        interactionCounts.keys.filter { $0.hasPrefix("trophy.auroraPrism.claim.day") && interactionCounts[$0,default:0] > 0 }.count
    }
    var auroraPrismCollectionTier:String {
        switch auroraPrismCollectionCount { case 0...2: return "Glow Seeker"; case 3...6: return "Prism Keeper"; case 7...13: return "Aurora Curator"; default: return "Radiant Master" }
    }
    var weeklyAuroraPrismProgress:Int {
        let first=(weeklyTrophyChainWeek - 1) * 7 + 1
        return (first...min(first + 6,dailyLifeProgress.day)).filter { interactionCounts["trophy.auroraPrism.claim.day\($0)",default:0] > 0 }.count
    }
    var isStarlightSuncatcherUnlocked:Bool { interactionCounts["trophy.starlightSuncatcher.unlocked",default:0] > 0 }
    var isAuroraPrismSeriesRewardReady:Bool { auroraPrismCollectionCount >= 3 && !isStarlightSuncatcherUnlocked }
    @discardableResult func claimAuroraPrismSeriesReward()->Bool {
        guard isAuroraPrismSeriesRewardReady else { return false }
        interactionCounts["trophy.starlightSuncatcher.unlocked"] = 1
        coins = Self.saturatedAdd(coins, 75); stars = Self.saturatedAdd(stars, 3); save(); return true
    }
    @discardableResult func interactWithStarlightSuncatcher(in roomID:String)->Bool {
        guard isStarlightSuncatcherUnlocked, roomID == "living" else { return false }
        interactionCounts["trophy.starlightSuncatcher.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.starlightSuncatcher.visits",default:0] + 1)
        characterNeeds.energy=min(100,characterNeeds.energy+2); characterNeeds.fun=min(100,characterNeeds.fun+3); recordRadiantRoomEventStep(1); save(); return true
    }
    // v2.26 adds higher Radiant Collection milestones and a complete-set bonus.
    var isMoonbeamTerrariumUnlocked:Bool { interactionCounts["trophy.moonbeamTerrarium.unlocked",default:0] > 0 }
    var isCelestialLanternUnlocked:Bool { interactionCounts["trophy.celestialLantern.unlocked",default:0] > 0 }
    var isMoonbeamTerrariumRewardReady:Bool { auroraPrismCollectionCount >= 7 && !isMoonbeamTerrariumUnlocked }
    var isCelestialLanternRewardReady:Bool { auroraPrismCollectionCount >= 14 && !isCelestialLanternUnlocked }
    var isRadiantSetComplete:Bool { isStarlightSuncatcherUnlocked && isMoonbeamTerrariumUnlocked && isCelestialLanternUnlocked }
    var isRadiantSetBonusClaimed:Bool { interactionCounts["trophy.radiantSet.claimed",default:0] > 0 }
    @discardableResult func claimMoonbeamTerrariumReward()->Bool {
        guard isMoonbeamTerrariumRewardReady else { return false }; interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; coins = Self.saturatedAdd(coins, 125); stars = Self.saturatedAdd(stars, 4); save(); return true
    }
    @discardableResult func claimCelestialLanternReward()->Bool {
        guard isCelestialLanternRewardReady else { return false }; interactionCounts["trophy.celestialLantern.unlocked"]=1; coins = Self.saturatedAdd(coins, 200); stars = Self.saturatedAdd(stars, 6); save(); return true
    }
    @discardableResult func claimRadiantSetBonus()->Bool {
        guard isRadiantSetComplete, !isRadiantSetBonusClaimed else { return false }; interactionCounts["trophy.radiantSet.claimed"]=1; coins = Self.saturatedAdd(coins, 250); stars = Self.saturatedAdd(stars, 8); characterNeeds.fun=min(100,characterNeeds.fun+5); characterNeeds.energy=min(100,characterNeeds.energy+5); save(); return true
    }
    @discardableResult func interactWithMoonbeamTerrarium(in roomID:String)->Bool {
        guard isMoonbeamTerrariumUnlocked, roomID == "living" else { return false }; interactionCounts["trophy.moonbeamTerrarium.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.moonbeamTerrarium.visits",default:0] + 1); characterNeeds.energy=min(100,characterNeeds.energy+3); recordRadiantRoomEventStep(2); save(); return true
    }
    @discardableResult func interactWithCelestialLantern(in roomID:String)->Bool {
        guard isCelestialLanternUnlocked, roomID == "living" else { return false }; interactionCounts["trophy.celestialLantern.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.celestialLantern.visits",default:0] + 1); characterNeeds.fun=min(100,characterNeeds.fun+4); recordRadiantRoomEventStep(3); save(); return true
    }
    @discardableResult func claimDailyRoomSurpriseBuddy()->Bool {
        guard isDailyRoomSurpriseBuddyReady, !isDailyRoomSurpriseBuddyClaimed else{return false}
        let reward=dailyRoomSurpriseBuddyReward
        interactionCounts["roomSurpriseBuddyClaim.day\(dailyLifeProgress.day)"] = 1; claimedFriendQuestIDs.insert("badge.\(dailyRoomSurpriseRoomID)"); coins = Self.saturatedAdd(coins, reward.coins); stars = Self.saturatedAdd(stars, reward.stars); save(); return true
    }
    // v2.11 rotates three social challenge templates so the daily loop does not repeat the same action every day.
    var dailySpotlightFriendChallengeKind:String { ["favorite","decorate","teaParty"][(dailyLifeProgress.day - 1) % 3] }
    var dailySpotlightFriendChallengeAction:String? {
        guard let friend=dailyMemorySpotlightFriend else{return nil}
        switch dailySpotlightFriendChallengeKind { case "favorite": return friend.favoriteActivity; case "decorate": return "decorate"; default: return "teaParty" }
    }
    var dailySpotlightFriendChallengeDetail:String {
        guard let friend=dailyMemorySpotlightFriend, let action=dailySpotlightFriendChallengeAction else{return "Earn and display a friendship keepsake to unlock today's challenge."}
        return "Visit today's keepsake, bring \(friend.name) to its room, then \(action == "teaParty" ? "host a Tea Party" : "do \(action)")."
    }
    var isDailySpotlightFriendMomentReady:Bool { interactionCounts["spotlightFriendMoment.day\(dailyLifeProgress.day)",default:0] > 0 }
    var isDailySpotlightFriendMomentClaimed:Bool { interactionCounts["spotlightFriendMomentClaim.day\(dailyLifeProgress.day)",default:0] > 0 }
    @discardableResult func claimDailySpotlightFriendMoment()->Bool {
        guard isDailySpotlightFriendMomentReady, !isDailySpotlightFriendMomentClaimed else{return false}
        interactionCounts["spotlightFriendMomentClaim.day\(dailyLifeProgress.day)"] = 1; coins = Self.saturatedAdd(coins, 30); stars = Self.saturatedAdd(stars, 1); save(); return true
    }
    @discardableResult func setFriendKeepsake(_ keepsakeID:String, displayed:Bool, in roomID:String)->Bool {
        guard rooms.contains(where:{$0.id==roomID}), ownedFriendKeepsakes.contains(where:{$0.id==keepsakeID}) else{return false}
        // A keepsake can be displayed in one room at a time so the collection stays easy to understand.
        for key in Array(displayedKeepsakeIDsByRoom.keys) { displayedKeepsakeIDsByRoom[key]?.remove(keepsakeID) }
        if displayed { displayedKeepsakeIDsByRoom[roomID,default:[]].insert(keepsakeID) }
        displayedKeepsakeIDsByRoom=displayedKeepsakeIDsByRoom.filter{!$0.value.isEmpty}
        save(); return true
    }
    @discardableResult func inviteFriend(_ friendID:String)->Bool {
        guard friends.contains(where:{$0.id==friendID}) else{return false}
        socialProgress.activeFriendID=friendID; socialProgress.friendRoomID="living"; save(); return true
    }
    @discardableResult func moveFriend(to roomID:String)->Bool {
        guard socialProgress.activeFriendID != nil, rooms.contains(where:{$0.id==roomID}) else{return false}
        socialProgress.friendRoomID=roomID; save(); return true
    }
    var activeFriend: FriendProfile? { friends.first(where:{$0.id==socialProgress.activeFriendID}) }
    func unlockedFriendActivities(for friendID:String)->[String] {
        let level=friendshipLevel(for:friendID); var result=["dance","decorate","garden","style","cook"]
        if level >= 2 { result.append("teaParty") }; if level >= 3 { result.append("talentShow") }; return result
    }
    @discardableResult func playFriendMiniGame(_ action:String, with friendID:String)->Bool {
        guard let friend=friends.first(where:{$0.id==friendID}), socialProgress.activeFriendID==friendID else{return false}
        guard unlockedFriendActivities(for:friendID).contains(action), ["teaParty","talentShow"].contains(action) else{return false}
        let gain = action == "talentShow" ? 35 : 22
        socialProgress.friendshipXP[friendID,default:0] = min(Self.maxSavedCounter, socialProgress.friendshipXP[friendID,default:0] + gain); socialProgress.hangouts[friendID,default:0] = min(Self.maxSavedCounter, socialProgress.hangouts[friendID,default:0] + 1); socialProgress.partyWins = min(Self.maxSavedCounter, socialProgress.partyWins + 1)
        interactionCounts["social.\(friend.id).\(action)",default:0] = min(Self.maxSavedCounter, interactionCounts["social.\(friend.id).\(action)",default:0] + 1)
        if let spotlight=dailyMemorySpotlightKeepsake, spotlight.friendID == friendID, isDailyMemorySpotlightReady, socialProgress.friendRoomID == roomForDisplayedKeepsake(spotlight.id), dailySpotlightFriendChallengeAction == action { interactionCounts["spotlightFriendMoment.day\(dailyLifeProgress.day)"] = 1 }
        coins = Self.saturatedAdd(coins, action == "talentShow" ? 25 : 15); stars = Self.saturatedAdd(stars, 1); save(); return true
    }
    @discardableResult func socialActivity(_ action:String, with friendID:String)->Bool {
        guard let friend=friends.first(where:{$0.id==friendID}), socialProgress.activeFriendID==friendID else{return false}
        let valid=["dance","decorate","garden","style","cook"]
        guard valid.contains(action) else{return false}
        var gain = action == friend.favoriteActivity ? 25 : 12
        if action == "garden" && petProfile.roomID == "garden" { gain += 5 }
        if action == "style" && ownedOutfitIDs.count >= 2 { gain += 5 }
        if action == "cook" && !cookedRecipes.isEmpty { gain += 5 }
        socialProgress.friendshipXP[friendID,default:0] = min(Self.maxSavedCounter, socialProgress.friendshipXP[friendID,default:0] + gain)
        socialProgress.hangouts[friendID,default:0] = min(Self.maxSavedCounter, socialProgress.hangouts[friendID,default:0] + 1)
        interactionCounts["social.\(friendID).\(action)",default:0] = min(Self.maxSavedCounter, interactionCounts["social.\(friendID).\(action)",default:0] + 1)
        if let spotlight=dailyMemorySpotlightKeepsake, spotlight.friendID == friendID, isDailyMemorySpotlightReady, socialProgress.friendRoomID == roomForDisplayedKeepsake(spotlight.id), dailySpotlightFriendChallengeAction == action { interactionCounts["spotlightFriendMoment.day\(dailyLifeProgress.day)"] = 1 }
        if isDailyRoomSurpriseReady, dailyRoomSurpriseBuddy.id == friendID, socialProgress.friendRoomID == dailyRoomSurpriseRoomID, action == dailyRoomSurpriseBuddy.favoriteActivity { interactionCounts["roomSurpriseBuddy.day\(dailyLifeProgress.day)"] = 1 }
        if isFriendStoryPartyClaimed(friendID), !isFriendStoryRoomClaimed(friendID), socialProgress.friendRoomID == friendStoryRoomTarget(for:friendID), action == friend.favoriteActivity { interactionCounts["storyroom.\(friendID)",default:0] = min(Self.maxSavedCounter, interactionCounts["storyroom.\(friendID)",default:0] + 1) }
        coins = Self.saturatedAdd(coins, action == friend.favoriteActivity ? 15 : 5)
        save(); return true
    }
    // v2.27: a same-day, ordered Radiant Room Event using the complete three-piece set.
    var radiantRoomEventStep:Int { interactionCounts["trophy.radiantEvent.step.day\(dailyLifeProgress.day)",default:0] }
    var isRadiantRoomEventReady:Bool { isRadiantSetComplete && radiantRoomEventStep >= 3 && !isRadiantRoomEventClaimedToday }
    var isRadiantRoomEventClaimedToday:Bool { interactionCounts["trophy.radiantEvent.claim.day\(dailyLifeProgress.day)",default:0] > 0 }
    var isRadiantChimeBonusReady:Bool { isRadiantChimeUnlocked && radiantRoomEventStep >= 4 && !isRadiantRoomEventClaimedToday }
    var radiantRoomAtmosphere:String {
        switch radiantRoomEventStep { case 1: return "Starwash"; case 2: return "Moonmist"; case 3: return "Celestial Glow"; case 4...: return "Chime Cascade"; default: return "Cozy Daylight" }
    }
    var radiantRoomEventReaction:String {
        switch radiantRoomEventStep { case 1: return "The sun-catcher paints tiny stars across the room."; case 2: return "Moonlight joins the colors — one sparkle remains."; case 3: return isRadiantChimeUnlocked ? "Event ready — ring the Radiant Chime for a bonus finale." : "Radiant Room Event ready! The whole room is glowing."; case 4...: return "Chime Cascade ready! Claim the enhanced Radiant Room reward."; default: return "Use Starlight → Moonbeam → Celestial in order." }
    }
    private func recordRadiantRoomEventStep(_ expected:Int) {
        guard isRadiantSetComplete, !isRadiantRoomEventClaimedToday else { return }
        let key="trophy.radiantEvent.step.day\(dailyLifeProgress.day)"
        let current=interactionCounts[key,default:0]
        if expected == current + 1 { interactionCounts[key]=expected }
        else if expected == 1 { interactionCounts[key]=1 }
        else { interactionCounts[key]=0 }
    }
    // v2.28: long-term mastery for repeated Radiant Room Events.
    var radiantRoomEventAchievementCount:Int { interactionCounts["trophy.radiantEvent.achievement",default:0] }
    var radiantRoomEventMasteryTier:String {
        switch radiantRoomEventAchievementCount { case 0...1: return "First Glow"; case 2...4: return "Room Illuminator"; case 5...9: return "Radiant Host"; default: return "Lightkeeper" }
    }
    var isRadiantChimeUnlocked:Bool { interactionCounts["trophy.radiantChime.unlocked",default:0] > 0 }
    var isRadiantChimeRewardReady:Bool { radiantRoomEventAchievementCount >= 5 && !isRadiantChimeUnlocked }
    var isLumenCanopyUnlocked:Bool { interactionCounts["trophy.lumenCanopy.unlocked",default:0] > 0 }
    var isLightkeeperRewardReady:Bool { radiantRoomEventAchievementCount >= 10 && !isLumenCanopyUnlocked }
    @discardableResult func claimRadiantChimeReward()->Bool {
        guard isRadiantChimeRewardReady else { return false }; interactionCounts["trophy.radiantChime.unlocked"]=1; coins = Self.saturatedAdd(coins, 140); stars = Self.saturatedAdd(stars, 5); save(); return true
    }
    @discardableResult func interactWithRadiantChime(in roomID:String)->Bool {
        guard isRadiantChimeUnlocked, roomID == "living" else { return false }; interactionCounts["trophy.radiantChime.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.radiantChime.visits",default:0] + 1); interactionCounts["trophy.radiantChime.day\(dailyLifeProgress.day)"]=1; characterNeeds.fun=min(100,characterNeeds.fun+2); characterNeeds.energy=min(100,characterNeeds.energy+3); recordRadiantRoomEventStep(4); save(); return true
    }
    @discardableResult func claimLightkeeperReward()->Bool {
        guard isLightkeeperRewardReady else { return false }; interactionCounts["trophy.lumenCanopy.unlocked"]=1; coins = Self.saturatedAdd(coins, 220); stars = Self.saturatedAdd(stars, 7); save(); return true
    }
    // v2.30: Lightkeeper weekly chain — Chime followed by Lumen Canopy on three distinct days.
    var isLightkeeperMomentReady:Bool { isRadiantChimeUnlocked && isLumenCanopyUnlocked && interactionCounts["trophy.radiantChime.day\(dailyLifeProgress.day)",default:0] > 0 && !isLightkeeperMomentClaimedToday }
    var isLightkeeperMomentClaimedToday:Bool { interactionCounts["trophy.lightkeeperMoment.day\(dailyLifeProgress.day)",default:0] > 0 }
    var weeklyLightkeeperProgress:Int { let start=((max(1,dailyLifeProgress.day)-1)/7)*7+1; return (start...(start+6)).filter{interactionCounts["trophy.lightkeeperMoment.day\($0)",default:0] > 0}.count }
    var isWeeklyLightkeeperRewardClaimed:Bool { interactionCounts["trophy.lightkeeperWeekly.week\((max(1,dailyLifeProgress.day)-1)/7)",default:0] > 0 }
    var isWeeklyLightkeeperRewardReady:Bool { weeklyLightkeeperProgress >= 3 && !isWeeklyLightkeeperRewardClaimed }
    // v2.31: consecutive completed-week streak. A streak only includes claimed weekly rewards,
    // so merely completing daily moments cannot inflate milestone progress.
    var currentLightkeeperWeek:Int { (max(1,dailyLifeProgress.day)-1)/7 }
    var lightkeeperWeeklyStreak:Int {
        guard isWeeklyLightkeeperRewardClaimed else { return 0 }
        var streak=0, week=currentLightkeeperWeek
        while week >= 0 && interactionCounts["trophy.lightkeeperWeekly.week\(week)",default:0] > 0 { streak += 1; week -= 1 }
        return streak
    }
    var isLightkeeperStreak2Claimed:Bool { interactionCounts["trophy.lightkeeperStreak.reward2",default:0] > 0 }
    var isLightkeeperStreak4Claimed:Bool { interactionCounts["trophy.lightkeeperStreak.reward4",default:0] > 0 }
    var isLightkeeperStreak2Ready:Bool { lightkeeperWeeklyStreak >= 2 && !isLightkeeperStreak2Claimed }
    var isLightkeeperStreak4Ready:Bool { lightkeeperWeeklyStreak >= 4 && !isLightkeeperStreak4Claimed }
    @discardableResult func claimLightkeeperStreak2Reward()->Bool {
        guard isLightkeeperStreak2Ready else { return false }; interactionCounts["trophy.lightkeeperStreak.reward2"]=1; coins = Self.saturatedAdd(coins, 125); stars = Self.saturatedAdd(stars, 4); save(); return true
    }
    @discardableResult func claimLightkeeperStreak4Reward()->Bool {
        guard isLightkeeperStreak4Ready else { return false }; interactionCounts["trophy.lightkeeperStreak.reward4"]=1; coins = Self.saturatedAdd(coins, 300); stars = Self.saturatedAdd(stars, 10); interactionCounts["trophy.lightkeeperStreak.crown"]=1; save(); return true
    }
    var hasLightkeeperStreakCrown:Bool { interactionCounts["trophy.lightkeeperStreak.crown",default:0] > 0 }
    // v2.32: the streak crown is a wearable accessory and creates a daily Crown + Canopy moment.
    var isStarlightCrownEquipped:Bool { characterProfile.accessoryID == "starlightCrown" && hasLightkeeperStreakCrown }
    var isCrownCanopyMomentClaimedToday:Bool { interactionCounts["trophy.crownCanopy.day\(dailyLifeProgress.day)",default:0] > 0 }
    var crownCanopyAchievementCount:Int { interactionCounts["trophy.crownCanopy.achievement",default:0] }
    var crownCanopyCollectionTitle:String {
        switch crownCanopyAchievementCount { case 0: return "Waiting for Starlight"; case 1...2: return "Crown Spark"; case 3...6: return "Canopy Keeper"; default: return "Starlight Guardian" }
    }
    // v2.33: a Crown Spark is earned once per game day by wearing the Crown
    // while visiting Lumen Canopy. Weekly challenges count distinct game days.
    var weeklyCrownSparkProgress:Int {
        let start=currentLightkeeperWeek*7+1
        return (start...(start+6)).filter { interactionCounts["trophy.crownCanopy.day\($0)",default:0] > 0 }.count
    }
    var isWeeklyCrownSparkClaimed:Bool { interactionCounts["trophy.crownSparkWeekly.week\(currentLightkeeperWeek)",default:0] > 0 }
    var isWeeklyCrownSparkReady:Bool {
        hasLightkeeperStreakCrown && isLumenCanopyUnlocked && weeklyCrownSparkProgress >= 3 && !isWeeklyCrownSparkClaimed
    }
    @discardableResult func claimWeeklyCrownSparkReward()->Bool {
        guard isWeeklyCrownSparkReady else { return false }
        interactionCounts["trophy.crownSparkWeekly.week\(currentLightkeeperWeek)"]=1
        coins = Self.saturatedAdd(coins, 150); stars = Self.saturatedAdd(stars, 5)
        characterNeeds.fun=min(100,characterNeeds.fun+3)
        characterNeeds.energy=min(100,characterNeeds.energy+3)
        save(); return true
    }
    var isCometVeilUnlocked:Bool { interactionCounts["trophy.crownCanopy.cometVeil",default:0] > 0 }
    var isCometVeilRewardReady:Bool { hasLightkeeperStreakCrown && crownCanopyAchievementCount >= 7 && !isCometVeilUnlocked }
    @discardableResult func claimCometVeilReward()->Bool {
        guard isCometVeilRewardReady else { return false }
        interactionCounts["trophy.crownCanopy.cometVeil"]=1
        coins = Self.saturatedAdd(coins, 160); stars = Self.saturatedAdd(stars, 5)
        save(); return true
    }
    var isCometVeilEquipped:Bool { characterProfile.accessoryID == "cometVeil" && isCometVeilUnlocked }

    // v2.34: count *claimed* weekly Crown Spark rewards, not daily progress.
    // Legacy v2.33 save keys are retained so no save migration is required.
    var crownSparkWeeksCollected:Int {
        let prefix = "trophy.crownSparkWeekly.week"
        return interactionCounts.filter { key, count in
            guard count > 0, key.hasPrefix(prefix),
                  let week = Int(key.dropFirst(prefix.count)) else { return false }
            return week >= 0 && week <= currentLightkeeperWeek
        }.count
    }
    var crownSparkWeeklyCollectionTier:String {
        switch crownSparkWeeksCollected {
        case 0: return "First Spark"
        case 1...2: return "Shimmer Keeper"
        case 3...5: return "Comet Collector"
        default: return "Skyward Legend"
        }
    }
    var isCometHaloUnlocked:Bool { interactionCounts["trophy.crownSparkWeekly.cometHalo",default:0] > 0 }
    var isCometHaloRewardReady:Bool { crownSparkWeeksCollected >= 3 && !isCometHaloUnlocked }
    @discardableResult func claimCometHaloReward()->Bool {
        guard isCometHaloRewardReady else { return false }
        interactionCounts["trophy.crownSparkWeekly.cometHalo"] = 1
        coins = Self.saturatedAdd(coins, 110); stars = Self.saturatedAdd(stars, 4)
        save(); return true
    }
    @discardableResult func interactWithCometHalo(in roomID:String)->Bool {
        guard isCometHaloUnlocked, roomID == "living" else { return false }
        interactionCounts["trophy.crownSparkWeekly.cometHalo.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.crownSparkWeekly.cometHalo.visits",default:0] + 1)
        characterNeeds.fun = min(100,characterNeeds.fun+2)
        characterNeeds.energy = min(100,characterNeeds.energy+2)
        save(); return true
    }

    @discardableResult func interactWithLumenCanopy(in roomID:String)->Bool {
        guard isLumenCanopyUnlocked, roomID == "living" else { return false }; interactionCounts["trophy.lumenCanopy.visits",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.lumenCanopy.visits",default:0] + 1); characterNeeds.fun=min(100,characterNeeds.fun+3); characterNeeds.energy=min(100,characterNeeds.energy+4)
        if isLightkeeperMomentReady { interactionCounts["trophy.lightkeeperMoment.day\(dailyLifeProgress.day)"]=1 }
        if isStarlightCrownEquipped && !isCrownCanopyMomentClaimedToday {
            interactionCounts["trophy.crownCanopy.day\(dailyLifeProgress.day)"]=1
            interactionCounts["trophy.crownCanopy.achievement",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.crownCanopy.achievement",default:0] + 1)
            coins = Self.saturatedAdd(coins, 35); stars = Self.saturatedAdd(stars, 1); characterNeeds.fun=min(100,characterNeeds.fun+2)
        }
        save(); return true
    }
    @discardableResult func claimWeeklyLightkeeperReward()->Bool {
        guard isWeeklyLightkeeperRewardReady else { return false }; interactionCounts["trophy.lightkeeperWeekly.week\((max(1,dailyLifeProgress.day)-1)/7)"]=1; coins = Self.saturatedAdd(coins, 180); stars = Self.saturatedAdd(stars, 6); characterNeeds.fun=min(100,characterNeeds.fun+5); characterNeeds.energy=min(100,characterNeeds.energy+5); save(); return true
    }

    @discardableResult func claimRadiantRoomEvent()->Bool {
        guard isRadiantRoomEventReady else { return false }
        // Capture the optional finale before marking today's event claimed; otherwise the
        // readiness predicate becomes false and the enhanced reward is silently lost.
        let chimeBonus = isRadiantChimeBonusReady
        interactionCounts["trophy.radiantEvent.claim.day\(dailyLifeProgress.day)"]=1
        interactionCounts["trophy.radiantEvent.achievement",default:0] = min(Self.maxSavedCounter, interactionCounts["trophy.radiantEvent.achievement",default:0] + 1)
        coins = Self.saturatedAdd(coins, chimeBonus ? 120 : 90); stars = Self.saturatedAdd(stars, chimeBonus ? 4 : 3); characterNeeds.fun=min(100,characterNeeds.fun+(chimeBonus ? 6 : 4)); characterNeeds.energy=min(100,characterNeeds.energy+(chimeBonus ? 6 : 4)); save(); return true
    }

    func updateSettings(soundEnabled: Bool? = nil, hapticsEnabled: Bool? = nil, reducedMotion: Bool? = nil, purchaseConfirmation: Bool? = nil, hasCompletedOnboarding: Bool? = nil) {
        if let soundEnabled { playerSettings.soundEnabled = soundEnabled }
        if let hapticsEnabled { playerSettings.hapticsEnabled = hapticsEnabled }
        if let reducedMotion { playerSettings.reducedMotion = reducedMotion }
        if let purchaseConfirmation { playerSettings.purchaseConfirmation = purchaseConfirmation }
        if let hasCompletedOnboarding { playerSettings.hasCompletedOnboarding = hasCompletedOnboarding }
        save()
    }
    var motionAnimationDuration: Double { playerSettings.reducedMotion ? 0 : 0.28 }
    func reward(coins amount:Int, stars starAmount:Int=1){ coins = Self.saturatedAdd(coins, amount); stars = Self.saturatedAdd(stars, starAmount); save() }
    func recordRecipe(_ recipe:String,rewardCoins:Int,rewardStars:Int=1){
        // Only the implemented recipe has a model-authorized reward. A future
        // caller cannot mint arbitrary currency with fabricated recipe data.
        guard recipe == "Rainbow Cupcake", rewardCoins == 75, rewardStars == 1,
              !cookedRecipes.contains(recipe) else { return }
        cookedRecipes.insert(recipe)
        reward(coins: 75, stars: 1)
    }
    // Adventure rewards are authorized by gameplay state, not by a UI-supplied
    // amount or a button's disabled state. This also protects future callers.
    @discardableResult func claimAdventureTask(_ taskID: String) -> Bool {
        guard !completedTasks.contains(taskID) else { return false }
        let rewardAmount: Int
        switch taskID {
        case "outfit":
            guard selectedOutfitID == "party" else { return false }
            rewardAmount = 60
        case "decorate":
            guard hasPlacedAdventureDecoration else { return false }
            rewardAmount = 80
        case "cupcake":
            guard cookedRecipes.contains("Rainbow Cupcake") else { return false }
            rewardAmount = 100
        case "dance":
            guard interactionCount("dance", in: "living") >= 3 else { return false }
            rewardAmount = 120
        default:
            return false
        }
        completedTasks.insert(taskID)
        reward(coins: rewardAmount)
        return true
    }
    func resetProgress(){ coins=500;stars=0;selectedOutfitID="sunny";cookedRecipes=[];completedTasks=[];ownedRoomItemIDs=["sofa"];ownedOutfitIDs=["sunny"];selectedItemsByRoom=["living":"sofa"];characterProfile=CharacterProfile();characterNeeds=CharacterNeeds();interactionCounts=[:];selectedItemsByRoomSlot=["living":["main":"sofa"]];characterPositionsByRoom=[:];petProfile=PetProfile();petNeeds=PetNeeds();gardenProgress=GardenProgress();dailyLifeProgress=DailyLifeProgress();socialProgress=SocialProgress();playerSettings=PlayerSettings();claimedFriendQuestIDs=[];displayedKeepsakeIDsByRoom=[:];save() }
    private func unlockRoomItem(_ item:RoomItem)->Bool { if ownsRoomItem(item){return true}; guard spend(item.cost) else{return false};ownedRoomItemIDs.insert(item.id);return true }
    private func unlockOutfit(_ outfit:Outfit)->Bool { if ownsOutfit(outfit){return true};guard spend(outfit.cost) else{return false};ownedOutfitIDs.insert(outfit.id);return true }
    private func spend(_ cost:Int)->Bool { guard cost>=0,coins>=cost else{return false};coins-=cost;return true }
    func completeOnboarding() { updateSettings(hasCompletedOnboarding: true) }
    private func snapshot() -> SaveGame { SaveGame(schemaVersion: Self.currentSaveSchemaVersion, commitSequence: lastCommittedSequence + 1, coins:coins,stars:stars,selectedOutfitID:selectedOutfitID,cookedRecipes:cookedRecipes,completedTasks:completedTasks,ownedRoomItemIDs:ownedRoomItemIDs,ownedOutfitIDs:ownedOutfitIDs,selectedItemsByRoom:selectedItemsByRoom,characterProfile:characterProfile,characterNeeds:characterNeeds,interactionCounts:interactionCounts,selectedItemsByRoomSlot:selectedItemsByRoomSlot,characterPositionsByRoom:characterPositionsByRoom,petProfile:petProfile,petNeeds:petNeeds,gardenProgress:gardenProgress,dailyLifeProgress:dailyLifeProgress,socialProgress:socialProgress,playerSettings:playerSettings,claimedFriendQuestIDs:claimedFriendQuestIDs,displayedKeepsakeIDsByRoom:displayedKeepsakeIDsByRoom) }
    // Treat an explicit, unrecognized schema marker as protected data, not as a
    // legacy save. This includes future schema versions, strings, null, booleans,
    // fractions and non-positive versions. Missing markers alone indicate legacy.
    // A malformed JSON blob with no readable schema is still recoverable from a
    // compatible backup; the original is not considered a future save.
    private static func hasProtectedSchema(_ data: Data) -> Bool {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let marker = json["schemaVersion"] else { return false }
        guard let number = marker as? NSNumber else { return true }
        // NSNumber bridges JSON booleans and floating-point values to Int. Check
        // the actual CFBoolean identity and numeric encoding to distinguish true
        // and 4.0 from integer schema versions (including small signed integers).
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return true }
        let encoding = String(cString: number.objCType)
        guard ["c", "C", "i", "q", "s", "l", "I", "Q", "S", "L"].contains(encoding),
              let version = marker as? Int,
              (1...currentSaveSchemaVersion).contains(version) else { return true }
        return false
    }
    // Only rotate snapshots that are actually readable by this build. Rotating
    // malformed bytes over a known-good backup destroys the recovery path.
    private static func decodeCompatibleSnapshot(_ data: Data) -> SaveGame? {
        guard !hasProtectedSchema(data),
              let candidate = try? JSONDecoder().decode(SaveGame.self, from: data),
              (1...currentSaveSchemaVersion).contains(candidate.schemaVersion ?? 1),
              (candidate.commitSequence ?? 0) >= 0 else { return nil }
        return candidate
    }
    // A committed primary and backup with the SAME positive journal number
    // but different bytes cannot be ordered safely, even when a pending
    // journal is present. An older journal must not hide this conflict, and
    // a newer journal must not rotate away either conflicting copy. Preserve
    // all three slots for parent review and export.
    private static func hasUnresolvedPrimaryBackupConflict(
        primary: Data?, backup: Data?, pending: Data?
    ) -> Bool {
        guard let primary, let backup, primary != backup,
              let first = decodeCompatibleSnapshot(primary),
              let second = decodeCompatibleSnapshot(backup),
              let sequence = first.commitSequence, sequence > 0,
              second.commitSequence == sequence else { return false }
        return true
    }

    // An interrupted journal with the same positive sequence as the committed
    // primary, but different bytes, cannot be safely dismissed as stale.
    // Discarding it loses a valid candidate. Lock the save and preserve both.
    private static func hasUnresolvedPrimaryPendingConflict(
        primary: Data?, pending: Data?
    ) -> Bool {
        guard let primary, let pending, primary != pending,
              let first = decodeCompatibleSnapshot(primary),
              let second = decodeCompatibleSnapshot(pending),
              let sequence = first.commitSequence, sequence > 0,
              second.commitSequence == sequence else { return false }
        return true
    }

    private func persistSnapshot(rotatingBackup: Bool = true) {
        guard !isSaveReadOnlyDueToNewerVersion && !isSaveReadOnlyDueToAmbiguousRecovery else { return }
        // v2.44: Int.max is a valid terminal commit, not corrupt data. Once it
        // has been reached, preserve the existing bytes rather than overflowing
        // `snapshot()` or silently replacing the save with an older backup.
        guard lastCommittedSequence < Int.max else {
            isSaveReadOnlyDueToSequenceLimit = true
            return
        }
        // Protect externally restored newer saves, including interrupted writes
        // left by a newer app build.
        if [saveKey, pendingKey].compactMap({ defaults.data(forKey: $0) }).contains(where: Self.hasProtectedSchema) {
            isSaveReadOnlyDueToNewerVersion = true
            return
        }
        // Optimistic concurrency check: even a *compatible* newer save must not
        // be overwritten by a stale in-memory GameStore (e.g. after a restore).
        // Comparing the exact committed bytes also catches same-sequence edits.
        let diskPrimary = defaults.data(forKey: saveKey)
        let diskBackup = defaults.data(forKey: backupKey)
        let diskPending = defaults.data(forKey: pendingKey)
        // A second session may introduce an equal-sequence conflict AFTER
        // this store was loaded. Detect it before staging any new writes.
        if Self.hasUnresolvedPrimaryPendingConflict(
            primary: diskPrimary, pending: defaults.data(forKey: pendingKey)
        ) {
            isSaveReadOnlyDueToAmbiguousRecovery = true
            return
        }
        if Self.hasUnresolvedPrimaryBackupConflict(
            primary: diskPrimary,
            backup: diskBackup,
            pending: diskPending
        ) {
            isSaveReadOnlyDueToAmbiguousRecovery = true
            return
        }
        // Never overwrite a foreign staged journal. Existing same-sequence
        // conflicts were classified above, so they retain the recovery warning.
        if diskPending != nil {
            isSaveReadOnlyDueToExternalChanges = true
            return
        }
        let newerPending = defaults.data(forKey: pendingKey)
            .flatMap(Self.decodeCompatibleSnapshot)
            .map { ($0.commitSequence ?? 0) > lastCommittedSequence } ?? false
        let newerBackup = defaults.data(forKey: backupKey)
            .flatMap(Self.decodeCompatibleSnapshot)
            .map { ($0.commitSequence ?? 0) > lastCommittedSequence } ?? false
        if diskPrimary != lastCommittedData || newerPending || newerBackup {
            isSaveReadOnlyDueToExternalChanges = true
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        // Stage a complete encoded snapshot before modifying either save slot.
        // If the process stops here, load() can finish the interrupted commit.
        defaults.set(data, forKey: pendingKey)
        guard defaults.data(forKey: pendingKey) == data else {
            isSaveReadOnlyDueToExternalChanges = true
            return
        }
        // Another session can write AFTER the first optimistic check but
        // DURING the pending stage. Verify both committed slots before touching
        // the backup or primary. This narrows, but does not eliminate, the
        // UserDefaults cross-process race (there is no atomic compare-and-swap).
        guard defaults.data(forKey: saveKey) == diskPrimary,
              defaults.data(forKey: backupKey) == diskBackup else {
            discardOurPendingJournal(data)
            isSaveReadOnlyDueToExternalChanges = true
            return
        }
        var expectedBackup = diskBackup
        if rotatingBackup, !preserveBackupAfterRecovery, let old = diskPrimary,
           Self.decodeCompatibleSnapshot(old) != nil {
            let protectedBackup = diskBackup.map(Self.hasProtectedSchema) ?? false
            if !protectedBackup {
                defaults.set(old, forKey: backupKey)
                expectedBackup = old
            }
        }
        // Recheck immediately before the primary commit. In particular, do
        // not overwrite a primary that changed while the backup was rotated.
        guard defaults.data(forKey: pendingKey) == data,
              defaults.data(forKey: saveKey) == diskPrimary,
              defaults.data(forKey: backupKey) == expectedBackup else {
            discardOurPendingJournal(data)
            isSaveReadOnlyDueToExternalChanges = true
            return
        }
        defaults.set(data, forKey: saveKey)
        // Keep the pending copy when the primary write cannot be verified.
        if defaults.data(forKey: saveKey) == data {
            lastCommittedSequence += 1
            if lastCommittedSequence == Int.max { isSaveReadOnlyDueToSequenceLimit = true }
            lastCommittedData = data
            defaults.removeObject(forKey: pendingKey)
            if rotatingBackup { preserveBackupAfterRecovery = false }
        }
    }
    // Only remove the pending journal if it still contains our exact staged
    // bytes. Do not erase another session's replacement journal on abort.
    private func discardOurPendingJournal(_ data: Data) {
        if defaults.data(forKey: pendingKey) == data {
            defaults.removeObject(forKey: pendingKey)
        }
    }

    // Reading twice is a best-effort consistency check for UserDefaults;
    // it does not make cross-process reads atomic.
    private func readRecoverySlotsConsistently() -> [Data?]? {
        let keys = [saveKey, backupKey, pendingKey]
        let before = keys.map { defaults.data(forKey: $0) }
        let after = keys.map { defaults.data(forKey: $0) }
        return before == after ? before : nil
    }

    private func makeRecoveryPreviews(_ bytes: [Data?]) -> [SaveRecoverySlotPreview] {
        let names = ["primary", "backup", "pending"]
        return zip(names.indices, names).map { index, name in
            let data = bytes[index]
            // Never classify two absent slots as matching save copies.
            let comparison: String? = data.map { candidate in
                let matchingNames = names.indices.compactMap { other -> String? in
                    guard other != index, bytes[other] == candidate else { return nil }
                    switch names[other] {
                    case "primary": return "Primary copy"
                    case "backup": return "Backup copy"
                    default: return "Pending copy"
                    }
                }
                return matchingNames.isEmpty
                    ? "No other copy has identical bytes"
                    : "Exact bytes match " + matchingNames.joined(separator: " and ")
            }
            guard let data else {
                return SaveRecoverySlotPreview(id: name, state: .absent,
                    sequence: nil, coins: nil, stars: nil, completedTasks: nil,
                    byteComparisonSummary: nil)
            }
            guard let snapshot = Self.decodeCompatibleSnapshot(data) else {
                return SaveRecoverySlotPreview(id: name,
                    state: Self.hasProtectedSchema(data) ? .needsNewerApp : .unreadable,
                    sequence: nil, coins: nil, stars: nil, completedTasks: nil,
                    byteComparisonSummary: comparison)
            }
            return SaveRecoverySlotPreview(id: name, state: .readable,
                sequence: snapshot.commitSequence,
                coins: Self.bounded(snapshot.coins, maximum: Self.maxSavedCurrency),
                stars: Self.bounded(snapshot.stars, maximum: Self.maxSavedCurrency),
                completedTasks: snapshot.completedTasks.count,
                byteComparisonSummary: comparison)
        }
    }

    // Count distinct *raw* candidates, not matching visible game totals.
    // All counts use the captured inspection snapshot (no extra disk reads).
    private func makeRecoveryInspectionSummary(_ bytes: [Data?],
                                               previews: [SaveRecoverySlotPreview]) -> String {
        let present = bytes.compactMap { $0 }
        let readable = previews.filter { $0.state == .readable }.count
        let newer = previews.filter { $0.state == .needsNewerApp }.count
        let damaged = previews.filter { $0.state == .unreadable }.count
        let distinct = Set(present).count
        var parts = ["\(present.count) of 3 copies present",
                     "\(distinct) distinct byte \(distinct == 1 ? "version" : "versions")",
                     "\(readable) readable"]
        if newer > 0 { parts.append("\(newer) \(newer == 1 ? "requires" : "require") a newer app") }
        if damaged > 0 { parts.append("\(damaged) unreadable") }
        return parts.joined(separator: " · ")
    }

    // Compatibility API for existing callers and tests. No storage mutations.
    func previewAmbiguousRecoverySlots() -> [SaveRecoverySlotPreview]? {
        guard isSaveReadOnlyDueToAmbiguousRecovery,
              let bytes = readRecoverySlotsConsistently() else { return nil }
        return makeRecoveryPreviews(bytes)
    }

    // Parent-facing UI uses this explicit session instead of two unrelated
    // reads for preview and export. A refresh revokes the previous token.
    func beginRecoveryInspection() -> SaveRecoveryInspection? {
        inspectedRecoverySlots = nil
        guard isSaveReadOnlyDueToAmbiguousRecovery,
              let bytes = readRecoverySlotsConsistently(),
              bytes.contains(where: { $0 != nil }) else { return nil }
        let id = UUID()
        inspectedRecoverySlots = (id, bytes)
        let previews = makeRecoveryPreviews(bytes)
        return SaveRecoveryInspection(id: id, previews: previews,
            summary: makeRecoveryInspectionSummary(bytes, previews: previews))
    }

    // The parent must review the exact candidate bytes that will be exported.
    // A stale inspection is rejected even if only an invisible JSON field
    // changed, and the UI must request an explicit refresh before retrying.
    func exportAmbiguousRecoveryArchive(inspectionID: UUID) -> Data? {
        guard let inspected = inspectedRecoverySlots,
              inspected.id == inspectionID else { return nil }
        return encodeRecoveryArchive(expectedBytes: inspected.bytes)
    }

    // Legacy programmatic export API retained for compatibility with prior
    // recovery tooling. The Settings UI exclusively uses the token-checked API.
    func exportAmbiguousRecoveryArchive() -> Data? {
        encodeRecoveryArchive(expectedBytes: nil)
    }

    private func encodeRecoveryArchive(expectedBytes: [Data?]?) -> Data? {
        guard isSaveReadOnlyDueToAmbiguousRecovery,
              let bytes = readRecoverySlotsConsistently(),
              bytes.contains(where: { $0 != nil }),
              (expectedBytes.map({ $0 == bytes }) ?? true) else { return nil }
        let names = ["primary", "backup", "pending"]
        let archive = SaveRecoveryArchive(
            formatVersion: 2,
            reason: "ambiguous-equal-sequence",
            slots: zip(names, bytes).map { name, data in
                SaveRecoveryArchive.Slot(name: name, bytes: data,
                                         checksum: SaveRecoveryArchive.checksum(for: data))
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard archive.integrityStatus == .verified,
              let encoded = try? encoder.encode(archive),
              let roundTrip = try? JSONDecoder().decode(SaveRecoveryArchive.self, from: encoded),
              roundTrip.integrityStatus == .verified,
              // Also reject an edit that happened while JSON was encoded.
              readRecoverySlotsConsistently() == bytes else { return nil }
        return encoded
    }

    private func save(){ persistSnapshot() }
    private func load(){
        var primary = defaults.data(forKey: saveKey)
        var backup = defaults.data(forKey: backupKey)
        let pending = defaults.data(forKey: pendingKey)
        // Do not commit a staged save if any staged/primary format is newer or
        // unrecognized. A compatible primary/backup can still be previewed.
        let protectedPrimary = primary.map(Self.hasProtectedSchema) ?? false
        let protectedPending = pending.map(Self.hasProtectedSchema) ?? false
        if protectedPrimary || protectedPending {
            isSaveReadOnlyDueToNewerVersion = true
        } else if Self.hasUnresolvedPrimaryBackupConflict(
            primary: primary, backup: backup, pending: pending
        ) || Self.hasUnresolvedPrimaryPendingConflict(primary: primary, pending: pending) {
            // Check BEFORE replaying or cleaning a pending journal. Otherwise
            // a newer journal can overwrite an ambiguous backup, or a stale
            // journal can be removed before the parent exports all raw copies.
            isSaveReadOnlyDueToAmbiguousRecovery = true
        } else if let pending, let staged = Self.decodeCompatibleSnapshot(pending) {
            let current = primary.flatMap(Self.decodeCompatibleSnapshot)
            let savedBackup = backup.flatMap(Self.decodeCompatibleSnapshot)
            let stagedSequence = staged.commitSequence ?? 0
            let currentSequence = current?.commitSequence ?? 0
            let backupSequence = savedBackup?.commitSequence ?? 0
            // Prefer a demonstrably newer backup over an orphaned journal.
            // Otherwise, a stale or ambiguous journal cannot replace a newer
            // committed primary. Legacy (unnumbered) journals still replay.
            if backupSequence > max(currentSequence, stagedSequence) {
                defaults.removeObject(forKey: pendingKey)
                primary = nil // Restore the newest known-good backup below.
            } else if savedBackup != nil && backupSequence > 0 &&
                        backupSequence == stagedSequence && backup != pending &&
                        (current == nil || currentSequence < backupSequence) {
                // v2.45: equal journal numbers cannot order different payloads.
                // Preview the committed backup, but preserve primary, pending
                // and backup bytes untouched. Lock writes until manual recovery.
                isSaveReadOnlyDueToAmbiguousRecovery = true
                primary = nil // Preview backup below without writing to disk.
            } else if current != nil && currentSequence > 0 && currentSequence >= stagedSequence {
                defaults.removeObject(forKey: pendingKey)
            } else if primary != pending {
                if let old = primary, let oldSnapshot = Self.decodeCompatibleSnapshot(old),
                   !(backup.map(Self.hasProtectedSchema) ?? false),
                   (savedBackup?.commitSequence ?? 0) <= (oldSnapshot.commitSequence ?? 0) {
                    defaults.set(old, forKey: backupKey)
                    backup = old
                }
                defaults.set(pending, forKey: saveKey)
                if defaults.data(forKey: saveKey) == pending { primary = pending }
            }
            if primary == pending { defaults.removeObject(forKey: pendingKey) }
        }
        // An invalid, non-future journal cannot be replayed. When a readable
        // committed copy exists and there is no ambiguous conflict, discard
        // the corrupt journal before normalizing (legacy recovery behavior).
        // Never discard an unknown/newer schema or a disputed candidate.
        if let pending,
           Self.decodeCompatibleSnapshot(pending) == nil,
           !Self.hasProtectedSchema(pending),
           !isSaveReadOnlyDueToNewerVersion,
           !isSaveReadOnlyDueToAmbiguousRecovery,
           (primary.flatMap(Self.decodeCompatibleSnapshot) != nil ||
            backup.flatMap(Self.decodeCompatibleSnapshot) != nil),
           defaults.data(forKey: pendingKey) == pending {
            defaults.removeObject(forKey: pendingKey)
        }
        // Check again after replay, because the journal path may have changed
        // the primary/backup pairing. Never normalize an unresolved tie.
        if !isSaveReadOnlyDueToNewerVersion && Self.hasUnresolvedPrimaryBackupConflict(
            primary: primary, backup: backup, pending: pending
        ) {
            isSaveReadOnlyDueToAmbiguousRecovery = true
        }
        // The journal may have been removed after backup rotation but before
        // primary commit. A newer *valid* backup must still win, even with no
        // pending key. Otherwise load normalization would cement a rollback.
        if !isSaveReadOnlyDueToNewerVersion,
           let savedBackup = backup.flatMap(Self.decodeCompatibleSnapshot),
           let current = primary.flatMap(Self.decodeCompatibleSnapshot),
           (savedBackup.commitSequence ?? 0) > (current.commitSequence ?? 0) {
            primary = nil
        }
        var decoded = primary.flatMap(Self.decodeCompatibleSnapshot)
        if decoded == nil, let backup, let recovered=Self.decodeCompatibleSnapshot(backup) {
            decoded=recovered
            preserveBackupAfterRecovery = true
            if !isSaveReadOnlyDueToNewerVersion && !isSaveReadOnlyDueToAmbiguousRecovery {
                defaults.set(backup,forKey:saveKey)
            }
        }
        if decoded == nil, backup.map(Self.hasProtectedSchema) ?? false {
            isSaveReadOnlyDueToNewerVersion = true
        }
        guard let s=decoded else{return}
        lastCommittedSequence = s.commitSequence ?? 0
        lastCommittedData = defaults.data(forKey: saveKey)
        let roomIDs=Set(rooms.map(\.id)), itemIDs=Set(roomItems.map(\.id)), outfitIDs=Set(outfits.map(\.id)), friendIDs=Set(friends.map(\.id))
        coins=Self.bounded(s.coins, maximum: Self.maxSavedCurrency); stars=Self.bounded(s.stars, maximum: Self.maxSavedCurrency)
        ownedRoomItemIDs=s.ownedRoomItemIDs.intersection(itemIDs).union(["sofa"])
        ownedOutfitIDs=s.ownedOutfitIDs.intersection(outfitIDs).union(["sunny"])
        selectedOutfitID=ownedOutfitIDs.contains(s.selectedOutfitID) ? s.selectedOutfitID : "sunny"
        cookedRecipes=s.cookedRecipes; completedTasks=s.completedTasks
        selectedItemsByRoom=(s.selectedItemsByRoom ?? [:]).filter { roomIDs.contains($0.key) && ownedRoomItemIDs.contains($0.value) }
        if selectedItemsByRoom["living"] == nil { selectedItemsByRoom["living"]="sofa" }
        characterProfile=s.characterProfile ?? CharacterProfile()
        characterNeeds=Self.sanitize(s.characterNeeds ?? CharacterNeeds())
        interactionCounts=(s.interactionCounts ?? [:]).mapValues { Self.bounded($0, maximum: Self.maxSavedCounter) }
        selectedItemsByRoomSlot=[:]
        for (room,slots) in s.selectedItemsByRoomSlot ?? [:] where roomIDs.contains(room) { selectedItemsByRoomSlot[room]=slots.filter { ["main","side"].contains($0.key) && ownedRoomItemIDs.contains($0.value) } }
        if selectedItemsByRoomSlot["living"]?["main"] == nil { selectedItemsByRoomSlot["living",default:[:]]["main"]="sofa" }
        characterPositionsByRoom=(s.characterPositionsByRoom ?? [:]).filter { roomIDs.contains($0.key) }.mapValues { CharacterPosition(x:min(1,max(0,$0.x)),y:min(1,max(0,$0.y))) }
        petProfile=s.petProfile ?? PetProfile(); if !roomIDs.contains(petProfile.roomID) { petProfile.roomID="living" }; if !["cat","dog"].contains(petProfile.species) { petProfile.species="cat" }
        petNeeds=Self.sanitize(s.petNeeds ?? PetNeeds())
        gardenProgress=s.gardenProgress ?? GardenProgress(); gardenProgress.poolVisits=Self.bounded(gardenProgress.poolVisits, maximum: Self.maxSavedCounter); gardenProgress.loungeVisits=Self.bounded(gardenProgress.loungeVisits, maximum: Self.maxSavedCounter); gardenProgress.petPlayVisits=Self.bounded(gardenProgress.petPlayVisits, maximum: Self.maxSavedCounter)
        dailyLifeProgress=s.dailyLifeProgress ?? DailyLifeProgress(); dailyLifeProgress.day=min(Self.maxSavedDay,max(1,dailyLifeProgress.day)); dailyLifeProgress.phaseIndex=min(2,max(0,dailyLifeProgress.phaseIndex)); dailyLifeProgress.chainStep=min(2,max(0,dailyLifeProgress.chainStep)); dailyLifeProgress.streak=Self.bounded(dailyLifeProgress.streak, maximum: Self.maxSavedCounter); dailyLifeProgress.lastCompletedDay=min(dailyLifeProgress.day,Self.bounded(dailyLifeProgress.lastCompletedDay, maximum: Self.maxSavedDay)); dailyLifeProgress.phaseActionCounts=dailyLifeProgress.phaseActionCounts.mapValues{Self.bounded($0, maximum: Self.maxSavedCounter)}
        socialProgress=s.socialProgress ?? SocialProgress(); socialProgress.friendshipXP=socialProgress.friendshipXP.filter{friendIDs.contains($0.key)}.mapValues{Self.bounded($0, maximum: Self.maxSavedCounter)}; socialProgress.hangouts=socialProgress.hangouts.filter{friendIDs.contains($0.key)}.mapValues{Self.bounded($0, maximum: Self.maxSavedCounter)}; if let id=socialProgress.activeFriendID, !friendIDs.contains(id){socialProgress.activeFriendID=nil}; if let room=socialProgress.friendRoomID, !roomIDs.contains(room){socialProgress.friendRoomID=nil}; socialProgress.partyWins=Self.bounded(socialProgress.partyWins, maximum: Self.maxSavedCounter)
        playerSettings=s.playerSettings ?? PlayerSettings()
        claimedFriendQuestIDs=Set((s.claimedFriendQuestIDs ?? []).filter { id in friends.contains(where:{ friendQuestID(for:$0.id)==id || friendStoryPartyID(for:$0.id)==id || friendStoryRoomID(for:$0.id)==id || "keepsake.\($0.id)"==id }) || surpriseBadges.contains(where:{$0.id==id}) || id == "badge.collection.complete" })
        let ownedKeepsakeIDs=Set(friends.compactMap{ isFriendKeepsakeClaimed($0.id) ? friendKeepsake(for:$0.id)?.id : nil })
        displayedKeepsakeIDsByRoom=(s.displayedKeepsakeIDsByRoom ?? [:]).filter{roomIDs.contains($0.key)}.mapValues{Set($0.filter{ownedKeepsakeIDs.contains($0)})}.filter{!$0.value.isEmpty}
        // v2.56: an edited/restored save could carry an over-long name or unknown
        // look IDs that the UI cannot draw. Normalise them like every other field.
        // (Accessory checks run after interactionCounts so earned items stay valid.)
        characterProfile=sanitizedProfile(characterProfile)
        let petName=petProfile.name.trimmingCharacters(in:.whitespacesAndNewlines)
        petProfile.name=petName.isEmpty ? PetProfile().name : String(petName.prefix(14))
        // Persist the normalized state without rotating the backup. This prevents repaired
        // legacy/corrupt values from reappearing on the next launch while preserving the
        // last known-good backup for recovery.
        // Loading a nearly exhausted save must not consume its final commit
        // merely to normalize values. Reserve that write for a player action.
        if !isSaveReadOnlyDueToAmbiguousRecovery && lastCommittedSequence < Int.max - 1 {
            persistSnapshot(rotatingBackup: false)
        } else if lastCommittedSequence == Int.max {
            isSaveReadOnlyDueToSequenceLimit = true
        }
    }
    private func sanitizedProfile(_ profile: CharacterProfile)->CharacterProfile {
        var p=profile; let d=CharacterProfile()
        let name=p.name.trimmingCharacters(in:.whitespacesAndNewlines)
        p.name=name.isEmpty ? d.name : String(name.prefix(18))
        if !hairStyles.contains(where:{$0.id==p.hairStyleID}) { p.hairStyleID=d.hairStyleID }
        if !hairColors.contains(where:{$0.id==p.hairColorID}) { p.hairColorID=d.hairColorID }
        if !skinTones.contains(where:{$0.id==p.skinToneID}) { p.skinToneID=d.skinToneID }
        if !accessories.contains(where:{$0.id==p.accessoryID}) { p.accessoryID=d.accessoryID }
        return p
    }
    private static func sanitize(_ value: CharacterNeeds)->CharacterNeeds { CharacterNeeds(energy:min(100,max(0,value.energy)),fun:min(100,max(0,value.fun)),hygiene:min(100,max(0,value.hygiene)),hunger:min(100,max(0,value.hunger))) }
    private static func sanitize(_ value: PetNeeds)->PetNeeds { PetNeeds(hunger:min(100,max(0,value.hunger)),happiness:min(100,max(0,value.happiness)),energy:min(100,max(0,value.energy))) }
}
