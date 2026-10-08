import XCTest
@testable import DreamLifeHouse

@MainActor
final class GameStoreTests: XCTestCase {
    private func makeStore(_ name: String = UUID().uuidString) -> (GameStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "DreamLifeHouseTests.\(name)")!
        defaults.removePersistentDomain(forName: "DreamLifeHouseTests.\(name)")
        return (GameStore(defaults: defaults, saveKey: "save"), defaults)
    }

    func testRewardAddsCurrency() {
        let (store, _) = makeStore()
        store.reward(coins: 50, stars: 2)
        XCTAssertEqual(store.coins, 550)
        XCTAssertEqual(store.stars, 2)
    }

    func testPurchasedItemIsNotChargedTwice() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        XCTAssertTrue(store.selectRoomItem(lamp))
        XCTAssertEqual(store.coins, 380)
        XCTAssertTrue(store.selectRoomItem(lamp))
        XCTAssertEqual(store.coins, 380)
        XCTAssertTrue(store.ownsRoomItem(lamp))
    }

    func testProgressPersistsAcrossStoreInstances() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        first.reward(coins: 25, stars: 3)
        let party = first.outfits.first { $0.id == "party" }!
        XCTAssertTrue(first.selectOutfit(party))

        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 445)
        XCTAssertEqual(restored.stars, 3)
        XCTAssertEqual(restored.selectedOutfitID, "party")
        XCTAssertTrue(restored.ownsOutfit(party))
    }

    func testRecipeRewardOnlyGrantedOnce() {
        let (store, _) = makeStore()
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
        XCTAssertEqual(store.coins, 575)
        XCTAssertEqual(store.stars, 1)
    }
}

extension GameStoreTests {
    func testRoomsKeepIndependentDecorations() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        let flowers = store.roomItems.first { $0.id == "flowers" }!
        XCTAssertTrue(store.selectRoomItem(lamp, in: "bedroom"))
        XCTAssertTrue(store.selectRoomItem(flowers, in: "garden"))
        XCTAssertEqual(store.selectedItem(in: "bedroom").id, "lamp")
        XCTAssertEqual(store.selectedItem(in: "garden").id, "flowers")
    }
    func testInvalidRoomCannotSpendCoins() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        XCTAssertFalse(store.selectRoomItem(lamp, in: "not-a-room"))
        XCTAssertEqual(store.coins, 500)
    }
}

extension GameStoreTests {
    func testCharacterProfilePersists() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        first.updateCharacter(name: "Lina", hairStyleID: "curls", hairColorID: "berry", skinToneID: "deep", accessoryID: "star")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.characterProfile, CharacterProfile(name:"Lina",hairStyleID:"curls",hairColorID:"berry",skinToneID:"deep",accessoryID:"star"))
    }
    func testInvalidCharacterOptionIsIgnored() {
        let (store, _) = makeStore()
        let before = store.characterProfile
        store.updateCharacter(hairStyleID: "not-real", accessoryID: "also-not-real")
        XCTAssertEqual(store.characterProfile, before)
    }
    func testCharacterNameIsTrimmedAndLimited() {
        let (store, _) = makeStore()
        store.updateCharacter(name: "   A very very very long character name   ")
        XCTAssertFalse(store.characterProfile.name.hasPrefix(" "))
        XCTAssertLessThanOrEqual(store.characterProfile.name.count, 18)
    }
}

extension GameStoreTests {
    func testRoomInteractionsUpdateNeedsAndClampAtHundred() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.performInteraction("snack", in: "kitchen"))
        XCTAssertEqual(store.characterNeeds.hunger, 85)
        XCTAssertTrue(store.performInteraction("snack", in: "kitchen"))
        XCTAssertEqual(store.characterNeeds.hunger, 100)
    }
    func testWrongInteractionForRoomDoesNothing() {
        let (store, _) = makeStore()
        let before = store.characterNeeds
        XCTAssertFalse(store.performInteraction("shower", in: "garden"))
        XCTAssertEqual(store.characterNeeds, before)
    }
    func testNeedsPersistAcrossStoreInstances() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(first.performInteraction("sleep", in: "bedroom"))
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.characterNeeds.energy, 95)
        XCTAssertEqual(restored.characterNeeds.hunger, 55)
    }
}

extension GameStoreTests {
    func testInteractionsAreCountedAndPersist() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(first.performInteraction("dance", in: "living"))
        XCTAssertTrue(first.performInteraction("dance", in: "living"))
        XCTAssertEqual(first.interactionCount("dance", in: "living"), 2)
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.interactionCount("dance", in: "living"), 2)
    }
    func testInvalidInteractionIsNotCounted() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.performInteraction("dance", in: "bathroom"))
        XCTAssertEqual(store.interactionCount("dance", in: "bathroom"), 0)
    }
    func testTaskRewardCannotBeClaimedTwice() {
        let (store, _) = makeStore()
        for _ in 0..<3 { XCTAssertTrue(store.performInteraction("dance", in: "living")) }
        XCTAssertTrue(store.claimAdventureTask("dance"))
        XCTAssertFalse(store.claimAdventureTask("dance"))
        XCTAssertEqual(store.coins, 620)
    }
}


extension GameStoreTests {
    func testRoomSupportsIndependentDecorSlots() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        let plant = store.roomItems.first { $0.id == "plant" }!
        XCTAssertTrue(store.selectRoomItem(lamp, in: "living", slot: "main"))
        XCTAssertTrue(store.selectRoomItem(plant, in: "living", slot: "side"))
        XCTAssertEqual(store.selectedItem(in: "living", slot: "main").id, "lamp")
        XCTAssertEqual(store.selectedItem(in: "living", slot: "side").id, "plant")
    }
    func testCharacterPositionClampsAndPersists() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        first.moveCharacter(in: "garden", x: 1.4, y: -0.2)
        XCTAssertEqual(first.characterPosition(in: "garden"), CharacterPosition(x: 1, y: 0))
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.characterPosition(in: "garden"), CharacterPosition(x: 1, y: 0))
    }
    func testInvalidDecorSlotDoesNotSpendCoins() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        XCTAssertFalse(store.selectRoomItem(lamp, in: "living", slot: "invalid"))
        XCTAssertEqual(store.coins, 500)
    }
}


extension GameStoreTests {
    func testDroppingCharacterOnBedroomBedTriggersSleep() {
        let (store, _) = makeStore()
        let before = store.characterNeeds.energy
        XCTAssertEqual(store.dropCharacter(in: "bedroom", x: 0.82, y: 0.62), "sleep")
        XCTAssertGreaterThan(store.characterNeeds.energy, before)
        XCTAssertEqual(store.interactionCount("sleep", in: "bedroom"), 1)
    }
    func testDroppingCharacterOutsideActivityZoneOnlyMoves() {
        let (store, _) = makeStore()
        let before = store.characterNeeds
        XCTAssertNil(store.dropCharacter(in: "kitchen", x: 0.20, y: 0.20))
        XCTAssertEqual(store.characterNeeds, before)
        XCTAssertEqual(store.characterPosition(in: "kitchen"), CharacterPosition(x: 0.20, y: 0.20))
    }
    func testContextualDropPersistsPositionAndInteraction() {
        let suite = "DreamLifeHouseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(first.dropCharacter(in: "bathroom", x: 0.75, y: 0.60), "shower")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.characterPosition(in: "bathroom"), CharacterPosition(x: 0.75, y: 0.60))
        XCTAssertEqual(restored.interactionCount("shower", in: "bathroom"), 1)
    }
}


extension GameStoreTests {
    func testPetCareClampsAndCounts() { let (store,_) = makeStore(); XCTAssertTrue(store.careForPet("feed")); XCTAssertTrue(store.careForPet("feed")); XCTAssertEqual(store.petNeeds.hunger,100); XCTAssertEqual(store.interactionCount("feed",in:"pet"),2) }
    func testPetRoomAndProfilePersist() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); first.updatePet(name:"Nova",species:"dog"); XCTAssertTrue(first.movePet(to:"garden")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.petProfile,PetProfile(name:"Nova",species:"dog",roomID:"garden")) }
    func testInvalidPetRoomDoesNotMove() { let (store,_) = makeStore(); XCTAssertFalse(store.movePet(to:"moon")); XCTAssertEqual(store.petProfile.roomID,"living") }
}


extension GameStoreTests {
    func testGardenSwimUpdatesNeedsAndProgress() { let (store,_) = makeStore(); let fun=store.characterNeeds.fun; XCTAssertTrue(store.performGardenActivity("swim")); XCTAssertGreaterThan(store.characterNeeds.fun,fun); XCTAssertEqual(store.gardenProgress.poolVisits,1); XCTAssertEqual(store.interactionCount("swim",in:"garden"),1) }
    func testPetGardenPlayRequiresPetInGarden() { let (store,_) = makeStore(); XCTAssertFalse(store.performGardenActivity("petPlay")); XCTAssertTrue(store.movePet(to:"garden")); XCTAssertTrue(store.performGardenActivity("petPlay")); XCTAssertEqual(store.gardenProgress.petPlayVisits,1) }
    func testGardenProgressPersists() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(first.performGardenActivity("lounge")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.gardenProgress.loungeVisits,1) }
}


extension GameStoreTests {
    func testFullDayCycleDecaysNeedsAndAdvancesDay() { let (store,_) = makeStore(); let hunger=store.characterNeeds.hunger; _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyLifeProgress.day,2); XCTAssertEqual(store.dayPhase,"Morning"); XCTAssertLessThan(store.characterNeeds.hunger,hunger) }
    func testDailyChainMustBeCompletedInOrderAndRewards() { let (store,_) = makeStore(); let coins=store.coins; XCTAssertFalse(store.performDailyChainAction("sleep")); XCTAssertTrue(store.performDailyChainAction("shower")); XCTAssertTrue(store.performDailyChainAction("decorate")); XCTAssertTrue(store.performDailyChainAction("sleep")); XCTAssertEqual(store.dailyLifeProgress.streak,1); XCTAssertEqual(store.coins,coins+110); XCTAssertEqual(store.stars,2) }
    func testDailyLifeProgressPersists() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.advanceDayPhase(); _=first.performDailyChainAction("shower"); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.dayPhase,"Afternoon"); XCTAssertEqual(restored.dailyLifeProgress.chainStep,1) }
}


extension GameStoreTests {
    func testRealHouseActionsAdvanceDailyChainAutomatically() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.performInteraction("shower", in: "bathroom"))
        XCTAssertEqual(store.dailyLifeProgress.chainStep, 1)
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        XCTAssertTrue(store.selectRoomItem(lamp, in: "living", slot: "side"))
        XCTAssertEqual(store.dailyLifeProgress.chainStep, 2)
        XCTAssertTrue(store.performInteraction("sleep", in: "bedroom"))
        XCTAssertEqual(store.dailyLifeProgress.lastCompletedDay, 1)
        XCTAssertEqual(store.dailyLifeProgress.streak, 1)
    }
    func testDailyChainCannotRewardTwiceOnSameDay() {
        let (store, _) = makeStore()
        _ = store.performDailyChainAction("shower")
        _ = store.performDailyChainAction("decorate")
        _ = store.performDailyChainAction("sleep")
        let coins = store.coins
        XCTAssertFalse(store.performDailyChainAction("shower"))
        XCTAssertEqual(store.coins, coins)
    }
    func testUnrelatedHouseActionDoesNotAdvanceDailyChain() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.performInteraction("dance", in: "living"))
        XCTAssertEqual(store.dailyLifeProgress.chainStep, 0)
    }
}


extension GameStoreTests {
    func testFavoriteFriendActivityAwardsBonusXP() { let (store,_)=makeStore(); XCTAssertTrue(store.inviteFriend("luna")); XCTAssertTrue(store.socialActivity("dance",with:"luna")); XCTAssertEqual(store.friendshipXP(for:"luna"),25); XCTAssertEqual(store.hangoutCount(for:"luna"),1) }
    func testSocialActivityRequiresInvitedFriend() { let (store,_)=makeStore(); XCTAssertFalse(store.socialActivity("garden",with:"ivy")); XCTAssertEqual(store.friendshipXP(for:"ivy"),0) }
    func testFriendshipProgressPersists() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(first.inviteFriend("rio")); XCTAssertTrue(first.socialActivity("decorate",with:"rio")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.socialProgress.activeFriendID,"rio"); XCTAssertEqual(restored.friendshipXP(for:"rio"),25) }
}

extension GameStoreTests {
    func testInvitedFriendCanMoveIntoHouseRoom() { let (store,_)=makeStore(); XCTAssertTrue(store.inviteFriend("ivy")); XCTAssertTrue(store.moveFriend(to:"garden")); XCTAssertEqual(store.socialProgress.friendRoomID,"garden"); XCTAssertFalse(store.moveFriend(to:"moon")) }
    func testFriendLevelUnlocksPartyMiniGames() { let (store,_)=makeStore(); XCTAssertTrue(store.inviteFriend("luna")); XCTAssertFalse(store.playFriendMiniGame("teaParty",with:"luna")); XCTAssertTrue(store.socialActivity("dance",with:"luna")); XCTAssertTrue(store.socialActivity("dance",with:"luna")); XCTAssertEqual(store.friendshipLevel(for:"luna"),2); XCTAssertTrue(store.playFriendMiniGame("teaParty",with:"luna")); XCTAssertEqual(store.socialProgress.partyWins,1) }
    func testFriendRoomAndPartyProgressPersist() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("rio"); _=first.moveFriend(to:"kitchen"); _=first.socialActivity("decorate",with:"rio"); _=first.socialActivity("decorate",with:"rio"); _=first.playFriendMiniGame("teaParty",with:"rio"); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.socialProgress.friendRoomID,"kitchen"); XCTAssertEqual(restored.socialProgress.partyWins,1) }
}


extension GameStoreTests {
    func testPlayerSettingsPersistAcrossLaunches() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); first.updateSettings(soundEnabled:false,hapticsEnabled:false,reducedMotion:true,purchaseConfirmation:true); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.playerSettings,PlayerSettings(soundEnabled:false,hapticsEnabled:false,reducedMotion:true,purchaseConfirmation:true)) }
    func testReducedMotionChangesAnimationDuration() { let (store,_)=makeStore(); XCTAssertEqual(store.motionAnimationDuration,0.28,accuracy:0.001); store.updateSettings(reducedMotion:true); XCTAssertEqual(store.motionAnimationDuration,0,accuracy:0.001) }
    func testResetProgressRestoresSafeSettingsDefaults() { let (store,_)=makeStore(); store.updateSettings(soundEnabled:false,hapticsEnabled:false,reducedMotion:true,purchaseConfirmation:false); store.resetProgress(); XCTAssertEqual(store.playerSettings,PlayerSettings()) }

    func testOnboardingCompletionPersists() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); XCTAssertFalse(first.playerSettings.hasCompletedOnboarding); first.completeOnboarding(); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(restored.playerSettings.hasCompletedOnboarding) }
    func testCorruptPrimaryRecoversFromBackup() { let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:40); first.reward(coins:10); d.set(Data("broken".utf8),forKey:"save"); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.coins,540) }
    func testFreshInstallKeepsSafeOnboardingDefaults() { let (store,_)=makeStore(); XCTAssertFalse(store.playerSettings.hasCompletedOnboarding); XCTAssertTrue(store.playerSettings.purchaseConfirmation); XCTAssertFalse(store.playerSettings.reducedMotion) }
}

extension GameStoreTests {
    func testLoadSanitizesOutOfRangeNeedsAndCounters() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save")
        for _ in 0..<8 { _=first.performInteraction("sleep",in:"bedroom") }
        first.reward(coins:10)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["coins"] = -500; json["characterNeeds"]=["energy":999,"fun":-5,"hygiene":200,"hunger":-9]; json["petNeeds"]=["hunger":500,"happiness":-2,"energy":101]
        json["dailyLifeProgress"]=["day":0,"phaseIndex":99,"chainStep":99,"streak":-3,"lastCompletedDay":-1,"phaseActionCounts":["sleep":-8]]
        d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let restored=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(restored.coins,0); XCTAssertEqual(restored.characterNeeds.energy,100); XCTAssertEqual(restored.characterNeeds.fun,0); XCTAssertEqual(restored.petNeeds.hunger,100); XCTAssertEqual(restored.petNeeds.happiness,0)
        XCTAssertEqual(restored.dailyLifeProgress.day,1); XCTAssertEqual(restored.dailyLifeProgress.phaseIndex,2); XCTAssertEqual(restored.dailyLifeProgress.chainStep,2); XCTAssertEqual(restored.dailyLifeProgress.streak,0)
    }
    func testLoadDropsUnknownCatalogReferences() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:1)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["selectedOutfitID"]="ghost"; json["ownedOutfitIDs"]=["ghost"]; json["ownedRoomItemIDs"]=["ghost"]; json["selectedItemsByRoom"]=["moon":"ghost","living":"ghost"]
        d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let restored=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(restored.selectedOutfitID,"sunny"); XCTAssertTrue(restored.ownedOutfitIDs.contains("sunny")); XCTAssertFalse(restored.ownedOutfitIDs.contains("ghost")); XCTAssertEqual(restored.selectedItem(in:"living").id,"sofa")
    }
    func testLoadRepairsInvalidPetAndSocialLocations() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:1)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["petProfile"]=["name":"Pip","species":"dragon","roomID":"moon"]; json["socialProgress"]=["friendshipXP":["ghost":50],"hangouts":["ghost":2],"activeFriendID":"ghost","friendRoomID":"moon","partyWins":-2]
        d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let restored=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(restored.petProfile.species,"cat"); XCTAssertEqual(restored.petProfile.roomID,"living"); XCTAssertNil(restored.socialProgress.activeFriendID); XCTAssertNil(restored.socialProgress.friendRoomID); XCTAssertEqual(restored.socialProgress.partyWins,0)
    }
}


extension GameStoreTests {
    func testSanitizedStateIsPersistedAcrossSubsequentLaunch() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:1)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["coins"] = -77; json["characterNeeds"]=["energy":900,"fun":-10,"hygiene":75,"hunger":60]
        d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let repaired=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(repaired.coins,0); XCTAssertEqual(repaired.characterNeeds.energy,100); XCTAssertEqual(repaired.characterNeeds.fun,0)
        let relaunched=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(relaunched.coins,0); XCTAssertEqual(relaunched.characterNeeds.energy,100); XCTAssertEqual(relaunched.characterNeeds.fun,0)
    }
    func testRepairDoesNotReplaceLastKnownGoodBackup() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:40); first.reward(coins:10)
        let backupBefore=d.data(forKey:"save.backup")
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["coins"] = -99; d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        _=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(d.data(forKey:"save.backup"), backupBefore)
    }
}


extension GameStoreTests {
    func testLegacySaveWithoutSchemaVersionStillMigrates() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:37)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json.removeValue(forKey:"schemaVersion"); d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let restored=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(restored.coins,537)
        guard let migrated=d.data(forKey:"save"), let migratedJSON=(try? JSONSerialization.jsonObject(with:migrated)) as? [String:Any] else { return XCTFail("migrated save missing") }
        XCTAssertEqual(migratedJSON["schemaVersion"] as? Int, GameStore.currentSaveSchemaVersion)
    }
    func testFuturePrimarySchemaFallsBackToCompatibleBackup() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite)
        let first=GameStore(defaults:d,saveKey:"save"); first.reward(coins:40); first.reward(coins:10)
        guard let data=d.data(forKey:"save"), var json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return XCTFail("save JSON missing") }
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 100; json["coins"] = 999999
        d.set(try! JSONSerialization.data(withJSONObject:json),forKey:"save")
        let restored=GameStore(defaults:d,saveKey:"save")
        XCTAssertEqual(restored.coins,540)
    }
}


extension GameStoreTests {
    func testExpandedFriendRosterUsesOriginalCharacters() {
        let (store,_)=makeStore()
        XCTAssertEqual(store.friends.count,5)
        XCTAssertEqual(Set(store.friends.map(\.id)),Set(["luna","rio","ivy","nova","milo"]))
        XCTAssertEqual(store.friends.first(where:{$0.id=="nova"})?.favoriteActivity,"style")
        XCTAssertEqual(store.friends.first(where:{$0.id=="milo"})?.favoriteActivity,"cook")
    }
    func testNewSocialActivitiesRewardFavoriteFriendMore() {
        let (store,_)=makeStore()
        XCTAssertTrue(store.inviteFriend("nova")); let before=store.friendshipXP(for:"nova")
        XCTAssertTrue(store.socialActivity("style",with:"nova")); let favoriteGain=store.friendshipXP(for:"nova")-before
        XCTAssertTrue(store.socialActivity("cook",with:"nova")); let normalGain=store.friendshipXP(for:"nova")-before-favoriteGain
        XCTAssertGreaterThan(favoriteGain,normalGain)
    }
    func testCookAndStyleAreUnlockedBaseFriendActivities() {
        let (store,_)=makeStore()
        let activities=store.unlockedFriendActivities(for:"milo")
        XCTAssertTrue(activities.contains("cook")); XCTAssertTrue(activities.contains("style"))
    }
}


extension GameStoreTests {
    func testFriendQuestRequiresThreeFavoriteHangoutsAndRewardsOnce() {
        let (store,_)=makeStore(); XCTAssertTrue(store.inviteFriend("ivy")); let coins=store.coins; let stars=store.stars
        XCTAssertFalse(store.claimFriendQuest("ivy")); for _ in 0..<3 { XCTAssertTrue(store.socialActivity("garden",with:"ivy")) }
        XCTAssertEqual(store.friendQuestProgress(for:"ivy"),3); XCTAssertTrue(store.claimFriendQuest("ivy")); XCTAssertEqual(store.coins,coins+105); XCTAssertEqual(store.stars,stars+2); XCTAssertFalse(store.claimFriendQuest("ivy"))
    }
    func testFriendQuestIgnoresNonFavoriteHangouts() {
        let (store,_)=makeStore(); _=store.inviteFriend("milo"); for _ in 0..<4 { _=store.socialActivity("dance",with:"milo") }; XCTAssertEqual(store.friendQuestProgress(for:"milo"),0); XCTAssertFalse(store.claimFriendQuest("milo"))
    }
    func testClaimedFriendQuestPersists() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("nova"); for _ in 0..<3 { _=first.socialActivity("style",with:"nova") }; XCTAssertTrue(first.claimFriendQuest("nova")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(restored.isFriendQuestClaimed("nova")); XCTAssertFalse(restored.claimFriendQuest("nova"))
    }
}


extension GameStoreTests {
    func testSecondFriendStoryQuestStaysLockedUntilFirstQuestClaimed() {
        let (store,_)=makeStore(); _=store.inviteFriend("luna")
        XCTAssertEqual(store.friendStoryPartyProgress(for:"luna"),0); XCTAssertFalse(store.claimFriendStoryParty("luna"))
    }
    func testSecondFriendStoryQuestCountsPartyMomentsAndRewardsOnce() {
        let (store,_)=makeStore(); _=store.inviteFriend("luna")
        for _ in 0..<3 { _=store.socialActivity("dance",with:"luna") }; XCTAssertTrue(store.claimFriendQuest("luna"))
        XCTAssertTrue(store.playFriendMiniGame("teaParty",with:"luna")); XCTAssertTrue(store.playFriendMiniGame("teaParty",with:"luna"))
        let coins=store.coins, stars=store.stars; XCTAssertEqual(store.friendStoryPartyProgress(for:"luna"),2); XCTAssertTrue(store.claimFriendStoryParty("luna")); XCTAssertEqual(store.coins,coins+80); XCTAssertEqual(store.stars,stars+3); XCTAssertFalse(store.claimFriendStoryParty("luna"))
    }
    func testSecondFriendStoryQuestPersistsAcrossLaunch() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("rio"); for _ in 0..<3 { _=first.socialActivity("decorate",with:"rio") }; _=first.claimFriendQuest("rio"); _=first.playFriendMiniGame("teaParty",with:"rio"); _=first.playFriendMiniGame("teaParty",with:"rio"); XCTAssertTrue(first.claimFriendStoryParty("rio")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(restored.isFriendStoryPartyClaimed("rio")); XCTAssertFalse(restored.claimFriendStoryParty("rio"))
    }
}


extension GameStoreTests {
    func testThirdFriendStoryQuestUnlocksOnlyAfterPartyChapter() {
        let (store,_)=makeStore(); _=store.inviteFriend("ivy")
        for _ in 0..<3 { _=store.socialActivity("garden",with:"ivy") }; _=store.claimFriendQuest("ivy")
        XCTAssertEqual(store.friendStoryRoomProgress(for:"ivy"),0); XCTAssertFalse(store.claimFriendStoryRoom("ivy"))
    }
    func testThirdFriendStoryQuestRequiresTargetRoomAndFavoriteActivity() {
        let (store,_)=makeStore(); _=store.inviteFriend("milo")
        for _ in 0..<3 { _=store.socialActivity("cook",with:"milo") }; _=store.claimFriendQuest("milo")
        _=store.playFriendMiniGame("teaParty",with:"milo"); _=store.playFriendMiniGame("teaParty",with:"milo"); _=store.claimFriendStoryParty("milo")
        _=store.socialActivity("cook",with:"milo"); XCTAssertEqual(store.friendStoryRoomProgress(for:"milo"),0)
        _=store.moveFriend(to:"kitchen"); _=store.socialActivity("dance",with:"milo"); XCTAssertEqual(store.friendStoryRoomProgress(for:"milo"),0)
        _=store.socialActivity("cook",with:"milo"); _=store.socialActivity("cook",with:"milo"); XCTAssertEqual(store.friendStoryRoomProgress(for:"milo"),2)
        let coins=store.coins, stars=store.stars; XCTAssertTrue(store.claimFriendStoryRoom("milo")); XCTAssertEqual(store.coins,coins+100); XCTAssertEqual(store.stars,stars+4); XCTAssertFalse(store.claimFriendStoryRoom("milo"))
    }
    func testThirdFriendStoryQuestClaimPersistsAcrossLaunch() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("ivy"); for _ in 0..<3 { _=first.socialActivity("garden",with:"ivy") }; _=first.claimFriendQuest("ivy"); _=first.playFriendMiniGame("teaParty",with:"ivy"); _=first.playFriendMiniGame("teaParty",with:"ivy"); _=first.claimFriendStoryParty("ivy"); _=first.moveFriend(to:"garden"); _=first.socialActivity("garden",with:"ivy"); _=first.socialActivity("garden",with:"ivy"); XCTAssertTrue(first.claimFriendStoryRoom("ivy")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(restored.isFriendStoryRoomClaimed("ivy")); XCTAssertFalse(restored.claimFriendStoryRoom("ivy"))
    }
}


extension GameStoreTests {
    func testKeepsakeStaysLockedUntilRoomChapterClaimed() {
        let (store,_)=makeStore(); XCTAssertNotNil(store.friendKeepsake(for:"luna")); XCTAssertFalse(store.claimFriendKeepsake("luna")); XCTAssertTrue(store.ownedFriendKeepsakes.isEmpty)
    }
    func testEachFriendHasUniqueOriginalKeepsake() {
        let (store,_)=makeStore(); let keepsakes=store.friends.compactMap{store.friendKeepsake(for:$0.id)}
        XCTAssertEqual(keepsakes.count,5); XCTAssertEqual(Set(keepsakes.map(\.id)).count,5); XCTAssertEqual(Set(keepsakes.map(\.name)).count,5)
    }
    func testKeepsakeClaimPersistsAfterCompletedStory() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("milo"); for _ in 0..<3 { _=first.socialActivity("cook",with:"milo") }; _=first.claimFriendQuest("milo"); _=first.playFriendMiniGame("teaParty",with:"milo"); _=first.playFriendMiniGame("teaParty",with:"milo"); _=first.claimFriendStoryParty("milo"); _=first.moveFriend(to:"kitchen"); _=first.socialActivity("cook",with:"milo"); _=first.socialActivity("cook",with:"milo"); _=first.claimFriendStoryRoom("milo"); XCTAssertTrue(first.claimFriendKeepsake("milo")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertTrue(restored.isFriendKeepsakeClaimed("milo")); XCTAssertEqual(restored.ownedFriendKeepsakes.map(\.friendID),["milo"]); XCTAssertFalse(restored.claimFriendKeepsake("milo"))
    }
}


extension GameStoreTests {
    func testOwnedKeepsakeCanBeDisplayedInOnlyOneRoom() {
        let (store,_)=makeStore(); _=store.inviteFriend("luna"); for _ in 0..<3 { _=store.socialActivity("dance",with:"luna") }; _=store.claimFriendQuest("luna"); _=store.playFriendMiniGame("teaParty",with:"luna"); _=store.playFriendMiniGame("teaParty",with:"luna"); _=store.claimFriendStoryParty("luna"); _=store.moveFriend(to:"living"); _=store.socialActivity("dance",with:"luna"); _=store.socialActivity("dance",with:"luna"); _=store.claimFriendStoryRoom("luna"); XCTAssertTrue(store.claimFriendKeepsake("luna")); XCTAssertTrue(store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living")); XCTAssertEqual(store.displayedFriendKeepsakes(in:"living").map(\.id),["keepsake.luna"]); XCTAssertTrue(store.setFriendKeepsake("keepsake.luna",displayed:true,in:"bedroom")); XCTAssertTrue(store.displayedFriendKeepsakes(in:"living").isEmpty); XCTAssertEqual(store.displayedFriendKeepsakes(in:"bedroom").map(\.id),["keepsake.luna"])
    }
    func testUnownedKeepsakeCannotBeDisplayed() {
        let (store,_)=makeStore(); XCTAssertFalse(store.setFriendKeepsake("keepsake.ivy",displayed:true,in:"garden")); XCTAssertTrue(store.displayedFriendKeepsakes(in:"garden").isEmpty)
    }
    func testKeepsakeDisplayPersistsAcrossLaunch() {
        let suite="DreamLifeHouseTests.\(UUID().uuidString)"; let d=UserDefaults(suiteName:suite)!; d.removePersistentDomain(forName:suite); let first=GameStore(defaults:d,saveKey:"save"); _=first.inviteFriend("milo"); for _ in 0..<3 { _=first.socialActivity("cook",with:"milo") }; _=first.claimFriendQuest("milo"); _=first.playFriendMiniGame("teaParty",with:"milo"); _=first.playFriendMiniGame("teaParty",with:"milo"); _=first.claimFriendStoryParty("milo"); _=first.moveFriend(to:"kitchen"); _=first.socialActivity("cook",with:"milo"); _=first.socialActivity("cook",with:"milo"); _=first.claimFriendStoryRoom("milo"); _=first.claimFriendKeepsake("milo"); XCTAssertTrue(first.setFriendKeepsake("keepsake.milo",displayed:true,in:"kitchen")); let restored=GameStore(defaults:d,saveKey:"save"); XCTAssertEqual(restored.displayedFriendKeepsakes(in:"kitchen").map(\.id),["keepsake.milo"])
    }
}


extension GameStoreTests {
    func testDisplayedKeepsakeCanBeInteractedWithAndRewardsFriendship() {
        let (store,_)=makeStore(); _=store.inviteFriend("luna"); for _ in 0..<3 { _=store.socialActivity("dance",with:"luna") }; _=store.claimFriendQuest("luna"); _=store.playFriendMiniGame("teaParty",with:"luna"); _=store.playFriendMiniGame("teaParty",with:"luna"); _=store.claimFriendStoryParty("luna"); _=store.moveFriend(to:"living"); _=store.socialActivity("dance",with:"luna"); _=store.socialActivity("dance",with:"luna"); _=store.claimFriendStoryRoom("luna"); _=store.claimFriendKeepsake("luna"); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); let xp=store.friendshipXP(for:"luna"); XCTAssertTrue(store.interactWithDisplayedKeepsake("keepsake.luna",in:"living")); XCTAssertEqual(store.friendshipXP(for:"luna"),xp+1); XCTAssertEqual(store.keepsakeInteractionCount("keepsake.luna"),1)
    }
    func testKeepsakeInteractionRequiresDisplayedRoom() {
        let (store,_)=makeStore(); XCTAssertFalse(store.interactWithDisplayedKeepsake("keepsake.ivy",in:"garden")); XCTAssertEqual(store.keepsakeInteractionCount("keepsake.ivy"),0)
    }
    func testDisplayedKeepsakeRoomLookupTracksMoves() {
        let (store,_)=makeStore(); _=store.inviteFriend("milo"); for _ in 0..<3 { _=store.socialActivity("cook",with:"milo") }; _=store.claimFriendQuest("milo"); _=store.playFriendMiniGame("teaParty",with:"milo"); _=store.playFriendMiniGame("teaParty",with:"milo"); _=store.claimFriendStoryParty("milo"); _=store.moveFriend(to:"kitchen"); _=store.socialActivity("cook",with:"milo"); _=store.socialActivity("cook",with:"milo"); _=store.claimFriendStoryRoom("milo"); _=store.claimFriendKeepsake("milo"); _=store.setFriendKeepsake("keepsake.milo",displayed:true,in:"kitchen"); XCTAssertEqual(store.roomForDisplayedKeepsake("keepsake.milo"),"kitchen"); _=store.setFriendKeepsake("keepsake.milo",displayed:true,in:"living"); XCTAssertEqual(store.roomForDisplayedKeepsake("keepsake.milo"),"living")
    }
}

extension GameStoreTests {
    private func unlockKeepsake(_ friendID:String, activity:String, room:String, in store:GameStore) {
        _=store.inviteFriend(friendID); for _ in 0..<3 { _=store.socialActivity(activity,with:friendID) }; _=store.claimFriendQuest(friendID)
        _=store.playFriendMiniGame("teaParty",with:friendID); _=store.playFriendMiniGame("teaParty",with:friendID); _=store.claimFriendStoryParty(friendID)
        _=store.moveFriend(to:room); _=store.socialActivity(activity,with:friendID); _=store.socialActivity(activity,with:friendID); _=store.claimFriendStoryRoom(friendID); _=store.claimFriendKeepsake(friendID)
    }
    func testDailyMemorySparkCountsDistinctKeepsakesOnly() {
        let (store,_)=makeStore(); unlockKeepsake("luna",activity:"dance",room:"living",in:store); unlockKeepsake("milo",activity:"cook",room:"kitchen",in:store)
        _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.setFriendKeepsake("keepsake.milo",displayed:true,in:"kitchen")
        _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); XCTAssertEqual(store.dailyKeepsakeMemoryProgress,1)
        _=store.interactWithDisplayedKeepsake("keepsake.milo",in:"kitchen"); XCTAssertEqual(store.dailyKeepsakeMemoryProgress,2)
    }
    func testDailyMemorySparkRewardCanOnlyBeClaimedOncePerDay() {
        let (store,_)=makeStore(); unlockKeepsake("luna",activity:"dance",room:"living",in:store); unlockKeepsake("milo",activity:"cook",room:"kitchen",in:store)
        _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.setFriendKeepsake("keepsake.milo",displayed:true,in:"kitchen"); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.interactWithDisplayedKeepsake("keepsake.milo",in:"kitchen")
        let coins=store.coins, stars=store.stars; XCTAssertTrue(store.claimDailyKeepsakeMemory()); XCTAssertEqual(store.coins,coins+40); XCTAssertEqual(store.stars,stars+1); XCTAssertFalse(store.claimDailyKeepsakeMemory())
    }
    func testDailyMemorySparkResetsOnNextInGameDay() {
        let (store,_)=makeStore(); unlockKeepsake("luna",activity:"dance",room:"living",in:store); unlockKeepsake("milo",activity:"cook",room:"kitchen",in:store)
        _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.setFriendKeepsake("keepsake.milo",displayed:true,in:"kitchen"); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.interactWithDisplayedKeepsake("keepsake.milo",in:"kitchen"); XCTAssertTrue(store.claimDailyKeepsakeMemory())
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyKeepsakeMemoryProgress,0); XCTAssertFalse(store.isDailyKeepsakeMemoryClaimed)
    }
}


extension GameStoreTests {
    private func unlockSpotlightKeepsake(_ friendID:String, activity:String, room:String, in store:GameStore) {
        _=store.inviteFriend(friendID); for _ in 0..<3 { _=store.socialActivity(activity,with:friendID) }; _=store.claimFriendQuest(friendID)
        _=store.playFriendMiniGame("teaParty",with:friendID); _=store.playFriendMiniGame("teaParty",with:friendID); _=store.claimFriendStoryParty(friendID)
        _=store.moveFriend(to:room); _=store.socialActivity(activity,with:friendID); _=store.socialActivity(activity,with:friendID); _=store.claimFriendStoryRoom(friendID); _=store.claimFriendKeepsake(friendID)
    }
    func testMemorySpotlightRotatesAcrossOwnedKeepsakesByGameDay() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); unlockSpotlightKeepsake("milo",activity:"cook",room:"kitchen",in:store)
        let first=store.dailyMemorySpotlightKeepsake?.id; _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase()
        XCTAssertNotNil(first); XCTAssertNotEqual(store.dailyMemorySpotlightKeepsake?.id,first)
    }
    func testMemorySpotlightRequiresTodaysSpecificKeepsake() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); unlockSpotlightKeepsake("milo",activity:"cook",room:"kitchen",in:store)
        for k in store.ownedFriendKeepsakes { _=store.setFriendKeepsake(k.id,displayed:true,in:k.friendID == "milo" ? "kitchen" : "living") }
        let target=store.dailyMemorySpotlightKeepsake!; let other=store.ownedFriendKeepsakes.first{$0.id != target.id}!
        _=store.interactWithDisplayedKeepsake(other.id,in:store.roomForDisplayedKeepsake(other.id)!); XCTAssertFalse(store.isDailyMemorySpotlightReady); XCTAssertFalse(store.claimDailyMemorySpotlight())
        _=store.interactWithDisplayedKeepsake(target.id,in:store.roomForDisplayedKeepsake(target.id)!); XCTAssertTrue(store.isDailyMemorySpotlightReady)
    }
    func testMemorySpotlightRewardIsOneTimeAndResetsNextGameDay() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living")
        _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); let coins=store.coins; XCTAssertTrue(store.claimDailyMemorySpotlight()); XCTAssertEqual(store.coins,coins+20); XCTAssertFalse(store.claimDailyMemorySpotlight())
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertFalse(store.isDailyMemorySpotlightClaimed); XCTAssertFalse(store.isDailyMemorySpotlightReady)
    }
    func testSpotlightFriendMomentRequiresVisitedKeepsakeAndCorrectFriendRoomActivity() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.inviteFriend("luna")
        XCTAssertFalse(store.socialActivity("dance",with:"luna") && store.isDailySpotlightFriendMomentReady)
        _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.socialActivity("decorate",with:"luna"); XCTAssertFalse(store.isDailySpotlightFriendMomentReady)
        _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.isDailySpotlightFriendMomentReady)
    }
    func testSpotlightFriendMomentRejectsWrongFriend() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.inviteFriend("rio"); _=store.socialActivity("decorate",with:"rio"); XCTAssertFalse(store.isDailySpotlightFriendMomentReady)
    }
    func testSpotlightFriendMomentRewardIsOneTime() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living"); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); let coins=store.coins; let stars=store.stars; XCTAssertTrue(store.claimDailySpotlightFriendMoment()); XCTAssertEqual(store.coins,coins+30); XCTAssertEqual(store.stars,stars+1); XCTAssertFalse(store.claimDailySpotlightFriendMoment())
    }

}

extension GameStoreTests {
    func testSpotlightFriendChallengeRotatesAcrossThreeTemplates() {
        let (store,_)=makeStore()
        XCTAssertEqual(store.dailySpotlightFriendChallengeKind,"favorite")
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase()
        XCTAssertEqual(store.dailySpotlightFriendChallengeKind,"decorate")
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase()
        XCTAssertEqual(store.dailySpotlightFriendChallengeKind,"teaParty")
    }
    func testRotatingDecorateChallengeRejectsFavoriteActionOnDayTwo() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living")
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.inviteFriend("luna")
        _=store.socialActivity("dance",with:"luna"); XCTAssertFalse(store.isDailySpotlightFriendMomentReady)
        _=store.socialActivity("decorate",with:"luna"); XCTAssertTrue(store.isDailySpotlightFriendMomentReady)
    }
    func testRotatingTeaPartyChallengeUsesMiniGamePathOnDayThree() {
        let (store,_)=makeStore(); unlockSpotlightKeepsake("luna",activity:"dance",room:"living",in:store); _=store.setFriendKeepsake("keepsake.luna",displayed:true,in:"living")
        for _ in 0..<2 { _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase() }
        _=store.interactWithDisplayedKeepsake("keepsake.luna",in:"living"); _=store.inviteFriend("luna"); XCTAssertTrue(store.playFriendMiniGame("teaParty",with:"luna")); XCTAssertTrue(store.isDailySpotlightFriendMomentReady)
    }
}


extension GameStoreTests {
    func testRoomSurpriseRotatesThroughRooms() {
        let (store,_)=makeStore(); XCTAssertEqual(store.dailyRoomSurpriseRoomID,"living"); XCTAssertEqual(store.dailyRoomSurpriseAction,"dance")
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyRoomSurpriseRoomID,"bedroom"); XCTAssertEqual(store.dailyRoomSurpriseAction,"sleep")
    }
    func testRoomSurpriseRequiresTodaysRoomActivity() {
        let (store,_)=makeStore(); XCTAssertFalse(store.performInteraction("sleep",in:"bedroom") && store.isDailyRoomSurpriseReady); XCTAssertFalse(store.isDailyRoomSurpriseReady)
        XCTAssertTrue(store.performInteraction("dance",in:"living")); XCTAssertTrue(store.isDailyRoomSurpriseReady)
    }
    func testRoomSurpriseRewardIsOneTimeAndResetsNextDay() {
        let (store,_)=makeStore(); _=store.performInteraction("dance",in:"living"); let coins=store.coins, stars=store.stars
        XCTAssertTrue(store.claimDailyRoomSurprise()); XCTAssertEqual(store.coins,coins+25); XCTAssertEqual(store.stars,stars+1); XCTAssertFalse(store.claimDailyRoomSurprise())
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertFalse(store.isDailyRoomSurpriseReady); XCTAssertFalse(store.isDailyRoomSurpriseClaimed)
    }
}


extension GameStoreTests {
    func testRoomSurpriseBuddyRequiresDiscoveryCorrectFriendRoomAndFavoriteActivity() {
        let (store,_)=makeStore(); _=store.inviteFriend("luna")
        _=store.socialActivity("dance",with:"luna"); XCTAssertFalse(store.isDailyRoomSurpriseBuddyReady)
        _=store.performInteraction("dance",in:"living"); _=store.moveFriend(to:"bedroom"); _=store.socialActivity("dance",with:"luna"); XCTAssertFalse(store.isDailyRoomSurpriseBuddyReady)
        _=store.moveFriend(to:"living"); _=store.socialActivity("decorate",with:"luna"); XCTAssertFalse(store.isDailyRoomSurpriseBuddyReady)
        _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.isDailyRoomSurpriseBuddyReady)
    }
    func testRoomSurpriseBuddyRewardIsOneTime() {
        let (store,_)=makeStore(); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); let coins=store.coins, stars=store.stars
        XCTAssertTrue(store.claimDailyRoomSurpriseBuddy()); XCTAssertEqual(store.coins,coins+30); XCTAssertEqual(store.stars,stars+2); XCTAssertFalse(store.claimDailyRoomSurpriseBuddy())
    }
    func testRoomSurpriseBuddyRotatesWithGameDayAndResets() {
        let (store,_)=makeStore(); XCTAssertEqual(store.dailyRoomSurpriseBuddy.id,"luna"); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.isDailyRoomSurpriseBuddyReady)
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyRoomSurpriseBuddy.id,"rio"); XCTAssertFalse(store.isDailyRoomSurpriseBuddyReady); XCTAssertFalse(store.isDailyRoomSurpriseBuddyClaimed)
    }
}


extension GameStoreTests {
    func testSurpriseBuddyEventsRotateWithRooms() {
        let (store,_)=makeStore(); XCTAssertEqual(store.dailyRoomSurpriseBuddyEventTitle,"Living Room Dance-Off"); XCTAssertEqual(store.dailyRoomSurpriseBuddyReward.coins,30); XCTAssertEqual(store.dailyRoomSurpriseBuddyReward.stars,2)
        _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyRoomSurpriseBuddyEventTitle,"Bedroom Pillow Fort"); XCTAssertEqual(store.dailyRoomSurpriseBuddyReward.coins,45); XCTAssertEqual(store.dailyRoomSurpriseBuddyReward.stars,1)
    }
    func testSurpriseBuddyUsesRoomSpecificReward() {
        let (store,_)=makeStore(); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); let coins=store.coins, stars=store.stars
        XCTAssertTrue(store.claimDailyRoomSurpriseBuddy()); XCTAssertEqual(store.coins,coins+30); XCTAssertEqual(store.stars,stars+2)
    }
    func testSurpriseBuddyRewardChangesOnNextDay() {
        let (store,_)=makeStore(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); _=store.advanceDayPhase(); XCTAssertEqual(store.dailyRoomSurpriseRoomID,"bedroom"); XCTAssertEqual(store.dailyRoomSurpriseBuddy.id,"rio"); XCTAssertEqual(store.dailyRoomSurpriseBuddyReward.coins,45)
    }
}


extension GameStoreTests {
    func testSurpriseBuddyAwardsRoomBadge() {
        let (store,_)=makeStore(); XCTAssertFalse(store.hasSurpriseBadge(for:"living")); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.claimDailyRoomSurpriseBuddy()); XCTAssertTrue(store.hasSurpriseBadge(for:"living")); XCTAssertEqual(store.earnedSurpriseBadges.map(\.id),["badge.living"])
    }
    func testSurpriseBadgeIsNotDuplicatedByRepeatClaim() {
        let (store,_)=makeStore(); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.claimDailyRoomSurpriseBuddy()); XCTAssertFalse(store.claimDailyRoomSurpriseBuddy()); XCTAssertEqual(store.earnedSurpriseBadges.filter{$0.id=="badge.living"}.count,1)
    }
    func testSurpriseBadgePersistsAcrossReload() {
        let (store,defaults)=makeStore(); _=store.performInteraction("dance",in:"living"); _=store.inviteFriend("luna"); _=store.socialActivity("dance",with:"luna"); XCTAssertTrue(store.claimDailyRoomSurpriseBuddy()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.hasSurpriseBadge(for:"living"))
    }
}


extension GameStoreTests {
    func testSurpriseBadgeCollectionProgressTracksUniqueBadges() {
        let (store,_)=makeStore(); XCTAssertEqual(store.surpriseBadgeProgress,0); XCTAssertFalse(store.isSurpriseBadgeCollectionComplete)
        for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }
        XCTAssertEqual(store.surpriseBadgeProgress,5); XCTAssertTrue(store.isSurpriseBadgeCollectionComplete)
    }
    func testSurpriseBadgeCollectionRewardRequiresAllFiveAndIsOneTime() {
        let (store,_)=makeStore(); XCTAssertFalse(store.claimSurpriseBadgeCollectionReward())
        for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }
        let coins=store.coins, stars=store.stars; XCTAssertTrue(store.claimSurpriseBadgeCollectionReward()); XCTAssertEqual(store.coins,coins+150); XCTAssertEqual(store.stars,stars+5); XCTAssertFalse(store.claimSurpriseBadgeCollectionReward())
    }
    func testSurpriseBadgeCollectionRewardPersistsAcrossReload() {
        let (store,defaults)=makeStore(); for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }; XCTAssertTrue(store.claimSurpriseBadgeCollectionReward())
        let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isSurpriseBadgeCollectionRewardClaimed); XCTAssertTrue(reloaded.isSurpriseBadgeCollectionComplete)
    }
}


extension GameStoreTests {
    func testDreamHouseTrophyRequiresCompletedCollectionReward() {
        let (store,_)=makeStore(); XCTAssertFalse(store.isDreamHouseTrophyUnlocked); XCTAssertFalse(store.interactWithDreamHouseTrophy(in:"living"))
        for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }; XCTAssertTrue(store.claimSurpriseBadgeCollectionReward()); XCTAssertTrue(store.isDreamHouseTrophyUnlocked)
    }
    func testDreamHouseTrophyOnlyInteractsInLivingRoomAndBoostsFun() {
        let (store,_)=makeStore(); for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }; _=store.claimSurpriseBadgeCollectionReward(); store.characterNeeds.fun=90
        XCTAssertFalse(store.interactWithDreamHouseTrophy(in:"bedroom")); XCTAssertTrue(store.interactWithDreamHouseTrophy(in:"living")); XCTAssertEqual(store.characterNeeds.fun,94); XCTAssertEqual(store.dreamHouseTrophyVisitCount,1)
    }
    func testDreamHouseTrophyVisitsPersistAcrossReload() {
        let (store,defaults)=makeStore(); for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }; _=store.claimSurpriseBadgeCollectionReward(); _=store.interactWithDreamHouseTrophy(in:"living")
        let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isDreamHouseTrophyUnlocked); XCTAssertEqual(reloaded.dreamHouseTrophyVisitCount,1)
    }
}


extension GameStoreTests {
    func testDreamHouseTrophyMasteryLevelsAdvanceAtMilestones() {
        let (store,_)=makeStore(); XCTAssertEqual(store.dreamHouseTrophyLevel,"Bronze")
        store.interactionCounts["trophy.dreamhouse.visits"] = 5; XCTAssertEqual(store.dreamHouseTrophyLevel,"Silver")
        store.interactionCounts["trophy.dreamhouse.visits"] = 15; XCTAssertEqual(store.dreamHouseTrophyLevel,"Gold")
        store.interactionCounts["trophy.dreamhouse.visits"] = 30; XCTAssertEqual(store.dreamHouseTrophyLevel,"Diamond")
    }
    func testDreamHouseTrophyDecorationsUnlockProgressively() {
        let (store,_)=makeStore(); XCTAssertTrue(store.unlockedTrophyDecorations.isEmpty); XCTAssertEqual(store.dreamHouseTrophyNextMilestone,5)
        store.interactionCounts["trophy.dreamhouse.visits"] = 15; XCTAssertEqual(store.unlockedTrophyDecorations,["Sparkle Garland","Memory Pedestal"]); XCTAssertEqual(store.dreamHouseTrophyNextMilestone,30)
        store.interactionCounts["trophy.dreamhouse.visits"] = 30; XCTAssertEqual(store.unlockedTrophyDecorations.count,3); XCTAssertNil(store.dreamHouseTrophyNextMilestone)
    }
    func testTrophyMasteryPersistsBecauseVisitsPersist() {
        let (store,defaults)=makeStore(); for room in ["living","bedroom","kitchen","bathroom","garden"] { store.claimedFriendQuestIDs.insert("badge.\(room)") }; _=store.claimSurpriseBadgeCollectionReward()
        store.interactionCounts["trophy.dreamhouse.visits"] = 14; _=store.interactWithDreamHouseTrophy(in:"living")
        let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertEqual(reloaded.dreamHouseTrophyLevel,"Gold"); XCTAssertEqual(reloaded.unlockedTrophyDecorations,["Sparkle Garland","Memory Pedestal"])
    }
}


extension GameStoreTests {
    func testTrophyDecorationsRequireUnlockAndLivingRoom() { let (store,_)=makeStore(); XCTAssertFalse(store.interactWithTrophyDecoration("Sparkle Garland",in:"living")); store.interactionCounts["trophy.dreamhouse.visits"] = 5; XCTAssertFalse(store.interactWithTrophyDecoration("Sparkle Garland",in:"bedroom")); XCTAssertTrue(store.interactWithTrophyDecoration("Sparkle Garland",in:"living")) }
    func testTrophyDecorationsApplyDistinctNeedEffects() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 30; store.characterNeeds.fun=80; store.characterNeeds.energy=80; XCTAssertTrue(store.interactWithTrophyDecoration("Sparkle Garland",in:"living")); XCTAssertEqual(store.characterNeeds.fun,82); XCTAssertTrue(store.interactWithTrophyDecoration("Memory Pedestal",in:"living")); XCTAssertEqual(store.characterNeeds.energy,82); XCTAssertTrue(store.interactWithTrophyDecoration("Dreamlight Crown",in:"living")); XCTAssertEqual(store.characterNeeds.fun,85); XCTAssertEqual(store.characterNeeds.energy,83) }
    func testTrophyDecorationVisitsPersist() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 30; _=store.interactWithTrophyDecoration("Dreamlight Crown",in:"living"); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertEqual(reloaded.trophyDecorationVisitCount("Dreamlight Crown"),1) }
}


extension GameStoreTests {
    func testDailyTrophyDecorationRotatesAcrossUnlockedRewards() { let (store,_)=makeStore(); XCTAssertNil(store.dailyTrophyDecorationName); store.interactionCounts["trophy.dreamhouse.visits"] = 30; XCTAssertEqual(store.dailyTrophyDecorationName,"Sparkle Garland"); store.dailyLifeProgress.day=2; XCTAssertEqual(store.dailyTrophyDecorationName,"Memory Pedestal"); store.dailyLifeProgress.day=3; XCTAssertEqual(store.dailyTrophyDecorationName,"Dreamlight Crown") }
    func testDailyTrophyDecorationBonusRequiresFreshInteractionAndPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 30; let c=store.coins; let s=store.stars; XCTAssertFalse(store.claimDailyTrophyDecorationBonus()); XCTAssertTrue(store.interactWithTrophyDecoration("Sparkle Garland",in:"living")); XCTAssertTrue(store.claimDailyTrophyDecorationBonus()); XCTAssertEqual(store.coins,c+20); XCTAssertEqual(store.stars,s+1); XCTAssertFalse(store.claimDailyTrophyDecorationBonus()) }
    func testDailyTrophyDecorationBonusPersistsAcrossReload() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 30; _=store.interactWithTrophyDecoration("Sparkle Garland",in:"living"); XCTAssertTrue(store.claimDailyTrophyDecorationBonus()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isDailyTrophyDecorationClaimed); XCTAssertFalse(reloaded.claimDailyTrophyDecorationBonus()) }
}


extension GameStoreTests {
    func testTrophyComboRequiresTwoUnlockedDecorationsAndBothTouches() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 15; XCTAssertEqual(store.dailyTrophyComboDecorations,["Sparkle Garland","Memory Pedestal"]); XCTAssertFalse(store.isDailyTrophyComboReady); _=store.interactWithTrophyDecoration("Sparkle Garland",in:"living"); XCTAssertFalse(store.isDailyTrophyComboReady); _=store.interactWithTrophyDecoration("Memory Pedestal",in:"living"); XCTAssertTrue(store.isDailyTrophyComboReady) }
    func testTrophyComboPaysOnceAndAddsFun() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 15; store.characterNeeds.fun=80; _=store.interactWithTrophyDecoration("Sparkle Garland",in:"living"); _=store.interactWithTrophyDecoration("Memory Pedestal",in:"living"); let c=store.coins, s=store.stars; XCTAssertTrue(store.claimDailyTrophyComboBonus()); XCTAssertEqual(store.coins,c+35); XCTAssertEqual(store.stars,s+1); XCTAssertEqual(store.characterNeeds.fun,84); XCTAssertFalse(store.claimDailyTrophyComboBonus()) }
    func testTrophyComboRotatesAndPersistsClaim() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"] = 30; store.dailyLifeProgress.day=2; XCTAssertEqual(store.dailyTrophyComboDecorations,["Memory Pedestal","Dreamlight Crown"]); _=store.interactWithTrophyDecoration("Memory Pedestal",in:"living"); _=store.interactWithTrophyDecoration("Dreamlight Crown",in:"living"); XCTAssertTrue(store.claimDailyTrophyComboBonus()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isDailyTrophyComboClaimed) }
}


extension GameStoreTests {
    func testWeeklyTrophyFinaleRequiresThreeComboClaimsAndAllDecorations() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"]=30; store.interactionCounts["trophy.combo.claim.day1"]=1; store.interactionCounts["trophy.combo.claim.day2"]=1; XCTAssertFalse(store.isWeeklyTrophyFinaleReady); store.interactionCounts["trophy.combo.claim.day3"]=1; XCTAssertTrue(store.isWeeklyTrophyFinaleReady) }
    func testWeeklyTrophyFinalePaysOnceAndUnlocksAuroraMobile() { let (store,_)=makeStore(); store.interactionCounts["trophy.dreamhouse.visits"]=30; for day in 1...3 { store.interactionCounts["trophy.combo.claim.day\(day)"]=1 }; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimWeeklyTrophyFinale()); XCTAssertEqual(store.coins,c+100); XCTAssertEqual(store.stars,s+3); XCTAssertTrue(store.isAuroraMobileUnlocked); XCTAssertFalse(store.claimWeeklyTrophyFinale()) }
    func testAuroraMobileRequiresUnlockAndPersists() { let (store,defaults)=makeStore(); XCTAssertFalse(store.interactWithAuroraMobile(in:"living")); store.interactionCounts["trophy.dreamhouse.visits"]=30; for day in 1...3 { store.interactionCounts["trophy.combo.claim.day\(day)"]=1 }; _=store.claimWeeklyTrophyFinale(); XCTAssertFalse(store.interactWithAuroraMobile(in:"bedroom")); XCTAssertTrue(store.interactWithAuroraMobile(in:"living")); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isAuroraMobileUnlocked); XCTAssertEqual(reloaded.interactionCounts["trophy.auroraMobile.visits"],1) }
}


extension GameStoreTests {
    func testAuroraWeeklyChainCountsDistinctDaysOnly() { let (store,_)=makeStore(); store.interactionCounts["trophy.auroraMobile.unlocked"]=1; XCTAssertTrue(store.recordAuroraDailyInteraction()); XCTAssertFalse(store.recordAuroraDailyInteraction()); XCTAssertEqual(store.auroraWeeklyInteractionProgress,1); store.dailyLifeProgress.day=2; XCTAssertTrue(store.recordAuroraDailyInteraction()); store.dailyLifeProgress.day=3; XCTAssertTrue(store.recordAuroraDailyInteraction()); XCTAssertEqual(store.auroraWeeklyInteractionProgress,3) }
    func testAuroraWeeklyRewardUnlocksPrismCharmAndPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.auroraMobile.unlocked"]=1; for day in 1...3 { store.dailyLifeProgress.day=day; _=store.recordAuroraDailyInteraction() }; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimAuroraWeeklyReward()); XCTAssertEqual(store.coins,c+60); XCTAssertEqual(store.stars,s+2); XCTAssertTrue(store.isPrismCharmUnlocked); XCTAssertFalse(store.claimAuroraWeeklyReward()) }
    func testAuroraWeeklyRewardPersistsAcrossReload() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.auroraMobile.unlocked"]=1; for day in 1...3 { store.dailyLifeProgress.day=day; _=store.recordAuroraDailyInteraction() }; _=store.claimAuroraWeeklyReward(); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isPrismCharmUnlocked); XCTAssertTrue(reloaded.isAuroraWeeklyRewardClaimed) }
}


extension GameStoreTests {
    func testPrismCharmRequiresUnlockAndLivingRoom() { let (store,_)=makeStore(); XCTAssertFalse(store.interactWithPrismCharm(in:"living")); store.interactionCounts["trophy.prismCharm.unlocked"]=1; XCTAssertFalse(store.interactWithPrismCharm(in:"bedroom")); XCTAssertTrue(store.interactWithPrismCharm(in:"living")); XCTAssertEqual(store.prismCharmVisitCount,1) }
    func testAuroraPrismComboRequiresBothDailyInteractionsAndPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.auroraMobile.unlocked"]=1; store.interactionCounts["trophy.prismCharm.unlocked"]=1; _=store.interactWithAuroraMobile(in:"living"); _=store.recordAuroraDailyInteraction(); XCTAssertFalse(store.isAuroraPrismComboReady); _=store.interactWithPrismCharm(in:"living"); XCTAssertTrue(store.isAuroraPrismComboReady); let c=store.coins,s=store.stars; XCTAssertTrue(store.claimAuroraPrismCombo()); XCTAssertEqual(store.coins,c+45); XCTAssertEqual(store.stars,s+2); XCTAssertFalse(store.claimAuroraPrismCombo()) }
    func testAuroraPrismAchievementPersistsAcrossReload() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.auroraMobile.unlocked"]=1; store.interactionCounts["trophy.prismCharm.unlocked"]=1; _=store.recordAuroraDailyInteraction(); _=store.interactWithPrismCharm(in:"living"); XCTAssertTrue(store.claimAuroraPrismCombo()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isAuroraPrismComboClaimed); XCTAssertEqual(reloaded.interactionCounts["trophy.auroraPrism.achievement"],1) }
}


extension GameStoreTests {
    func testAuroraPrismCollectionTiersAdvance() { let (store,_)=makeStore(); XCTAssertEqual(store.auroraPrismCollectionTier,"Glow Seeker"); for day in 1...3 { store.interactionCounts["trophy.auroraPrism.claim.day\(day)"]=1 }; XCTAssertEqual(store.auroraPrismCollectionCount,3); XCTAssertEqual(store.auroraPrismCollectionTier,"Prism Keeper") }
    func testAuroraPrismWeeklyProgressCountsCurrentWeekOnly() { let (store,_)=makeStore(); store.interactionCounts["trophy.auroraPrism.claim.day1"]=1; store.interactionCounts["trophy.auroraPrism.claim.day2"]=1; store.dailyLifeProgress.day=8; store.interactionCounts["trophy.auroraPrism.claim.day8"]=1; XCTAssertEqual(store.weeklyAuroraPrismProgress,1) }
    func testStarlightSuncatcherRewardRequiresThreeMomentsAndPaysOnce() { let (store,_)=makeStore(); for day in 1...2 { store.interactionCounts["trophy.auroraPrism.claim.day\(day)"]=1 }; XCTAssertFalse(store.claimAuroraPrismSeriesReward()); store.interactionCounts["trophy.auroraPrism.claim.day3"]=1; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimAuroraPrismSeriesReward()); XCTAssertEqual(store.coins,c+75); XCTAssertEqual(store.stars,s+3); XCTAssertFalse(store.claimAuroraPrismSeriesReward()) }
    func testStarlightSuncatcherInteractionAndPersistence() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; XCTAssertFalse(store.interactWithStarlightSuncatcher(in:"bedroom")); XCTAssertTrue(store.interactWithStarlightSuncatcher(in:"living")); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isStarlightSuncatcherUnlocked); XCTAssertEqual(reloaded.interactionCounts["trophy.starlightSuncatcher.visits"],1) }
}


extension GameStoreTests {
    func testRadiantSevenDayRewardGatesAndPaysOnce() { let (store,_)=makeStore(); for day in 1...7 { store.interactionCounts["trophy.auroraPrism.claim.day\(day)"]=1 }; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimMoonbeamTerrariumReward()); XCTAssertEqual(store.coins,c+125); XCTAssertEqual(store.stars,s+4); XCTAssertFalse(store.claimMoonbeamTerrariumReward()) }
    func testRadiantFourteenDayRewardGatesAndPersists() { let (store,defaults)=makeStore(); for day in 1...14 { store.interactionCounts["trophy.auroraPrism.claim.day\(day)"]=1 }; XCTAssertTrue(store.claimCelestialLanternReward()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isCelestialLanternUnlocked) }
    func testRadiantSetBonusRequiresAllThreeDecorationsAndPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; XCTAssertFalse(store.claimRadiantSetBonus()); store.interactionCounts["trophy.celestialLantern.unlocked"]=1; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimRadiantSetBonus()); XCTAssertEqual(store.coins,c+250); XCTAssertEqual(store.stars,s+8); XCTAssertFalse(store.claimRadiantSetBonus()) }
    func testNewRadiantDecorationsRequireLivingRoom() { let (store,_)=makeStore(); store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; store.interactionCounts["trophy.celestialLantern.unlocked"]=1; XCTAssertFalse(store.interactWithMoonbeamTerrarium(in:"kitchen")); XCTAssertTrue(store.interactWithMoonbeamTerrarium(in:"living")); XCTAssertFalse(store.interactWithCelestialLantern(in:"bedroom")); XCTAssertTrue(store.interactWithCelestialLantern(in:"living")) }
}


extension GameStoreTests {
    private func unlockRadiantEventSet(_ store:GameStore) { store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; store.interactionCounts["trophy.celestialLantern.unlocked"]=1 }
    func testRadiantRoomEventRequiresOrderedThreePieceSequence() { let (store,_)=makeStore(); unlockRadiantEventSet(store); XCTAssertTrue(store.interactWithMoonbeamTerrarium(in:"living")); XCTAssertEqual(store.radiantRoomEventStep,0); XCTAssertTrue(store.interactWithStarlightSuncatcher(in:"living")); XCTAssertEqual(store.radiantRoomEventStep,1); XCTAssertTrue(store.interactWithMoonbeamTerrarium(in:"living")); XCTAssertTrue(store.interactWithCelestialLantern(in:"living")); XCTAssertTrue(store.isRadiantRoomEventReady) }
    func testRadiantRoomEventPaysOncePerDayAndTracksAchievement() { let (store,_)=makeStore(); unlockRadiantEventSet(store); _=store.interactWithStarlightSuncatcher(in:"living"); _=store.interactWithMoonbeamTerrarium(in:"living"); _=store.interactWithCelestialLantern(in:"living"); let c=store.coins,s=store.stars; XCTAssertTrue(store.claimRadiantRoomEvent()); XCTAssertEqual(store.coins,c+90); XCTAssertEqual(store.stars,s+3); XCTAssertEqual(store.interactionCounts["trophy.radiantEvent.achievement"],1); XCTAssertFalse(store.claimRadiantRoomEvent()) }
    func testRadiantRoomEventResetsOnNewDayAndPersistsClaims() { let (store,defaults)=makeStore(); unlockRadiantEventSet(store); _=store.interactWithStarlightSuncatcher(in:"living"); _=store.interactWithMoonbeamTerrarium(in:"living"); _=store.interactWithCelestialLantern(in:"living"); XCTAssertTrue(store.claimRadiantRoomEvent()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isRadiantRoomEventClaimedToday); reloaded.dailyLifeProgress.day += 1; XCTAssertEqual(reloaded.radiantRoomEventStep,0); XCTAssertFalse(reloaded.isRadiantRoomEventClaimedToday) }
}


extension GameStoreTests {
    func testRadiantEventSequenceStartsFromStarlightRegression() { let (store,_)=makeStore(); store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; store.interactionCounts["trophy.celestialLantern.unlocked"]=1; XCTAssertTrue(store.interactWithStarlightSuncatcher(in:"living")); XCTAssertEqual(store.radiantRoomEventStep,1) }
    func testRadiantMasteryTiersAdvance() { let (store,_)=makeStore(); XCTAssertEqual(store.radiantRoomEventMasteryTier,"First Glow"); store.interactionCounts["trophy.radiantEvent.achievement"]=2; XCTAssertEqual(store.radiantRoomEventMasteryTier,"Room Illuminator"); store.interactionCounts["trophy.radiantEvent.achievement"]=5; XCTAssertEqual(store.radiantRoomEventMasteryTier,"Radiant Host") }
    func testRadiantChimeRequiresFiveEventsAndPersists() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.radiantEvent.achievement"]=4; XCTAssertFalse(store.claimRadiantChimeReward()); store.interactionCounts["trophy.radiantEvent.achievement"]=5; XCTAssertTrue(store.claimRadiantChimeReward()); XCTAssertFalse(store.claimRadiantChimeReward()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isRadiantChimeUnlocked) }
    func testRadiantChimeInteractionRequiresLivingRoom() { let (store,_)=makeStore(); store.interactionCounts["trophy.radiantChime.unlocked"]=1; XCTAssertFalse(store.interactWithRadiantChime(in:"kitchen")); XCTAssertTrue(store.interactWithRadiantChime(in:"living")) }
}

extension GameStoreTests {
    private func unlockV229RadiantSet(_ store:GameStore) { store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; store.interactionCounts["trophy.celestialLantern.unlocked"]=1; store.interactionCounts["trophy.radiantChime.unlocked"]=1 }
    func testRadiantChimeActsAsOptionalFourthEventStep() { let (store,_)=makeStore(); unlockV229RadiantSet(store); _=store.interactWithStarlightSuncatcher(in:"living"); _=store.interactWithMoonbeamTerrarium(in:"living"); _=store.interactWithCelestialLantern(in:"living"); XCTAssertEqual(store.radiantRoomEventStep,3); XCTAssertTrue(store.isRadiantRoomEventReady); _=store.interactWithRadiantChime(in:"living"); XCTAssertEqual(store.radiantRoomEventStep,4); XCTAssertTrue(store.isRadiantChimeBonusReady); XCTAssertEqual(store.radiantRoomAtmosphere,"Chime Cascade") }
    func testRadiantChimeBonusEnhancesEventReward() { let (store,_)=makeStore(); unlockV229RadiantSet(store); _=store.interactWithStarlightSuncatcher(in:"living"); _=store.interactWithMoonbeamTerrarium(in:"living"); _=store.interactWithCelestialLantern(in:"living"); _=store.interactWithRadiantChime(in:"living"); let c=store.coins,s=store.stars; XCTAssertTrue(store.claimRadiantRoomEvent()); XCTAssertEqual(store.coins,c+120); XCTAssertEqual(store.stars,s+4) }
    func testLightkeeperRewardRequiresTenEventsAndPersists() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.radiantEvent.achievement"]=9; XCTAssertFalse(store.claimLightkeeperReward()); store.interactionCounts["trophy.radiantEvent.achievement"]=10; XCTAssertTrue(store.claimLightkeeperReward()); XCTAssertFalse(store.claimLightkeeperReward()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isLumenCanopyUnlocked) }
    func testLumenCanopyInteractionRequiresLivingRoom() { let (store,_)=makeStore(); store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; XCTAssertFalse(store.interactWithLumenCanopy(in:"garden")); XCTAssertTrue(store.interactWithLumenCanopy(in:"living")); XCTAssertEqual(store.interactionCounts["trophy.lumenCanopy.visits"],1) }
}


extension GameStoreTests {
    func testV230ChimeBonusRegressionPaysEnhancedReward() { let (store,_)=makeStore(); store.interactionCounts["trophy.starlightSuncatcher.unlocked"]=1; store.interactionCounts["trophy.moonbeamTerrarium.unlocked"]=1; store.interactionCounts["trophy.celestialLantern.unlocked"]=1; store.interactionCounts["trophy.radiantChime.unlocked"]=1; _=store.interactWithStarlightSuncatcher(in:"living"); _=store.interactWithMoonbeamTerrarium(in:"living"); _=store.interactWithCelestialLantern(in:"living"); _=store.interactWithRadiantChime(in:"living"); let c=store.coins,s=store.stars; XCTAssertTrue(store.claimRadiantRoomEvent()); XCTAssertEqual(store.coins,c+120); XCTAssertEqual(store.stars,s+4) }
    func testLightkeeperMomentRequiresChimeBeforeCanopy() { let (store,_)=makeStore(); store.interactionCounts["trophy.radiantChime.unlocked"]=1; store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; _=store.interactWithLumenCanopy(in:"living"); XCTAssertEqual(store.weeklyLightkeeperProgress,0); _=store.interactWithRadiantChime(in:"living"); _=store.interactWithLumenCanopy(in:"living"); XCTAssertEqual(store.weeklyLightkeeperProgress,1) }
    func testWeeklyLightkeeperRewardRequiresThreeDistinctDaysAndPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.radiantChime.unlocked"]=1; store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; for day in 1...3 { store.dailyLifeProgress.day=day; _=store.interactWithRadiantChime(in:"living"); _=store.interactWithLumenCanopy(in:"living") }; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimWeeklyLightkeeperReward()); XCTAssertEqual(store.coins,c+180); XCTAssertEqual(store.stars,s+6); XCTAssertFalse(store.claimWeeklyLightkeeperReward()) }
    func testWeeklyLightkeeperClaimPersistsAcrossReload() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.radiantChime.unlocked"]=1; store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; for day in 1...3 { store.dailyLifeProgress.day=day; _=store.interactWithRadiantChime(in:"living"); _=store.interactWithLumenCanopy(in:"living") }; XCTAssertTrue(store.claimWeeklyLightkeeperReward()); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isWeeklyLightkeeperRewardClaimed); XCTAssertFalse(reloaded.claimWeeklyLightkeeperReward()) }
}


extension GameStoreTests {
    func testV231LightkeeperStreakRequiresCurrentWeekClaim() { let (store,_)=makeStore(); store.interactionCounts["trophy.lightkeeperWeekly.week0"]=1; store.dailyLifeProgress.day=8; XCTAssertEqual(store.lightkeeperWeeklyStreak,0); store.interactionCounts["trophy.lightkeeperWeekly.week1"]=1; XCTAssertEqual(store.lightkeeperWeeklyStreak,2) }
    func testV231LightkeeperStreakBreakResetsConsecutiveCount() { let (store,_)=makeStore(); store.interactionCounts["trophy.lightkeeperWeekly.week0"]=1; store.interactionCounts["trophy.lightkeeperWeekly.week2"]=1; store.dailyLifeProgress.day=15; XCTAssertEqual(store.lightkeeperWeeklyStreak,1) }
    func testV231TwoWeekStreakRewardPaysOnce() { let (store,_)=makeStore(); store.interactionCounts["trophy.lightkeeperWeekly.week0"]=1; store.interactionCounts["trophy.lightkeeperWeekly.week1"]=1; store.dailyLifeProgress.day=8; let c=store.coins,s=store.stars; XCTAssertTrue(store.claimLightkeeperStreak2Reward()); XCTAssertEqual(store.coins,c+125); XCTAssertEqual(store.stars,s+4); XCTAssertFalse(store.claimLightkeeperStreak2Reward()) }
    func testV231FourWeekStreakUnlocksCrownAndPersists() { let (store,defaults)=makeStore(); for week in 0...3 { store.interactionCounts["trophy.lightkeeperWeekly.week\(week)"]=1 }; store.dailyLifeProgress.day=22; XCTAssertTrue(store.claimLightkeeperStreak4Reward()); XCTAssertTrue(store.hasLightkeeperStreakCrown); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.hasLightkeeperStreakCrown); XCTAssertTrue(reloaded.isLightkeeperStreak4Claimed) }
}


extension GameStoreTests {
    func testV232CrownBecomesWearableOnlyAfterUnlock() { let (store,_)=makeStore(); XCTAssertFalse(store.accessories.contains{$0.id=="starlightCrown"}); store.interactionCounts["trophy.lightkeeperStreak.crown"]=1; XCTAssertTrue(store.accessories.contains{$0.id=="starlightCrown"}); store.updateCharacter(accessoryID:"starlightCrown"); XCTAssertTrue(store.isStarlightCrownEquipped) }
    func testV232CrownCanopyMomentRequiresEquippedCrownAndPaysOnceDaily() { let (store,_)=makeStore(); store.interactionCounts["trophy.lightkeeperStreak.crown"]=1; store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; _=store.interactWithLumenCanopy(in:"living"); XCTAssertEqual(store.crownCanopyAchievementCount,0); store.updateCharacter(accessoryID:"starlightCrown"); let c=store.coins,s=store.stars; _=store.interactWithLumenCanopy(in:"living"); XCTAssertEqual(store.coins,c+35); XCTAssertEqual(store.stars,s+1); XCTAssertEqual(store.crownCanopyAchievementCount,1); _=store.interactWithLumenCanopy(in:"living"); XCTAssertEqual(store.crownCanopyAchievementCount,1) }
    func testV232CrownCanopyMomentResetsNextDayAndPersists() { let (store,defaults)=makeStore(); store.interactionCounts["trophy.lightkeeperStreak.crown"]=1; store.interactionCounts["trophy.lumenCanopy.unlocked"]=1; store.updateCharacter(accessoryID:"starlightCrown"); _=store.interactWithLumenCanopy(in:"living"); let reloaded=GameStore(defaults:defaults,saveKey:"save"); XCTAssertTrue(reloaded.isStarlightCrownEquipped); XCTAssertTrue(reloaded.isCrownCanopyMomentClaimedToday); reloaded.dailyLifeProgress.day += 1; XCTAssertFalse(reloaded.isCrownCanopyMomentClaimedToday); _=reloaded.interactWithLumenCanopy(in:"living"); XCTAssertEqual(reloaded.crownCanopyAchievementCount,2) }
    func testV232CrownCanopyCollectionTiersAdvance() { let (store,_)=makeStore(); XCTAssertEqual(store.crownCanopyCollectionTitle,"Waiting for Starlight"); store.interactionCounts["trophy.crownCanopy.achievement"]=3; XCTAssertEqual(store.crownCanopyCollectionTitle,"Canopy Keeper"); store.interactionCounts["trophy.crownCanopy.achievement"]=7; XCTAssertEqual(store.crownCanopyCollectionTitle,"Starlight Guardian") }
}


// v2.33: new Crown Spark progression and persistence regression coverage.
extension GameStoreTests {
    func testV233WeeklyCrownSparkRequiresThreeDistinctDaysAndPaysOnce() {
        let (store,_) = makeStore()
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.interactionCounts["trophy.lumenCanopy.unlocked"]=1
        store.updateCharacter(accessoryID:"starlightCrown")
        _=store.interactWithLumenCanopy(in:"living")
        _=store.interactWithLumenCanopy(in:"living")
        XCTAssertEqual(store.weeklyCrownSparkProgress,1)
        XCTAssertFalse(store.claimWeeklyCrownSparkReward())
        for day in 2...3 { store.dailyLifeProgress.day=day; _=store.interactWithLumenCanopy(in:"living") }
        XCTAssertEqual(store.weeklyCrownSparkProgress,3)
        let coins=store.coins, stars=store.stars
        XCTAssertTrue(store.claimWeeklyCrownSparkReward())
        XCTAssertEqual(store.coins,coins+150)
        XCTAssertEqual(store.stars,stars+5)
        XCTAssertFalse(store.claimWeeklyCrownSparkReward())
    }
    func testV233WeeklyCrownSparkExcludesLockedAndWrongRoomInteractions() {
        let (store,_) = makeStore()
        store.interactionCounts["trophy.lumenCanopy.unlocked"]=1
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyCrownSparkProgress,0)
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.updateCharacter(accessoryID:"starlightCrown")
        XCTAssertFalse(store.interactWithLumenCanopy(in:"bedroom"))
        XCTAssertEqual(store.weeklyCrownSparkProgress,0)
    }
    func testV233WeeklyCrownSparkWeekBoundaryAndReload() {
        let (store,defaults) = makeStore()
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.interactionCounts["trophy.lumenCanopy.unlocked"]=1
        store.updateCharacter(accessoryID:"starlightCrown")
        for day in 5...7 { store.dailyLifeProgress.day=day; _=store.interactWithLumenCanopy(in:"living") }
        XCTAssertTrue(store.claimWeeklyCrownSparkReward())
        store.dailyLifeProgress.day=8
        _=store.interactWithLumenCanopy(in:"living")
        XCTAssertEqual(store.weeklyCrownSparkProgress,1)
        XCTAssertFalse(store.isWeeklyCrownSparkClaimed)
        let reloaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertEqual(reloaded.dailyLifeProgress.day,8)
        XCTAssertEqual(reloaded.weeklyCrownSparkProgress,1)
        XCTAssertFalse(reloaded.isWeeklyCrownSparkClaimed)
        for day in 9...10 { reloaded.dailyLifeProgress.day=day; _=reloaded.interactWithLumenCanopy(in:"living") }
        XCTAssertTrue(reloaded.claimWeeklyCrownSparkReward())
        XCTAssertFalse(reloaded.claimWeeklyCrownSparkReward())
    }
    func testV233CometVeilRequiresSevenMomentsAndClaimsOnlyOnce() {
        let (store,_) = makeStore()
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.interactionCounts["trophy.crownCanopy.achievement"]=6
        XCTAssertFalse(store.claimCometVeilReward())
        XCTAssertFalse(store.accessories.contains{$0.id=="cometVeil"})
        store.interactionCounts["trophy.crownCanopy.achievement"]=7
        let coins=store.coins,stars=store.stars
        XCTAssertTrue(store.claimCometVeilReward())
        XCTAssertEqual(store.coins,coins+160)
        XCTAssertEqual(store.stars,stars+5)
        XCTAssertFalse(store.claimCometVeilReward())
        XCTAssertTrue(store.accessories.contains{$0.id=="cometVeil"})
    }
    func testV233CometVeilWearAndPersistence() {
        let (store,defaults) = makeStore()
        store.updateCharacter(accessoryID:"cometVeil")
        XCTAssertFalse(store.isCometVeilEquipped)
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.interactionCounts["trophy.crownCanopy.achievement"]=7
        XCTAssertTrue(store.claimCometVeilReward())
        store.updateCharacter(accessoryID:"cometVeil")
        XCTAssertTrue(store.isCometVeilEquipped)
        let reloaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertTrue(reloaded.isCometVeilUnlocked)
        XCTAssertTrue(reloaded.isCometVeilEquipped)
        XCTAssertFalse(reloaded.claimCometVeilReward())
    }
    func testV233CrownSparkClaimRemainsClaimedAfterReload() {
        let (store,defaults)=makeStore()
        store.interactionCounts["trophy.lightkeeperStreak.crown"]=1
        store.interactionCounts["trophy.lumenCanopy.unlocked"]=1
        store.updateCharacter(accessoryID:"starlightCrown")
        for day in 1...3 { store.dailyLifeProgress.day=day; _=store.interactWithLumenCanopy(in:"living") }
        XCTAssertTrue(store.claimWeeklyCrownSparkReward())
        let reloaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertTrue(reloaded.isWeeklyCrownSparkClaimed)
        XCTAssertFalse(reloaded.claimWeeklyCrownSparkReward())
    }
}

// v2.34: collectible weekly Crown Spark milestones, earned room props, and
// the formerly missing Radiant Chime -> Lumen Canopy interaction chain.
extension GameStoreTests {
    func testV234CrownSparkCollectionCountsClaimedWeeksOnly() {
        let (store,_) = makeStore()
        store.dailyLifeProgress.day = 22 // current week index 3
        store.interactionCounts["trophy.crownCanopy.day22"] = 1
        store.interactionCounts["trophy.crownSparkWeekly.week0"] = 1
        store.interactionCounts["trophy.crownSparkWeekly.week1"] = 1
        store.interactionCounts["trophy.crownSparkWeekly.week2"] = 0
        store.interactionCounts["trophy.crownSparkWeekly.week4"] = 1 // future claim is ignored
        store.interactionCounts["trophy.crownSparkWeekly.weekgarbage"] = 1
        XCTAssertEqual(store.crownSparkWeeksCollected,2)
        XCTAssertEqual(store.crownSparkWeeklyCollectionTier,"Shimmer Keeper")
        XCTAssertFalse(store.claimCometHaloReward())
        store.interactionCounts["trophy.crownSparkWeekly.week3"] = 1
        XCTAssertEqual(store.crownSparkWeeksCollected,3)
        XCTAssertEqual(store.crownSparkWeeklyCollectionTier,"Comet Collector")
    }
    func testV234CometHaloRewardIsOneTimeAndPersists() {
        let (store,defaults) = makeStore()
        store.dailyLifeProgress.day = 15
        for week in 0...2 { store.interactionCounts["trophy.crownSparkWeekly.week\(week)"] = 1 }
        let coins=store.coins, stars=store.stars
        XCTAssertTrue(store.claimCometHaloReward())
        XCTAssertEqual(store.coins,coins+110)
        XCTAssertEqual(store.stars,stars+4)
        XCTAssertFalse(store.claimCometHaloReward())
        let loaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertTrue(loaded.isCometHaloUnlocked)
        XCTAssertEqual(loaded.crownSparkWeeksCollected,3)
        XCTAssertFalse(loaded.claimCometHaloReward())
    }
    func testV234CometHaloOnlyWorksInLivingRoomAndPersistsVisits() {
        let (store,defaults) = makeStore()
        XCTAssertFalse(store.interactWithCometHalo(in:"living"))
        store.dailyLifeProgress.day = 15
        for week in 0...2 { store.interactionCounts["trophy.crownSparkWeekly.week\(week)"] = 1 }
        XCTAssertTrue(store.claimCometHaloReward())
        XCTAssertFalse(store.interactWithCometHalo(in:"garden"))
        let fun=store.characterNeeds.fun, energy=store.characterNeeds.energy
        XCTAssertTrue(store.interactWithCometHalo(in:"living"))
        XCTAssertEqual(store.characterNeeds.fun,min(100,fun+2))
        XCTAssertEqual(store.characterNeeds.energy,min(100,energy+2))
        let loaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertEqual(loaded.interactionCounts["trophy.crownSparkWeekly.cometHalo.visits"],1)
    }
    func testV234ChimeThenCanopyUnlocksRealLightkeeperProgress() {
        let (store,_) = makeStore()
        store.interactionCounts["trophy.radiantChime.unlocked"] = 1
        store.interactionCounts["trophy.lumenCanopy.unlocked"] = 1
        XCTAssertFalse(store.interactWithRadiantChime(in:"bedroom"))
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyLightkeeperProgress,0)
        XCTAssertTrue(store.interactWithRadiantChime(in:"living"))
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyLightkeeperProgress,1)
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyLightkeeperProgress,1)
    }
    func testV234CollectionTierSixAndWeekTransition() {
        let (store,defaults) = makeStore()
        store.dailyLifeProgress.day = 43 // week 6
        for week in 0...5 { store.interactionCounts["trophy.crownSparkWeekly.week\(week)"] = 1 }
        XCTAssertEqual(store.crownSparkWeeklyCollectionTier,"Skyward Legend")
        store.reward(coins:0,stars:0)
        let loaded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertEqual(loaded.crownSparkWeeksCollected,6)
        loaded.dailyLifeProgress.day = 50 // next week, prior claims retained
        XCTAssertEqual(loaded.crownSparkWeeksCollected,6)
        XCTAssertFalse(loaded.isWeeklyCrownSparkClaimed)
    }
    func testV234CometVeilDoesNotAccidentallyTriggerCrownSpark() {
        let (store,_) = makeStore()
        store.interactionCounts["trophy.lightkeeperStreak.crown"] = 1
        store.interactionCounts["trophy.lumenCanopy.unlocked"] = 1
        store.interactionCounts["trophy.crownCanopy.achievement"] = 7
        XCTAssertTrue(store.claimCometVeilReward())
        store.updateCharacter(accessoryID:"cometVeil")
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyCrownSparkProgress,0)
        store.updateCharacter(accessoryID:"starlightCrown")
        XCTAssertTrue(store.interactWithLumenCanopy(in:"living"))
        XCTAssertEqual(store.weeklyCrownSparkProgress,1)
    }
}

// v2.35: protect newer-version player saves from destructive downgrade writes.
extension GameStoreTests {
    func testV235FuturePrimaryAndCompatibleBackupStayByteIdentical() {
        let (store, defaults) = makeStore()
        store.reward(coins:40)
        store.reward(coins:10)
        let backupBefore = defaults.data(forKey:"save.backup")
        guard let original = defaults.data(forKey:"save"),
              var json = (try? JSONSerialization.jsonObject(with:original)) as? [String:Any]
        else { return XCTFail("save JSON missing") }
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        json["futureOnlyCollection"] = ["uniqueItem":"keep-me"]
        let future = try! JSONSerialization.data(withJSONObject:json,options:[.sortedKeys])
        defaults.set(future,forKey:"save")
        let downgraded = GameStore(defaults:defaults,saveKey:"save")
        XCTAssertTrue(downgraded.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(downgraded.coins,540) // backup is a read-only preview
        XCTAssertEqual(defaults.data(forKey:"save"),future)
        downgraded.reward(coins:100)
        XCTAssertEqual(downgraded.coins,640) // session-only play is allowed
        XCTAssertEqual(defaults.data(forKey:"save"),future)
        XCTAssertEqual(defaults.data(forKey:"save.backup"),backupBefore)
    }
    func testV235FuturePrimaryWithoutBackupRemainsUntouched() {
        let (store,defaults) = makeStore()
        store.reward(coins:1)
        guard let original=defaults.data(forKey:"save"),
              var json=(try? JSONSerialization.jsonObject(with:original)) as? [String:Any]
        else { return XCTFail("save JSON missing") }
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 10
        let future = try! JSONSerialization.data(withJSONObject:json)
        defaults.set(future,forKey:"save")
        defaults.removeObject(forKey:"save.backup")
        let downgraded=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertTrue(downgraded.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(downgraded.coins,500) // safe in-memory defaults
        downgraded.reward(coins:25)
        XCTAssertEqual(defaults.data(forKey:"save"),future)
        XCTAssertNil(defaults.data(forKey:"save.backup"))
    }
    func testV235CorruptPrimaryStillRestoresBackupAndCanSave() {
        let (store,defaults) = makeStore()
        store.reward(coins:40)
        store.reward(coins:10)
        defaults.set(Data("invalid-json".utf8),forKey:"save")
        let recovered=GameStore(defaults:defaults,saveKey:"save")
        XCTAssertFalse(recovered.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(recovered.coins,540)
        recovered.reward(coins:5)
        XCTAssertEqual(GameStore(defaults:defaults,saveKey:"save").coins,545)
    }
}

// v2.36: protect a future-version backup even if an older primary is writable.
extension GameStoreTests {
    func testV236CompatiblePrimaryDoesNotRotateOverNewerBackup() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 25)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        var futureJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: primary) as? [String: Any])
        futureJSON["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        futureJSON["futureFurniture"] = ["rare": "do-not-delete"]
        let futureBackup = try JSONSerialization.data(withJSONObject: futureJSON)
        defaults.set(futureBackup, forKey: "save.backup")
        let loaded = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(loaded.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(loaded.coins, 525)
        loaded.reward(coins: 10)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 535)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), futureBackup)
    }

    func testV236CorruptPrimaryAndFutureBackupAreBothPreserved() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 5)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "save"))) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 2
        let futureBackup = try JSONSerialization.data(withJSONObject: json)
        let corrupt = Data("corrupt-primary".utf8)
        defaults.set(corrupt, forKey: "save")
        defaults.set(futureBackup, forKey: "save.backup")
        let loaded = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(loaded.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(loaded.coins, 500)
        loaded.reward(coins: 100)
        loaded.resetProgress()
        XCTAssertEqual(defaults.data(forKey: "save"), corrupt)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), futureBackup)
    }

    func testV236MissingPrimaryAndFutureBackupCannotBeOverwritten() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 5)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "save"))) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 4
        let futureBackup = try JSONSerialization.data(withJSONObject: json)
        defaults.removeObject(forKey: "save")
        defaults.set(futureBackup, forKey: "save.backup")
        let loaded = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(loaded.isSaveReadOnlyDueToNewerVersion)
        loaded.completeOnboarding()
        XCTAssertNil(defaults.data(forKey: "save"))
        XCTAssertEqual(defaults.data(forKey: "save.backup"), futureBackup)
    }

    func testV236NormalBackupRotationStillWorks() {
        let (store, defaults) = makeStore()
        store.reward(coins: 20)
        let prior = defaults.data(forKey: "save")
        store.reward(coins: 10)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), prior)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 530)
    }
}

// v2.37: unknown schema markers are protected, even when JSONDecoder would
// otherwise treat them as a missing optional field or an integer-like value.
extension GameStoreTests {
    private func withSchema(_ data: Data, marker: Any?) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if let marker { json["schemaVersion"] = marker }
        else { json.removeValue(forKey: "schemaVersion") }
        let encoded = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        if let text = marker as? String, text == "__fractional__" {
            return Data(String(decoding: encoded, as: UTF8.self)
                .replacingOccurrences(of: "\"__fractional__\"", with: "4.0").utf8)
        }
        return encoded
    }

    func testV237MalformedPrimarySchemaPreservesBothSaves() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 25)
        let compatibleBackup = try XCTUnwrap(defaults.data(forKey: "save"))
        let malformed = try withSchema(compatibleBackup, marker: "future")
        defaults.set(malformed, forKey: "save")
        defaults.set(compatibleBackup, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(restored.coins, 525) // preview of compatible backup
        restored.reward(coins: 40)
        XCTAssertEqual(defaults.data(forKey: "save"), malformed)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), compatibleBackup)
    }

    func testV237NullBooleanAndFractionalSchemaMarkersCannotOverwrite() throws {
        for (index, marker) in [NSNull(), NSNumber(value: true), "__fractional__", NSNumber(value: 0)] .enumerated() {
            let (store, defaults) = makeStore("malformed.\(index)")
            store.reward(coins: 5)
            let raw = try withSchema(XCTUnwrap(defaults.data(forKey: "save")), marker: marker)
            defaults.set(raw, forKey: "save")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            XCTAssertTrue(restored.isSaveReadOnlyDueToNewerVersion, "invalid schema case \(index)")
            restored.resetProgress()
            XCTAssertEqual(defaults.data(forKey: "save"), raw)
        }
    }

    func testV237UnknownBackupSchemaSurvivesCompatiblePrimaryWrites() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        let unknownBackup = try withSchema(primary, marker: "unrecognized-v5")
        defaults.set(unknownBackup, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToNewerVersion)
        restored.reward(coins: 20)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 530)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), unknownBackup)
    }

    func testV237UnknownBackupOnlyPreventsEmptyOverwrite() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 15)
        let unknownBackup = try withSchema(XCTUnwrap(defaults.data(forKey: "save")), marker: NSNull())
        defaults.removeObject(forKey: "save")
        defaults.set(unknownBackup, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToNewerVersion)
        restored.completeOnboarding()
        XCTAssertNil(defaults.data(forKey: "save"))
        XCTAssertEqual(defaults.data(forKey: "save.backup"), unknownBackup)
    }

    func testV237ExternalFutureSaveReplacementBlocksNextWrite() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 30)
        let future = try withSchema(XCTUnwrap(defaults.data(forKey: "save")), marker: GameStore.currentSaveSchemaVersion + 1)
        defaults.set(future, forKey: "save")
        let backupBefore = defaults.data(forKey: "save.backup")
        store.reward(coins: 10)
        XCTAssertTrue(store.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(defaults.data(forKey: "save"), future)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backupBefore)
    }

    func testV237MissingSchemaStillMigratesLegacySave() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 45)
        let legacy = try withSchema(XCTUnwrap(defaults.data(forKey: "save")), marker: nil)
        defaults.set(legacy, forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(restored.coins, 545)
        restored.reward(coins: 5)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 550)
    }
}

// v2.38: simulate interruptions at each stage of the UserDefaults save commit.
extension GameStoreTests {
    func testV238PendingOnlyCompletesInterruptedFirstWrite() {
        let (store, defaults) = makeStore()
        store.reward(coins: 33)
        let staged = defaults.data(forKey: "save")!
        defaults.removeObject(forKey: "save")
        defaults.set(staged, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 533)
        XCTAssertNotNil(defaults.data(forKey: "save"))
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }

    func testV238PendingBeforeBackupRotationPreservesPriorPrimary() {
        let (store, defaults) = makeStore()
        store.reward(coins: 20)
        let oldPrimary = defaults.data(forKey: "save")!
        store.reward(coins: 35)
        let newPrimary = defaults.data(forKey: "save")!
        defaults.set(oldPrimary, forKey: "save")
        defaults.removeObject(forKey: "save.backup")
        defaults.set(newPrimary, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 555)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), oldPrimary)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }

    func testV238PendingAfterBackupRotationCompletesCommit() {
        let (store, defaults) = makeStore()
        store.reward(coins: 12)
        let oldPrimary = defaults.data(forKey: "save")!
        store.reward(coins: 14)
        let newPrimary = defaults.data(forKey: "save")!
        defaults.set(oldPrimary, forKey: "save")
        defaults.set(oldPrimary, forKey: "save.backup")
        defaults.set(newPrimary, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 526)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), oldPrimary)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 526)
    }

    func testV238AlreadyCommittedPendingIsRemovedWithoutRollback() {
        let (store, defaults) = makeStore()
        store.reward(coins: 41)
        let committed = defaults.data(forKey: "save")!
        defaults.set(committed, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 541)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 541)
    }

    func testV238CorruptPrimaryCannotReplaceGoodBackup() {
        let (store, defaults) = makeStore()
        store.reward(coins: 25)
        let goodBackup = defaults.data(forKey: "save")!
        store.reward(coins: 9)
        defaults.set(Data("truncated-json".utf8), forKey: "save")
        defaults.set(goodBackup, forKey: "save.backup")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 525)
        recovered.reward(coins: 10)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), goodBackup)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 535)
    }

    func testV238ProtectedPendingCannotOverwriteCompatiblePrimary() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 50)
        let original = try XCTUnwrap(defaults.data(forKey: "save"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        let future = try JSONSerialization.data(withJSONObject: json)
        defaults.set(future, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToNewerVersion)
        XCTAssertEqual(restored.coins, 550)
        restored.reward(coins: 15)
        XCTAssertEqual(defaults.data(forKey: "save"), original)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), future)
    }

    func testV238MalformedPendingCannotRollbackHealthyPrimary() {
        let (store, defaults) = makeStore()
        store.reward(coins: 19)
        defaults.set(Data("{\"coins\":".utf8), forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 519)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 519)
    }

    func testV238PendingRecoveryPreservesFutureBackup() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 20)
        let oldPrimary = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 30)
        let newPrimary = try XCTUnwrap(defaults.data(forKey: "save"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: newPrimary) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 2
        let futureBackup = try JSONSerialization.data(withJSONObject: json)
        defaults.set(oldPrimary, forKey: "save")
        defaults.set(futureBackup, forKey: "save.backup")
        defaults.set(newPrimary, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 550)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), futureBackup)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
}

// v2.39: journal sequence ordering protects against stale or ambiguous pending saves.
extension GameStoreTests {
    private func v239Sequence(_ data: Data) throws -> Int {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["commitSequence"] as? Int)
    }
    private func v239Edit(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV239StalePendingDoesNotRollbackCommittedPrimary() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 20)
        let old = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 35)
        let newest = try XCTUnwrap(defaults.data(forKey: "save"))
        XCTAssertGreaterThan(try v239Sequence(newest), try v239Sequence(old))
        defaults.set(old, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 555)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 555)
    }
    func testV239EqualSequenceConflictKeepsPrimary() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 50)
        let committed = try XCTUnwrap(defaults.data(forKey: "save"))
        let conflicting = try v239Edit(committed) { $0["coins"] = 3 }
        defaults.set(conflicting, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 550)
        // v2.50 supersedes v2.39's journal-discard behavior.
        XCTAssertTrue(recovered.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), conflicting)
    }
    func testV239HigherSequencePendingReplaysInterruptedCommit() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 12)
        let prior = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 30)
        let newer = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(prior, forKey: "save")
        defaults.removeObject(forKey: "save.backup")
        defaults.set(newer, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 542)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), prior)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV239LegacyPendingWithoutSequenceStillReplays() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let saved = try XCTUnwrap(defaults.data(forKey: "save"))
        let old = try v239Edit(saved) { $0.removeValue(forKey: "commitSequence") }
        let pending = try v239Edit(old) { $0["coins"] = 600 }
        defaults.set(old, forKey: "save")
        defaults.set(pending, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 600)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertGreaterThan(try v239Sequence(XCTUnwrap(defaults.data(forKey: "save"))), 0)
    }
    func testV239InvalidNegativeSequenceCannotOverridePrimary() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 25)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v239Edit(primary) { $0["commitSequence"] = -3 }, forKey: "save.pending")
        let recovered = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(recovered.coins, 525)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV239SequenceMonotonicAcrossReloadAndGameplay() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let before = try v239Sequence(XCTUnwrap(defaults.data(forKey: "save")))
        let restored = GameStore(defaults: defaults, saveKey: "save")
        let afterReload = try v239Sequence(XCTUnwrap(defaults.data(forKey: "save")))
        restored.reward(coins: 15)
        let afterReward = try v239Sequence(XCTUnwrap(defaults.data(forKey: "save")))
        XCTAssertGreaterThan(afterReload, before)
        XCTAssertGreaterThan(afterReward, afterReload)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 525)
    }
}

extension GameStoreTests {
    func testV239NewerBackupWinsAgainstStalePendingAndCorruptPrimary() {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let stale = defaults.data(forKey: "save")!
        store.reward(coins: 30)
        let latest = defaults.data(forKey: "save")!
        defaults.set(Data("corrupt".utf8), forKey: "save")
        defaults.set(latest, forKey: "save.backup")
        defaults.set(stale, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 540)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), latest)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 540)
    }
}

// v2.40: interrupted rotation and concurrent writers must not roll back progress.
extension GameStoreTests {
    private func v240Edit(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    func testV240NewerBackupWinsWithoutPendingJournal() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let old = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 30)
        let newest = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(old, forKey: "save")
        defaults.set(newest, forKey: "save.backup")
        defaults.removeObject(forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 540)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), newest)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 540)
    }

    func testV240NewerBackupSurvivesMalformedPending() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 20)
        let old = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 40)
        let newest = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(old, forKey: "save")
        defaults.set(newest, forKey: "save.backup")
        defaults.set(Data("{broken".utf8), forKey: "save.pending")
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 560)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        XCTAssertEqual(defaults.data(forKey: "save.backup"), newest)
    }

    func testV240NewerPendingDoesNotDestroyIntermediateBackup() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let old = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 20)
        let middle = try XCTUnwrap(defaults.data(forKey: "save"))
        store.reward(coins: 30)
        let newest = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(old, forKey: "save")
        defaults.set(middle, forKey: "save.backup")
        defaults.set(newest, forKey: "save.pending")
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 560)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), middle)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }

    func testV240StaleStoreCannotOverwriteNewerCompatibleSave() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let second = GameStore(defaults: defaults, saveKey: "save")
        second.reward(coins: 25)
        let latest = try XCTUnwrap(defaults.data(forKey: "save"))
        first.reward(coins: 80)
        XCTAssertTrue(first.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), latest)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 535)
    }

    func testV240SameSequenceExternalEditIsProtected() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let original = try XCTUnwrap(defaults.data(forKey: "save"))
        let modified = try v240Edit(original) { $0["coins"] = 770 }
        defaults.set(modified, forKey: "save")
        store.reward(coins: 15)
        XCTAssertTrue(store.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), modified)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 770)
    }

    func testV240ExternalPendingCommitIsProtected() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let committed = try XCTUnwrap(defaults.data(forKey: "save"))
        let staged = try v240Edit(committed) {
            $0["coins"] = 710
            $0["commitSequence"] = (($0["commitSequence"] as? Int) ?? 0) + 1
        }
        defaults.set(staged, forKey: "save.pending")
        store.reward(coins: 60)
        XCTAssertTrue(store.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), committed)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), staged)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 710)
    }
}

// v2.41: enforce task prerequisites and reward amounts in the model itself.
extension GameStoreTests {
    func testV241LockedAndUnknownAdventuresCannotClaim() {
        let (store, _) = makeStore()
        for task in ["outfit", "decorate", "cupcake", "dance", "unknown"] {
            XCTAssertFalse(store.claimAdventureTask(task))
        }
        XCTAssertEqual(store.coins, 500)
        XCTAssertEqual(store.stars, 0)
        XCTAssertTrue(store.completedTasks.isEmpty)
    }
    func testV241DanceRequiresThreeInteractionsAndCannotDoubleClaim() {
        let (store, _) = makeStore()
        for _ in 0..<2 { XCTAssertTrue(store.performInteraction("dance", in: "living")) }
        XCTAssertFalse(store.claimAdventureTask("dance"))
        XCTAssertTrue(store.performInteraction("dance", in: "living"))
        XCTAssertTrue(store.claimAdventureTask("dance"))
        XCTAssertFalse(store.claimAdventureTask("dance"))
        XCTAssertEqual(store.coins, 620)
        XCTAssertEqual(store.stars, 1)
    }
    func testV241OutfitRewardUsesFixedAmount() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.selectOutfit(store.outfits.first { $0.id == "party" }!))
        XCTAssertTrue(store.claimAdventureTask("outfit"))
        XCTAssertEqual(store.coins, 480)
    }
    func testV241DecorationRewardRequiresPlacedItem() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.selectRoomItem(store.roomItems.first { $0.id == "lamp" }!))
        XCTAssertTrue(store.claimAdventureTask("decorate"))
        XCTAssertEqual(store.coins, 460)
    }
    func testV241CupcakeRewardRequiresActualRecipe() {
        let (store, _) = makeStore()
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
        XCTAssertTrue(store.claimAdventureTask("cupcake"))
        XCTAssertFalse(store.claimAdventureTask("cupcake"))
        XCTAssertEqual(store.coins, 675)
        XCTAssertEqual(store.stars, 2)
    }
    func testV241ClaimedAdventureSurvivesReload() {
        let (store, defaults) = makeStore()
        for _ in 0..<3 { XCTAssertTrue(store.performInteraction("dance", in: "living")) }
        XCTAssertTrue(store.claimAdventureTask("dance"))
        let reloaded = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(reloaded.completedTasks.contains("dance"))
        XCTAssertFalse(reloaded.claimAdventureTask("dance"))
        XCTAssertEqual(reloaded.coins, 620)
    }
}

// v2.42: catalog pricing cannot be bypassed, and both decor slots count.
extension GameStoreTests {
    func testV242SideSlotDecorationUnlocksAdventure() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        XCTAssertFalse(store.hasPlacedAdventureDecoration)
        XCTAssertTrue(store.selectRoomItem(lamp, in: "living", slot: "side"))
        XCTAssertEqual(store.selectedItemsByRoom["living"], "sofa")
        XCTAssertTrue(store.hasPlacedAdventureDecoration)
        XCTAssertTrue(store.claimAdventureTask("decorate"))
        XCTAssertEqual(store.coins, 460)
    }
    func testV242SideSlotClaimPersistsAndCannotBeRepeated() {
        let (store, defaults) = makeStore()
        XCTAssertTrue(store.selectRoomItem(store.roomItems.first { $0.id == "plant" }!, in: "bedroom", slot: "side"))
        XCTAssertTrue(store.claimAdventureTask("decorate"))
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.hasPlacedAdventureDecoration)
        XCTAssertTrue(restored.completedTasks.contains("decorate"))
        XCTAssertFalse(restored.claimAdventureTask("decorate"))
        XCTAssertEqual(restored.coins, 510)
    }
    func testV242RejectsForgedRoomItemPrices() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.selectRoomItem(RoomItem(id: "lamp", name: "Star Lamp", icon: "lamp.table.fill", cost: 0)))
        XCTAssertFalse(store.selectRoomItem(RoomItem(id: "unknown", name: "Unknown", icon: "star", cost: 0)))
        XCTAssertEqual(store.coins, 500)
        XCTAssertFalse(store.hasPlacedAdventureDecoration)
        XCTAssertFalse(store.claimAdventureTask("decorate"))
    }
    func testV242RejectsForgedOutfitPrices() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.selectOutfit(Outfit(id: "party", name: "Party", icon: "sparkles", cost: 0)))
        XCTAssertFalse(store.selectOutfit(Outfit(id: "unknown", name: "Unknown", icon: "star", cost: 0)))
        XCTAssertEqual(store.coins, 500)
        XCTAssertFalse(store.claimAdventureTask("outfit"))
    }
    func testV242RejectsUnapprovedRecipeRewards() {
        let (store, _) = makeStore()
        store.recordRecipe("Unknown", rewardCoins: 10000)
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 10000)
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75, rewardStars: 99)
        XCTAssertTrue(store.cookedRecipes.isEmpty)
        XCTAssertEqual(store.coins, 500)
        XCTAssertEqual(store.stars, 0)
        XCTAssertFalse(store.claimAdventureTask("cupcake"))
    }
    func testV242ValidRecipeRewardRemainsOnceOnly() {
        let (store, defaults) = makeStore()
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
        store.recordRecipe("Rainbow Cupcake", rewardCoins: 75)
        XCTAssertEqual(store.coins, 575)
        XCTAssertEqual(store.stars, 1)
        XCTAssertTrue(store.claimAdventureTask("cupcake"))
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 675)
    }
    func testV242CanonicalItemsStillChargeOnce() {
        let (store, _) = makeStore()
        let lamp = store.roomItems.first { $0.id == "lamp" }!
        let party = store.outfits.first { $0.id == "party" }!
        XCTAssertTrue(store.selectRoomItem(lamp))
        XCTAssertTrue(store.selectRoomItem(lamp))
        XCTAssertTrue(store.selectOutfit(party))
        XCTAssertTrue(store.selectOutfit(party))
        XCTAssertEqual(store.coins, 300)
    }
}

// v2.43: imported/edited local JSON must not crash gameplay with Int overflow.
extension GameStoreTests {
    func testV243HugeSaveNumbersAreClampedAndPersisted() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "save"))) as? [String: Any])
        json["coins"] = Int.max
        json["stars"] = Int.max
        json["interactionCounts"] = ["living.dance": Int.max]
        json["dailyLifeProgress"] = ["day": Int.max, "phaseIndex": 2, "chainStep": 0, "streak": Int.max, "lastCompletedDay": Int.max, "phaseActionCounts": [:]]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, GameStore.maxSavedCurrency)
        XCTAssertEqual(restored.stars, GameStore.maxSavedCurrency)
        XCTAssertEqual(restored.dailyLifeProgress.day, GameStore.maxSavedDay)
        XCTAssertEqual(restored.dailyLifeProgress.streak, GameStore.maxSavedCounter)
        XCTAssertEqual(restored.interactionCount("dance", in: "living"), GameStore.maxSavedCounter)
        XCTAssertTrue(restored.advanceDayPhase())
        XCTAssertTrue(restored.performInteraction("dance", in: "living"))
        XCTAssertEqual(restored.interactionCount("dance", in: "living"), GameStore.maxSavedCounter)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, GameStore.maxSavedCurrency)
    }

    func testV243RewardAtIntegerMaximumDoesNotTrap() {
        let (store, defaults) = makeStore()
        store.reward(coins: Int.max, stars: Int.max)
        XCTAssertEqual(store.coins, GameStore.maxSavedCurrency)
        XCTAssertEqual(store.stars, GameStore.maxSavedCurrency)
        store.reward(coins: Int.max, stars: Int.max)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, GameStore.maxSavedCurrency)
    }

    func testV243DailyStreakAtIntegerMaximumDoesNotTrap() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "save"))) as? [String: Any])
        json["dailyLifeProgress"] = ["day": 12, "phaseIndex": 0, "chainStep": 2, "streak": Int.max, "lastCompletedDay": 11, "phaseActionCounts": [:]]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.performDailyChainAction("sleep"))
        XCTAssertEqual(restored.dailyLifeProgress.streak, GameStore.maxSavedCounter)
        XCTAssertEqual(restored.coins, 701)
    }

    func testV243NegativeSaveNumbersRemainNonnegative() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "save"))) as? [String: Any])
        json["coins"] = -100
        json["stars"] = -200
        json["interactionCounts"] = ["living.dance": -3]
        json["dailyLifeProgress"] = ["day": -5, "phaseIndex": -1, "chainStep": -1, "streak": -2, "lastCompletedDay": -1, "phaseActionCounts": [:]]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 0)
        XCTAssertEqual(restored.stars, 0)
        XCTAssertEqual(restored.dailyLifeProgress.day, 1)
        XCTAssertEqual(restored.dailyLifeProgress.streak, 0)
        XCTAssertEqual(restored.interactionCount("dance", in: "living"), 0)
    }
}

// v2.44: terminal commit sequence is a valid, protected save, never corruption.
extension GameStoreTests {
    private func v244Edit(_ data: Data, sequence: Int, coins: Int? = nil) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["commitSequence"] = sequence
        if let coins { json["coins"] = coins }
        return try JSONSerialization.data(withJSONObject: json)
    }
    private func v244Sequence(_ data: Data) throws -> Int {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["commitSequence"] as? Int)
    }
    func testV244TerminalPrimaryRemainsReadableAndImmutable() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 25)
        let terminal = try v244Edit(XCTUnwrap(defaults.data(forKey: "save")), sequence: Int.max)
        defaults.set(terminal, forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 525)
        XCTAssertTrue(restored.isSaveReadOnlyDueToSequenceLimit)
        restored.reward(coins: 100)
        XCTAssertEqual(defaults.data(forKey: "save"), terminal)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 525)
    }
    func testV244NearTerminalReservesFinalCommitForGameplay() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 20)
        let near = try v244Edit(XCTUnwrap(defaults.data(forKey: "save")), sequence: Int.max - 1)
        defaults.set(near, forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(defaults.data(forKey: "save"), near)
        XCTAssertFalse(restored.isSaveReadOnlyDueToSequenceLimit)
        restored.reward(coins: 30)
        let final = try XCTUnwrap(defaults.data(forKey: "save"))
        XCTAssertEqual(try v244Sequence(final), Int.max)
        XCTAssertTrue(restored.isSaveReadOnlyDueToSequenceLimit)
        restored.reward(coins: 40)
        XCTAssertEqual(defaults.data(forKey: "save"), final)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 550)
    }
    func testV244TerminalPendingReplaysWithoutOverflow() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let primary = try v244Edit(XCTUnwrap(defaults.data(forKey: "save")), sequence: Int.max - 1)
        let terminal = try v244Edit(primary, sequence: Int.max, coins: 777)
        defaults.set(primary, forKey: "save")
        defaults.set(terminal, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 777)
        XCTAssertTrue(restored.isSaveReadOnlyDueToSequenceLimit)
        XCTAssertEqual(defaults.data(forKey: "save"), terminal)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV244TerminalBackupRecoversWithoutRollback() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let primary = try v244Edit(XCTUnwrap(defaults.data(forKey: "save")), sequence: Int.max - 1)
        let terminal = try v244Edit(primary, sequence: Int.max, coins: 888)
        defaults.set(primary, forKey: "save")
        defaults.set(terminal, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 888)
        XCTAssertTrue(restored.isSaveReadOnlyDueToSequenceLimit)
        XCTAssertEqual(defaults.data(forKey: "save"), terminal)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), terminal)
    }
}

// v2.45: a staged snapshot with the same sequence but different bytes cannot
// supersede a committed backup when the primary is absent or older.
extension GameStoreTests {
    private func v245Snapshot(_ source: Data, sequence: Int, coins: Int) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        json["commitSequence"] = sequence
        json["coins"] = coins
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV245ConflictingEqualSequenceJournalCannotReplaceBackupWithoutPrimary() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let backup = try v245Snapshot(source, sequence: 5, coins: 880)
        let pending = try v245Snapshot(source, sequence: 5, coins: 640)
        defaults.removeObject(forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 880)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertNil(defaults.data(forKey: "save"))
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        restored.reward(coins: 100)
        XCTAssertNil(defaults.data(forKey: "save"))
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 880)
    }
    func testV245ConflictingEqualSequenceJournalCannotReplaceBackupWithOlderPrimary() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v245Snapshot(source, sequence: 4, coins: 520), forKey: "save")
        let backup = try v245Snapshot(source, sequence: 5, coins: 880)
        defaults.set(backup, forKey: "save.backup")
        let pending = try v245Snapshot(source, sequence: 5, coins: 640)
        defaults.set(pending, forKey: "save.pending")
        let originalPrimary = defaults.data(forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 880)
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), originalPrimary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
    func testV245GenuinelyNewerPendingStillReplays() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v245Snapshot(source, sequence: 4, coins: 520), forKey: "save")
        let backup = try v245Snapshot(source, sequence: 5, coins: 880)
        defaults.set(backup, forKey: "save.backup")
        defaults.set(try v245Snapshot(source, sequence: 6, coins: 940), forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 940)
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV245CommittedPrimaryStillWinsEqualSequenceConflict() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v245Snapshot(source, sequence: 5, coins: 777), forKey: "save")
        defaults.set(try v245Snapshot(source, sequence: 5, coins: 888), forKey: "save.backup")
        defaults.set(try v245Snapshot(source, sequence: 5, coins: 999), forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 777)
        // v2.50: all three equal-sequence copies remain protected.
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertNotNil(defaults.data(forKey: "save.pending"))
        XCTAssertTrue(GameStore(defaults: defaults, saveKey: "save").isSaveReadOnlyDueToAmbiguousRecovery)
    }
}

extension GameStoreTests {
    func testV245CorruptPrimaryAndEqualSequenceConflictRecoversBackup() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        func edited(_ sequence: Int, _ coins: Int) throws -> Data {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
            json["commitSequence"] = sequence
            json["coins"] = coins
            return try JSONSerialization.data(withJSONObject: json)
        }
        let backup = try edited(5, 880)
        defaults.set(Data("corrupt".utf8), forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        let pending = try edited(5, 640)
        defaults.set(pending, forKey: "save.pending")
        let originalPrimary = defaults.data(forKey: "save")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.coins, 880)
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), originalPrimary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
}

// v2.46: preserve every candidate byte-for-byte in a parent-initiated export.
extension GameStoreTests {
    private func v246Edited(_ source: Data, sequence: Int, coins: Int) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        json["commitSequence"] = sequence
        json["coins"] = coins
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV246AmbiguousRecoveryArchivePreservesAllRawCandidates() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v246Edited(source, sequence: 4, coins: 520)
        let backup = try v246Edited(source, sequence: 5, coins: 880)
        let pending = try v246Edited(source, sequence: 5, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        let bytes = try XCTUnwrap(restored.exportAmbiguousRecoveryArchive())
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self, from: bytes)
        XCTAssertEqual(archive.formatVersion, 2)
        XCTAssertEqual(archive.reason, "ambiguous-equal-sequence")
        XCTAssertEqual(archive.slots.map(\.name), ["primary", "backup", "pending"])
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, pending])
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
    func testV246ArchiveIncludesMalformedPrimaryAndMissingPrimary() throws {
        for corrupt in [false, true] {
            let (first, defaults) = makeStore()
            first.reward(coins: 10)
            let source = try XCTUnwrap(defaults.data(forKey: "save"))
            let backup = try v246Edited(source, sequence: 5, coins: 880)
            let pending = try v246Edited(source, sequence: 5, coins: 640)
            let primary = corrupt ? Data("corrupt-primary".utf8) : nil
            if let primary { defaults.set(primary, forKey: "save") }
            else { defaults.removeObject(forKey: "save") }
            defaults.set(backup, forKey: "save.backup")
            defaults.set(pending, forKey: "save.pending")
            let restored = GameStore(defaults: defaults, saveKey: "save")
            XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
            let archive = try JSONDecoder().decode(SaveRecoveryArchive.self,
                from: XCTUnwrap(restored.exportAmbiguousRecoveryArchive()))
            XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, pending])
            XCTAssertEqual(defaults.data(forKey: "save"), primary)
            XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
            XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        }
    }
    func testV246HealthySaveCannotExportRecoveryArchive() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertNil(store.exportAmbiguousRecoveryArchive())
    }
    func testV246ExportIsRepeatableAndDoesNotUnlockWrites() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let backup = try v246Edited(source, sequence: 5, coins: 880)
        let pending = try v246Edited(source, sequence: 5, coins: 640)
        defaults.removeObject(forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertEqual(restored.exportAmbiguousRecoveryArchive(), restored.exportAmbiguousRecoveryArchive())
        restored.reward(coins: 100)
        XCTAssertNil(defaults.data(forKey: "save"))
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
    }
}

// v2.47: exports are self-checking while v1 remains explicitly unverified.
extension GameStoreTests {
    func testV247CRC32KnownVectorAndMissingVersusEmpty() {
        XCTAssertEqual(SaveRecoveryArchive.checksum(for: Data("123456789".utf8)), "crc32:CBF43926:9")
        XCTAssertEqual(SaveRecoveryArchive.checksum(for: Data()), "crc32:00000000:0")
        XCTAssertEqual(SaveRecoveryArchive.checksum(for: nil), "absent")
    }
    func testV247ValidArchiveVerifiesAndRoundTrips() throws {
        let slots = [
            SaveRecoveryArchive.Slot(name: "primary", bytes: nil, checksum: "absent"),
            SaveRecoveryArchive.Slot(name: "backup", bytes: Data([0, 255, 127]), checksum: SaveRecoveryArchive.checksum(for: Data([0, 255, 127]))),
            SaveRecoveryArchive.Slot(name: "pending", bytes: Data(), checksum: "crc32:00000000:0")
        ]
        let archive = SaveRecoveryArchive(formatVersion: 2, reason: "ambiguous-equal-sequence", slots: slots)
        XCTAssertEqual(archive.integrityStatus, .verified)
        let bytes = try JSONEncoder().encode(archive)
        XCTAssertEqual(try JSONDecoder().decode(SaveRecoveryArchive.self, from: bytes).integrityStatus, .verified)
    }
    func testV247ChangedPayloadFailsIntegrityCheck() {
        let archive = SaveRecoveryArchive(formatVersion: 2, reason: "ambiguous-equal-sequence", slots: [
            .init(name: "primary", bytes: Data("tampered".utf8), checksum: SaveRecoveryArchive.checksum(for: Data("original".utf8))),
            .init(name: "backup", bytes: nil, checksum: "absent"),
            .init(name: "pending", bytes: Data(), checksum: "crc32:00000000:0")
        ])
        XCTAssertEqual(archive.integrityStatus, .invalid)
    }
    func testV247MissingChecksumAndSwappedSlotsAreInvalid() {
        let slots: [SaveRecoveryArchive.Slot] = [
            .init(name: "primary", bytes: nil, checksum: nil),
            .init(name: "backup", bytes: nil, checksum: "absent"),
            .init(name: "pending", bytes: nil, checksum: "absent")
        ]
        XCTAssertEqual(SaveRecoveryArchive(formatVersion: 2, reason: "ambiguous-equal-sequence", slots: slots).integrityStatus, .invalid)
        let reordered = [slots[1], slots[0], slots[2]]
        XCTAssertEqual(SaveRecoveryArchive(formatVersion: 2, reason: "ambiguous-equal-sequence", slots: reordered).integrityStatus, .invalid)
    }
    func testV247V1ArchiveIsLegacyUnverifiedAndUnknownVersionRejected() throws {
        let oldJSON = Data(#"{"formatVersion":1,"reason":"ambiguous-equal-sequence","slots":[{"name":"primary","bytes":null},{"name":"backup","bytes":""},{"name":"pending","bytes":null}]}"#.utf8)
        let old = try JSONDecoder().decode(SaveRecoveryArchive.self, from: oldJSON)
        XCTAssertEqual(old.integrityStatus, .legacyUnverified)
        XCTAssertEqual(SaveRecoveryArchive(formatVersion: 3, reason: old.reason, slots: old.slots).integrityStatus, .invalid)
    }
}

// v2.48: a parent may compare bounded, read-only save summaries before export.
extension GameStoreTests {
    private func v248Conflict() throws -> (GameStore, UserDefaults, Data, Data) {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        func edit(_ amount: Int) throws -> Data {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
            json["commitSequence"] = 5
            json["coins"] = amount
            return try JSONSerialization.data(withJSONObject: json)
        }
        let backup = try edit(880)
        let pending = try edit(640)
        defaults.removeObject(forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        return (restored, defaults, backup, pending)
    }
    func testV248HealthySaveHasNoRecoveryPreview() {
        let (store, _) = makeStore()
        XCTAssertNil(store.previewAmbiguousRecoverySlots())
    }
    func testV248ConflictPreviewsAllSlotsWithoutMutation() throws {
        let (store, defaults, backup, pending) = try v248Conflict()
        let preview = try XCTUnwrap(store.previewAmbiguousRecoverySlots())
        XCTAssertEqual(preview.map(\.id), ["primary", "backup", "pending"])
        XCTAssertEqual(preview.map(\.state), [.absent, .readable, .readable])
        XCTAssertEqual(preview.map(\.sequence), [nil, 5, 5])
        XCTAssertEqual(preview.map(\.coins), [nil, 880, 640])
        XCTAssertEqual(preview[1].stars, 1)
        XCTAssertEqual(preview[1].completedTasks, 0)
        XCTAssertTrue(preview[1].summary.contains("880 coins"))
        XCTAssertEqual(defaults.data(forKey: "save"), nil)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        XCTAssertNotNil(store.exportAmbiguousRecoveryArchive())
    }
    func testV248MalformedPrimaryIsNotPresentedAsReadable() throws {
        let (store, defaults, _, _) = try v248Conflict()
        defaults.set(Data("broken".utf8), forKey: "save")
        let preview = try XCTUnwrap(store.previewAmbiguousRecoverySlots())
        XCTAssertEqual(preview[0].state, .unreadable)
        XCTAssertNil(preview[0].coins)
        XCTAssertTrue(preview[0].summary.contains("Damaged"))
    }
    func testV248FutureSchemaCandidateIsNotMislabelledCorrupt() throws {
        let (store, defaults, backup, _) = try v248Conflict()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "save.backup")
        let preview = try XCTUnwrap(store.previewAmbiguousRecoverySlots())
        XCTAssertEqual(preview[1].state, .needsNewerApp)
        XCTAssertNil(preview[1].coins)
        XCTAssertTrue(preview[1].summary.contains("newer app"))
    }
    func testV248PreviewClampsExtremeAndNegativeTotals() throws {
        let (store, defaults, backup, pending) = try v248Conflict()
        var a = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        var b = try XCTUnwrap(JSONSerialization.jsonObject(with: pending) as? [String: Any])
        a["coins"] = Int.max
        a["stars"] = -999
        b["coins"] = -100
        b["stars"] = Int.max
        defaults.set(try JSONSerialization.data(withJSONObject: a), forKey: "save.backup")
        defaults.set(try JSONSerialization.data(withJSONObject: b), forKey: "save.pending")
        let preview = try XCTUnwrap(store.previewAmbiguousRecoverySlots())
        XCTAssertEqual(preview[1].coins, GameStore.maxSavedCurrency)
        XCTAssertEqual(preview[1].stars, 1)
        XCTAssertEqual(preview[2].coins, 0)
        XCTAssertEqual(preview[2].stars, GameStore.maxSavedCurrency)
        XCTAssertTrue(store.isSaveReadOnlyDueToAmbiguousRecovery)
    }
}


extension GameStoreTests {
    private func v249Edit(_ data: Data, sequence: Int, coins: Int) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["commitSequence"] = sequence
        json["coins"] = coins
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV249EqualSequencePrimaryBackupWithoutPendingPreservesBoth() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v249Edit(source, sequence: 9, coins: 880)
        let backup = try v249Edit(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.removeObject(forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 880) // Preview only, not a chosen winner.
        XCTAssertEqual(restored.previewAmbiguousRecoverySlots()?.map(\.coins), [880, 640, nil])
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self,
            from: XCTUnwrap(restored.exportAmbiguousRecoveryArchive()))
        XCTAssertEqual(archive.integrityStatus, .verified)
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, nil])
        restored.reward(coins: 50)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV249IdenticalEqualSequencePrimaryBackupIsSafe() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let identical = try v249Edit(source, sequence: 9, coins: 880)
        defaults.set(identical, forKey: "save")
        defaults.set(identical, forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        restored.reward(coins: 5)
        XCTAssertEqual(GameStore(defaults: defaults, saveKey: "save").coins, 885)
    }
    func testV249OlderBackupIsNotAmbiguous() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v249Edit(source, sequence: 9, coins: 880), forKey: "save")
        defaults.set(try v249Edit(source, sequence: 8, coins: 640), forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 880)
    }
    func testV249LateBackupMutationBlocksWrites() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: primary) as? [String: Any])
        let sequence = try XCTUnwrap(json["commitSequence"] as? Int)
        json["coins"] = 222
        json["commitSequence"] = sequence
        let backup = try JSONSerialization.data(withJSONObject: json)
        defaults.set(backup, forKey: "save.backup")
        defaults.removeObject(forKey: "save.pending")
        first.reward(coins: 25)
        XCTAssertTrue(first.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV249MalformedBackupDoesNotClaimEqualSequenceConflict() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        defaults.set(Data("bad backup".utf8), forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 510)
    }
}

// v2.50: an equal-sequence pending journal is not necessarily a stale replay.
extension GameStoreTests {
    private func v250Edited(_ bytes: Data, sequence: Int, coins: Int) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json["commitSequence"] = sequence
        json["coins"] = coins
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV250EqualSequencePrimaryPendingPreservesBothAndLocksWrites() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v250Edited(source, sequence: 8, coins: 880)
        let pending = try v250Edited(source, sequence: 8, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.removeObject(forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 880)
        XCTAssertEqual(restored.previewAmbiguousRecoverySlots()?.map(\.coins), [880, nil, 640])
        restored.reward(coins: 50)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertNil(defaults.data(forKey: "save.backup"))
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
    func testV250ParentExportRetainsBothConflictingRawCopies() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v250Edited(source, sequence: 8, coins: 880)
        let pending = try v250Edited(source, sequence: 8, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(pending, forKey: "save.pending")
        defaults.removeObject(forKey: "save.backup")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        let exported = try XCTUnwrap(restored.exportAmbiguousRecoveryArchive())
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self, from: exported)
        XCTAssertEqual(archive.integrityStatus, .verified)
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, nil, pending])
    }
    func testV250OlderBackupCannotResolvePrimaryPendingTie() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v250Edited(source, sequence: 9, coins: 880)
        let backup = try v250Edited(source, sequence: 8, coins: 710)
        let pending = try v250Edited(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
    func testV250IdenticalPendingAndOlderPendingAreNotConflicts() throws {
        let (first, defaults) = makeStore()
        first.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v250Edited(source, sequence: 8, coins: 880)
        defaults.set(primary, forKey: "save")
        defaults.set(primary, forKey: "save.pending")
        XCTAssertFalse(GameStore(defaults: defaults, saveKey: "save").isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
        defaults.set(try v250Edited(source, sequence: 7, coins: 640), forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 880)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV250LiveSessionDetectsEqualSequencePendingConflict() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: primary) as? [String: Any])
        let sequence = try XCTUnwrap(json["commitSequence"] as? Int)
        let pending = try v250Edited(primary, sequence: sequence, coins: 640)
        defaults.set(pending, forKey: "save.pending")
        store.reward(coins: 50)
        XCTAssertTrue(store.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }
}

// v2.51: a third journal slot cannot hide an equal-sequence primary/backup tie.
extension GameStoreTests {
    private func v251Edited(_ bytes: Data, sequence: Int, coins: Int) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json["commitSequence"] = sequence
        json["coins"] = coins
        return try JSONSerialization.data(withJSONObject: json)
    }

    func testV251OlderPendingCannotHideEqualPrimaryBackupConflict() throws {
        let (initial, defaults) = makeStore()
        initial.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v251Edited(source, sequence: 9, coins: 880)
        let backup = try v251Edited(source, sequence: 9, coins: 640)
        let pending = try v251Edited(source, sequence: 8, coins: 510)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.previewAmbiguousRecoverySlots()?.map(\.coins), [880, 640, 510])
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        let exported = try XCTUnwrap(restored.exportAmbiguousRecoveryArchive())
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self, from: exported)
        XCTAssertEqual(archive.integrityStatus, .verified)
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, pending])
    }

    func testV251NewerPendingCannotOverwriteEqualPrimaryBackupConflict() throws {
        let (initial, defaults) = makeStore()
        initial.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v251Edited(source, sequence: 9, coins: 880)
        let backup = try v251Edited(source, sequence: 9, coins: 640)
        let pending = try v251Edited(source, sequence: 10, coins: 950)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        restored.reward(coins: 50)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }

    func testV251LiveStorePreservesEqualBackupWhenOlderPendingExists() throws {
        let (store, defaults) = makeStore()
        store.reward(coins: 10)
        let primary = try XCTUnwrap(defaults.data(forKey: "save"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: primary) as? [String: Any])
        let sequence = try XCTUnwrap(json["commitSequence"] as? Int)
        let backup = try v251Edited(primary, sequence: sequence, coins: 640)
        let pending = try v251Edited(primary, sequence: max(0, sequence - 1), coins: 450)
        defaults.set(backup, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        store.reward(coins: 55)
        XCTAssertTrue(store.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
    }

    func testV251IdenticalBackupStillAllowsNewerPendingReplay() throws {
        let (initial, defaults) = makeStore()
        initial.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v251Edited(source, sequence: 9, coins: 880)
        let pending = try v251Edited(source, sequence: 10, coins: 950)
        defaults.set(primary, forKey: "save")
        defaults.set(primary, forKey: "save.backup")
        defaults.set(pending, forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 950)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }

    func testV251OlderBackupAndPendingRemainNonAmbiguous() throws {
        let (initial, defaults) = makeStore()
        initial.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        defaults.set(try v251Edited(source, sequence: 9, coins: 880), forKey: "save")
        defaults.set(try v251Edited(source, sequence: 8, coins: 640), forKey: "save.backup")
        defaults.set(try v251Edited(source, sequence: 7, coins: 450), forKey: "save.pending")
        let restored = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertFalse(restored.isSaveReadOnlyDueToAmbiguousRecovery)
        XCTAssertEqual(restored.coins, 880)
    }
    // v2.52: review/export must use the exact same raw save candidates.
    private func v252Fixture() throws -> (GameStore, UserDefaults, Data, Data) {
        let (initial, defaults) = makeStore()
        initial.reward(coins: 10)
        let source = try XCTUnwrap(defaults.data(forKey: "save"))
        let primary = try v251Edited(source, sequence: 9, coins: 880)
        let backup = try v251Edited(source, sequence: 9, coins: 640)
        defaults.set(primary, forKey: "save")
        defaults.set(backup, forKey: "save.backup")
        let store = GameStore(defaults: defaults, saveKey: "save")
        XCTAssertTrue(store.isSaveReadOnlyDueToAmbiguousRecovery)
        return (store, defaults, primary, backup)
    }

    func testV252InspectionExportsExactlyReviewedBytes() throws {
        let (store, defaults, primary, backup) = try v252Fixture()
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(inspection.previews.map(\.coins), [880, 640, nil])
        let data = try XCTUnwrap(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self, from: data)
        XCTAssertEqual(archive.integrityStatus, .verified)
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, nil])
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
    }

    func testV252RejectsChangedBackupEvenWithIdenticalVisibleTotals() throws {
        let (store, defaults, primary, backup) = try v252Fixture()
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        json["selectedOutfitID"] = "changed-but-not-shown"
        let changed = try JSONSerialization.data(withJSONObject: json)
        XCTAssertNotEqual(changed, backup)
        defaults.set(changed, forKey: "save.backup")
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), changed)
        let refreshed = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(refreshed.previews.map(\.coins), inspection.previews.map(\.coins))
        XCTAssertNotEqual(refreshed.id, inspection.id)
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self,
            from: XCTUnwrap(store.exportAmbiguousRecoveryArchive(inspectionID: refreshed.id)))
        XCTAssertEqual(archive.slots[1].bytes, changed)
    }

    func testV252RejectsNewPendingCopyAfterInspection() throws {
        let (store, defaults, primary, _) = try v252Fixture()
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        let pending = try v251Edited(primary, sequence: 10, coins: 950)
        defaults.set(pending, forKey: "save.pending")
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        XCTAssertEqual(defaults.data(forKey: "save.pending"), pending)
        let refreshed = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(refreshed.previews[2].coins, 950)
        XCTAssertNotNil(store.exportAmbiguousRecoveryArchive(inspectionID: refreshed.id))
    }

    func testV252RefreshRevokesOldInspectionEvenWithoutDiskChanges() throws {
        let (store, _, _, _) = try v252Fixture()
        let first = try XCTUnwrap(store.beginRecoveryInspection())
        let second = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(first.previews, second.previews)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: first.id))
        XCTAssertNotNil(store.exportAmbiguousRecoveryArchive(inspectionID: second.id))
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: UUID()))
    }

    func testV252HealthyStoreCannotCreateInspection() {
        let (store, _) = makeStore()
        XCTAssertNil(store.beginRecoveryInspection())
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: UUID()))
    }

    // v2.53: raw-byte duplicate hints are informational, not a conflict resolver.
    func testV253DifferentCopiesHaveDistinctByteHints() throws {
        let (store, _, _, _) = try v252Fixture()
        let previews = try XCTUnwrap(store.beginRecoveryInspection()).previews
        XCTAssertEqual(previews[0].byteComparisonSummary, "No other copy has identical bytes")
        XCTAssertEqual(previews[1].byteComparisonSummary, "No other copy has identical bytes")
        XCTAssertNil(previews[2].byteComparisonSummary)
        XCTAssertEqual(previews[2].state, .absent)
    }

    func testV253IdenticalPendingAndBackupHaveSymmetricHints() throws {
        let (store, defaults, primary, backup) = try v252Fixture()
        defaults.set(backup, forKey: "save.pending")
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(inspection.previews[0].byteComparisonSummary, "No other copy has identical bytes")
        XCTAssertEqual(inspection.previews[1].byteComparisonSummary, "Exact bytes match Pending copy")
        XCTAssertEqual(inspection.previews[2].byteComparisonSummary, "Exact bytes match Backup copy")
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self,
            from: XCTUnwrap(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id)))
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, backup])
    }

    func testV253InvisibleDifferenceDoesNotClaimExactMatch() throws {
        let (store, defaults, _, backup) = try v252Fixture()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        json["selectedOutfitID"] = "invisible-difference"
        let changed = try JSONSerialization.data(withJSONObject: json)
        XCTAssertNotEqual(changed, backup)
        defaults.set(changed, forKey: "save.pending")
        let previews = try XCTUnwrap(store.beginRecoveryInspection()).previews
        XCTAssertEqual(previews[1].coins, previews[2].coins)
        XCTAssertEqual(previews[1].byteComparisonSummary, "No other copy has identical bytes")
        XCTAssertEqual(previews[2].byteComparisonSummary, "No other copy has identical bytes")
        XCTAssertEqual(defaults.data(forKey: "save.pending"), changed)
    }

    func testV253UnreadableMatchingCopiesStillIdentifiedWithoutMutation() throws {
        let (store, defaults, _, backup) = try v252Fixture()
        let damaged = Data("not-json".utf8)
        defaults.set(damaged, forKey: "save")
        defaults.set(damaged, forKey: "save.pending")
        let previews = try XCTUnwrap(store.beginRecoveryInspection()).previews
        XCTAssertEqual(previews[0].state, .unreadable)
        XCTAssertEqual(previews[2].state, .unreadable)
        XCTAssertEqual(previews[0].byteComparisonSummary, "Exact bytes match Pending copy")
        XCTAssertEqual(previews[2].byteComparisonSummary, "Exact bytes match Primary copy")
        XCTAssertEqual(defaults.data(forKey: "save"), damaged)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
    }


    // v2.54: parent overview uses the same inspected bytes as the export.
    func testV254RecoveryOverviewCountsDistinctCopiesAndAbsentSlot() throws {
        let (store, _, _, _) = try v252Fixture()
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(inspection.summary,
            "2 of 3 copies present · 2 distinct byte versions · 2 readable")
        XCTAssertEqual(inspection.previews.count, 3)
        XCTAssertEqual(inspection.previews[2].state, .absent)
    }

    func testV254RecoveryOverviewCountsDuplicatePendingOnlyOnce() throws {
        let (store, defaults, primary, backup) = try v252Fixture()
        defaults.set(backup, forKey: "save.pending")
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(inspection.summary,
            "3 of 3 copies present · 2 distinct byte versions · 3 readable")
        let data = try XCTUnwrap(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        let archive = try JSONDecoder().decode(SaveRecoveryArchive.self, from: data)
        XCTAssertEqual(archive.slots.map(\.bytes), [primary, backup, backup])
    }

    func testV254RecoveryOverviewDistinguishesDamageFromNewerSchema() throws {
        let (store, defaults, _, backup) = try v252Fixture()
        let damaged = Data("damaged-json".utf8)
        defaults.set(damaged, forKey: "save")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        json["schemaVersion"] = GameStore.currentSaveSchemaVersion + 1
        let future = try JSONSerialization.data(withJSONObject: json)
        defaults.set(future, forKey: "save.pending")
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertEqual(inspection.summary,
            "3 of 3 copies present · 3 distinct byte versions · 1 readable · 1 requires a newer app · 1 unreadable")
        XCTAssertEqual(inspection.previews[0].state, .unreadable)
        XCTAssertEqual(inspection.previews[2].state, .needsNewerApp)
        XCTAssertEqual(defaults.data(forKey: "save"), damaged)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), future)
    }

    func testV254ConfirmationTimeRecheckRejectsStaleReviewWithoutChangingSaves() throws {
        let (store, defaults, primary, backup) = try v252Fixture()
        let inspection = try XCTUnwrap(store.beginRecoveryInspection())
        // Simulate an external write while the confirmation dialog is open.
        defaults.set(backup, forKey: "save.pending")
        XCTAssertNil(store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id))
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), backup)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), backup)
        let refreshed = try XCTUnwrap(store.beginRecoveryInspection())
        XCTAssertNotEqual(refreshed.id, inspection.id)
        XCTAssertNotNil(store.exportAmbiguousRecoveryArchive(inspectionID: refreshed.id))
    }

}

// v2.55: deterministic, single-threaded simulations of interleaved writes.
// UserDefaults is still NOT an atomic cross-process transaction.
private final class V255InterleavingDefaults: UserDefaults {
    var onPendingWrite: (() -> Void)?
    var onBackupWrite: (() -> Void)?
    override func set(_ value: Any?, forKey defaultName: String) {
        super.set(value, forKey: defaultName)
        if defaultName == "save.pending", let callback = onPendingWrite {
            onPendingWrite = nil
            callback()
        }
        if defaultName == "save.backup", let callback = onBackupWrite {
            onBackupWrite = nil
            callback()
        }
    }
}

extension GameStoreTests {
    private func v255Fixture() -> (GameStore, V255InterleavingDefaults, Data) {
        let suite = "DreamLifeHouseTests.v255.\(UUID().uuidString)"
        let defaults = V255InterleavingDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        GameStore(defaults: defaults, saveKey: "save").reward(coins: 10)
        let live = GameStore(defaults: defaults, saveKey: "save")
        return (live, defaults, defaults.data(forKey: "save")!)
    }
    private func v255Edited(_ source: Data) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        json["commitSequence"] = 777
        json["coins"] = 777
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testV255PreexistingForeignPendingJournalIsNeverReplaced() throws {
        let (live, defaults, primary) = v255Fixture()
        let foreign = try v255Edited(primary)
        defaults.set(foreign, forKey: "save.pending")
        live.reward(coins: 1)
        XCTAssertTrue(live.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), foreign)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
    }
    func testV255PrimaryChangedDuringStageIsPreserved() throws {
        let (live, defaults, primary) = v255Fixture()
        let foreign = try v255Edited(primary)
        defaults.onPendingWrite = { defaults.set(foreign, forKey: "save") }
        live.reward(coins: 1)
        XCTAssertTrue(live.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), foreign)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV255BackupChangedDuringStageIsPreserved() throws {
        let (live, defaults, primary) = v255Fixture()
        let foreign = try v255Edited(primary)
        defaults.onPendingWrite = { defaults.set(foreign, forKey: "save.backup") }
        live.reward(coins: 1)
        XCTAssertTrue(live.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), foreign)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV255PrimaryChangedDuringBackupRotationIsPreserved() throws {
        let (live, defaults, primary) = v255Fixture()
        let foreign = try v255Edited(primary)
        defaults.onBackupWrite = { defaults.set(foreign, forKey: "save") }
        live.reward(coins: 1)
        XCTAssertTrue(live.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), foreign)
        XCTAssertEqual(defaults.data(forKey: "save.backup"), primary)
        XCTAssertNil(defaults.data(forKey: "save.pending"))
    }
    func testV255ForeignPendingDuringRotationIsNotDeleted() throws {
        let (live, defaults, primary) = v255Fixture()
        let foreign = try v255Edited(primary)
        defaults.onBackupWrite = { defaults.set(foreign, forKey: "save.pending") }
        live.reward(coins: 1)
        XCTAssertTrue(live.isSaveReadOnlyDueToExternalChanges)
        XCTAssertEqual(defaults.data(forKey: "save"), primary)
        XCTAssertEqual(defaults.data(forKey: "save.pending"), foreign)
    }
}
