import Foundation

@main struct DreamLifeSmoke {
    @MainActor static func main() {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("SMOKE FAILED: \(message)") }
            passed += 1
        }
        func fresh(_ suffix: String) -> (GameStore,UserDefaults) {
            let d=UserDefaults(suiteName:"dreamlife.v233.smoke.\(suffix)")!
            d.removePersistentDomain(forName:"dreamlife.v233.smoke.\(suffix)")
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
        print("DreamLife House v2.33 model smoke: \(passed)/\(passed) assertions PASSED")
    }
}
