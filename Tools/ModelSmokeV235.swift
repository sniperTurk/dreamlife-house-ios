import Foundation

@main struct DreamLifeSmoke {
    @MainActor static func main() {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("SMOKE FAILED: \(message)") }
            passed += 1
        }
        func fresh(_ suffix: String) -> (GameStore,UserDefaults) {
            let d=UserDefaults(suiteName:"dreamlife.v235.smoke.\(suffix)")!
            d.removePersistentDomain(forName:"dreamlife.v235.smoke.\(suffix)")
            return (GameStore(defaults:d,saveKey:"save"),d)
        }
        do {
            let (s,d)=fresh("weekly")
            s.interactionCounts["trophy.lightkeeperStreak.crown"]=1
            s.interactionCounts["trophy.lumenCanopy.unlocked"]=1
            s.updateCharacter(accessoryID:"starlightCrown")
            check(s.interactWithLumenCanopy(in:"living"),"living interaction")
            check(s.interactWithLumenCanopy(in:"living"),"repeat interaction")
            check(s.weeklyCrownSparkProgress == 1,"same-day dedup")
            check(!s.claimWeeklyCrownSparkReward(),"early claim blocked")
            for day in 2...3 { s.dailyLifeProgress.day=day; _=s.interactWithLumenCanopy(in:"living") }
            check(s.weeklyCrownSparkProgress == 3,"distinct days")
            let coins=s.coins, stars=s.stars
            check(s.claimWeeklyCrownSparkReward(),"weekly claim")
            check(s.coins == coins+150 && s.stars == stars+5,"weekly payout")
            check(!s.claimWeeklyCrownSparkReward(),"duplicate claim blocked")
            let loaded=GameStore(defaults:d,saveKey:"save")
            check(loaded.isWeeklyCrownSparkClaimed,"claim persists")
            loaded.dailyLifeProgress.day=8
            check(loaded.weeklyCrownSparkProgress == 0,"week reset")
            check(!loaded.isWeeklyCrownSparkClaimed,"week claim resets")
            check(loaded.interactWithLumenCanopy(in:"living"),"new week interaction")
            check(loaded.weeklyCrownSparkProgress == 1,"new week count")
        }
        do {
            let (s,d)=fresh("guardian")
            s.interactionCounts["trophy.lightkeeperStreak.crown"]=1
            s.interactionCounts["trophy.crownCanopy.achievement"]=6
            check(!s.claimCometVeilReward(),"six moments not enough")
            check(!s.accessories.contains{$0.id=="cometVeil"},"locked veil hidden")
            s.interactionCounts["trophy.crownCanopy.achievement"]=7
            check(s.claimCometVeilReward(),"seven moments unlock")
            check(!s.claimCometVeilReward(),"one-time veil reward")
            check(s.accessories.contains{$0.id=="cometVeil"},"veil option appears")
            s.updateCharacter(accessoryID:"cometVeil")
            check(s.isCometVeilEquipped,"veil wearable")
            let loaded=GameStore(defaults:d,saveKey:"save")
            check(loaded.isCometVeilEquipped,"veil persists")
        }
        do {
            let (s,_)=fresh("guard")
            check(!s.interactWithLumenCanopy(in:"living"),"canopy locked")
            s.interactionCounts["trophy.lumenCanopy.unlocked"]=1
            check(!s.interactWithLumenCanopy(in:"bedroom"),"wrong room blocked")
            check(s.weeklyCrownSparkProgress==0,"no progress without crown")
        }
        do {
            let (s,d)=fresh("halo")
            s.dailyLifeProgress.day=15
            check(s.crownSparkWeeksCollected == 0,"no collected weeks initially")
            check(!s.claimCometHaloReward(),"early halo claim blocked")
            for week in 0...2 { s.interactionCounts["trophy.crownSparkWeekly.week\(week)"]=1 }
            check(s.crownSparkWeeksCollected == 3,"claimed weeks counted")
            check(s.crownSparkWeeklyCollectionTier == "Comet Collector","collection tier")
            let coins=s.coins, stars=s.stars
            check(s.claimCometHaloReward(),"halo unlock")
            check(s.coins == coins+110 && s.stars == stars+4,"halo payout")
            check(!s.claimCometHaloReward(),"duplicate halo reward blocked")
            check(!s.interactWithCometHalo(in:"bedroom"),"wrong room halo blocked")
            check(s.interactWithCometHalo(in:"living"),"halo can be used in living room")
            let loaded=GameStore(defaults:d,saveKey:"save")
            check(loaded.isCometHaloUnlocked,"halo survives reload")
            check(loaded.interactionCounts["trophy.crownSparkWeekly.cometHalo.visits"] == 1,"halo visits survive reload")
        }
        do {
            let (s,_)=fresh("chime-canopy")
            s.interactionCounts["trophy.radiantChime.unlocked"]=1
            s.interactionCounts["trophy.lumenCanopy.unlocked"]=1
            check(s.interactWithLumenCanopy(in:"living"),"canopy before chime")
            check(s.weeklyLightkeeperProgress == 0,"no lightkeeper progress before chime")
            check(!s.interactWithRadiantChime(in:"garden"),"chime wrong room blocked")
            check(s.interactWithRadiantChime(in:"living"),"chime in living room")
            check(s.interactWithLumenCanopy(in:"living"),"canopy after chime")
            check(s.weeklyLightkeeperProgress == 1,"lightkeeper moment counted")
            check(s.interactWithLumenCanopy(in:"living"),"canopy repeat")
            check(s.weeklyLightkeeperProgress == 1,"same-day lightkeeper dedup")
        }
        do {
            let (s,_)=fresh("three-weeks")
            s.interactionCounts["trophy.lightkeeperStreak.crown"]=1
            s.interactionCounts["trophy.lumenCanopy.unlocked"]=1
            s.updateCharacter(accessoryID:"starlightCrown")
            for week in 0...2 {
                for day in (week*7+1)...(week*7+3) {
                    s.dailyLifeProgress.day=day
                    check(s.interactWithLumenCanopy(in:"living"),"week \(week) day \(day) interaction")
                }
                check(s.claimWeeklyCrownSparkReward(),"week \(week) real claim")
                check(s.crownSparkWeeksCollected == week+1,"week \(week) collection progress")
            }
            check(s.isCometHaloRewardReady,"three real weekly claims unlock halo")
        }
        do {
            let (s,d)=fresh("future-backup")
            s.reward(coins:40)
            s.reward(coins:10)
            let backup=d.data(forKey:"save.backup")!
            var json=(try! JSONSerialization.jsonObject(with:d.data(forKey:"save")!)) as! [String:Any]
            json["schemaVersion"]=GameStore.currentSaveSchemaVersion+10
            json["newerAppExclusiveItem"]="keep"
            let future=try! JSONSerialization.data(withJSONObject:json)
            d.set(future,forKey:"save")
            let preview=GameStore(defaults:d,saveKey:"save")
            check(preview.isSaveReadOnlyDueToNewerVersion,"future primary triggers read-only mode")
            check(preview.coins==540,"compatible backup is previewed")
            check(d.data(forKey:"save")==future,"future primary preserved after load")
            preview.reward(coins:100)
            check(d.data(forKey:"save")==future,"future primary preserved after reward")
            check(d.data(forKey:"save.backup")==backup,"backup not rotated in read-only mode")
        }
        do {
            let (s,d)=fresh("future-no-backup")
            s.reward(coins:1)
            var json=(try! JSONSerialization.jsonObject(with:d.data(forKey:"save")!)) as! [String:Any]
            json["schemaVersion"]=GameStore.currentSaveSchemaVersion+1
            let future=try! JSONSerialization.data(withJSONObject:json)
            d.set(future,forKey:"save")
            d.removeObject(forKey:"save.backup")
            let preview=GameStore(defaults:d,saveKey:"save")
            check(preview.isSaveReadOnlyDueToNewerVersion,"future primary without backup is read-only")
            check(preview.coins==500,"without compatible backup use in-memory defaults")
            preview.reward(coins:2)
            check(d.data(forKey:"save")==future,"future primary still intact")
        }
        do {
            let (s,d)=fresh("corrupt-primary")
            s.reward(coins:40)
            s.reward(coins:10)
            d.set(Data("bad".utf8),forKey:"save")
            let recovered=GameStore(defaults:d,saveKey:"save")
            check(!recovered.isSaveReadOnlyDueToNewerVersion,"corruption is not future schema")
            check(recovered.coins==540,"backup restores corrupt primary")
            recovered.reward(coins:5)
            check(GameStore(defaults:d,saveKey:"save").coins==545,"recovered save is writable")
        }
        print("DreamLife House v2.35 model smoke: \(passed)/\(passed) assertions PASSED")
    }
}
