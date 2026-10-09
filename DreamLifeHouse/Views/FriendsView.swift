import SwiftUI

// v2.56: previously a single 3,700-character expression; split into small
// views so Xcode can type-check it, and given friend avatars. Logic unchanged.
struct FriendsView: View {
    @EnvironmentObject var store: GameStore
    @State private var message = loc("Invite a friend for a hangout.", "Takılmak için bir arkadaşını davet et.")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(loc("DreamLife Friends", "DreamLife Arkadaşları")).font(.title2.weight(.black)).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(loc("Invite friends into the house, build friendship levels, and unlock original party mini-games.", "Arkadaşlarını eve davet et, arkadaşlık seviyeni yükselt ve özgün parti mini oyunlarını aç."))
                        .font(.subheadline).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Text(message)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Color.white.opacity(0.85)))

                ForEach(store.friends) { friend in
                    FriendCard(friend: friend, message: $message)
                }

                BadgeCollectionCard(message: $message)
                if !store.ownedFriendKeepsakes.isEmpty { KeepsakeCard(message: $message) }

                Label(loc("Party wins: \(store.socialProgress.partyWins)", "Parti galibiyeti: \(store.socialProgress.partyWins)"), systemImage: "party.popper.fill")
                    .font(.caption.weight(.heavy)).foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 28)
            .readableWidth()
        }
    }
}

private struct FriendCard: View {
    @EnvironmentObject var store: GameStore
    let friend: FriendProfile
    @Binding var message: String

    private var isActive: Bool { store.socialProgress.activeFriendID == friend.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isActive {
                Picker(loc("Room", "Oda"), selection: Binding(get: { store.socialProgress.friendRoomID ?? "living" }, set: { _ = store.moveFriend(to: $0) })) {
                    ForEach(store.rooms) { Text(trName($0.name)).tag($0.id) }
                }
                .pickerStyle(.menu)
                .tint(Theme.pink)
                activities
                questOne
                if store.isFriendQuestClaimed(friend.id) { questTwo }
                if store.isFriendStoryPartyClaimed(friend.id) { questThree }
                miniGames
            }
        }
        .padding(14)
        .dreamCard()
    }

    private var header: some View {
        HStack(spacing: 12) {
            AvatarView(look: FriendLooks.look(for: friend.id), size: 50)
                .frame(width: 56, height: 62)
                .background(Circle().fill(Theme.lavenderSoft).frame(width: 58, height: 58))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(friend.name).font(.headline.weight(.heavy)).foregroundStyle(Theme.ink)
                    Image(systemName: friend.icon).font(.caption.weight(.bold)).foregroundStyle(Theme.lavender)
                }
                Text(loc("Friendship Lv. \(store.friendshipLevel(for: friend.id)) • \(store.friendshipXP(for: friend.id)) XP • \(store.hangoutCount(for: friend.id)) hangouts", "Arkadaşlık Sv. \(store.friendshipLevel(for: friend.id)) • \(store.friendshipXP(for: friend.id)) XP • \(store.hangoutCount(for: friend.id)) buluşma"))
                    .font(.caption).foregroundStyle(Theme.inkSoft)
                Text(loc("Loves: \(friend.favoriteActivity.capitalized)", "Sever: \(activityName(friend.favoriteActivity))")).font(.caption2.weight(.bold)).foregroundStyle(Theme.pink)
            }
            Spacer(minLength: 4)
            Button(isActive ? loc("Invited", "Davetli") : loc("Invite", "Davet Et")) {
                if store.inviteFriend(friend.id) {
                    message = loc("\(friend.name) joined your house!", "\(friend.name) evine geldi!")
                    Feedback.play(.success, settings: store.playerSettings)
                }
            }
            .buttonStyle(PillButtonStyle(color: isActive ? Theme.mint : Theme.pink))
        }
    }

    private var activities: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SocialButton(title: loc("Dance", "Dans"), icon: "music.note") { act("dance") }
                SocialButton(title: loc("Decorate", "Dekorasyon"), icon: "lamp.table.fill") { act("decorate") }
                SocialButton(title: loc("Garden", "Bahçe"), icon: "leaf.fill") { act("garden") }
            }
            HStack(spacing: 8) {
                SocialButton(title: loc("Style", "Stil"), icon: "tshirt.fill") { act("style") }
                SocialButton(title: loc("Cook", "Yemek"), icon: "fork.knife") { act("cook") }
            }
        }
    }

    private var questOne: some View {
        QuestProgress(title: loc("Friend Quest: do \(friend.favoriteActivity.capitalized) together 3 times", "Arkadaş Görevi: 3 kez birlikte \(activityName(friend.favoriteActivity))"),
                      progress: store.friendQuestProgress(for: friend.id), total: 3) {
            if store.isFriendQuestClaimed(friend.id) {
                Label(loc("Quest complete", "Görev tamamlandı"), systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(Theme.mint)
            } else if store.friendQuestProgress(for: friend.id) >= 3 {
                Button(loc("Claim 60 coins + 2 stars", "60 jeton + 2 yıldız al")) { if store.claimFriendQuest(friend.id) { success(loc("\(friend.name)'s friend quest complete!", "\(friend.name) ile arkadaşlık görevi tamamlandı!")) } }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text(loc("\(store.friendQuestProgress(for: friend.id))/3 favorite hangouts", "\(store.friendQuestProgress(for: friend.id))/3 favori buluşma")).font(.caption2).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var questTwo: some View {
        QuestProgress(title: loc("Story Quest 2: celebrate together twice", "Hikâye Görevi 2: iki kez birlikte kutlayın"),
                      progress: store.friendStoryPartyProgress(for: friend.id), total: 2) {
            if store.isFriendStoryPartyClaimed(friend.id) {
                Label(loc("Story chapter complete", "Hikâye bölümü tamamlandı"), systemImage: "book.closed.fill").font(.caption).foregroundStyle(Theme.mint)
            } else if store.friendStoryPartyProgress(for: friend.id) >= 2 {
                Button(loc("Claim 80 coins + 3 stars", "80 jeton + 3 yıldız al")) { if store.claimFriendStoryParty(friend.id) { success(loc("\(friend.name)'s story chapter complete!", "\(friend.name) ile hikâye bölümü tamamlandı!")) } }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text(loc("\(store.friendStoryPartyProgress(for: friend.id))/2 party moments", "\(store.friendStoryPartyProgress(for: friend.id))/2 parti anı")).font(.caption2).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var questThree: some View {
        let roomName = store.rooms.first(where: { $0.id == store.friendStoryRoomTarget(for: friend.id) })?.name ?? loc("special room", "özel oda")
        return QuestProgress(title: loc("Story Quest 3: \(roomName) memory", "Hikâye Görevi 3: \(trName(roomName)) anısı"),
                             progress: store.friendStoryRoomProgress(for: friend.id), total: 2) {
            if store.isFriendStoryRoomClaimed(friend.id) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(loc("Room chapter complete", "Oda bölümü tamamlandı"), systemImage: "house.and.flag.fill").font(.caption).foregroundStyle(Theme.mint)
                    if let keepsake = store.friendKeepsake(for: friend.id) {
                        if store.isFriendKeepsakeClaimed(friend.id) {
                            Label(loc("Keepsake: \(keepsake.name)", "Hatıra: \(trName(keepsake.name))"), systemImage: keepsake.icon).font(.caption.bold()).foregroundStyle(Theme.ink)
                        } else {
                            Button(loc("Collect \(keepsake.name)", "Topla: \(trName(keepsake.name))")) {
                                if store.claimFriendKeepsake(friend.id) { success(loc("A special friendship keepsake joined your collection!", "Koleksiyonuna özel bir arkadaşlık hatırası eklendi!")) }
                            }
                            .buttonStyle(PillButtonStyle(color: Theme.lavender))
                        }
                    }
                }
            } else if store.friendStoryRoomProgress(for: friend.id) >= 2 {
                Button(loc("Claim 100 coins + 4 stars", "100 jeton + 4 yıldız al")) { if store.claimFriendStoryRoom(friend.id) { success(loc("\(friend.name)'s room story complete!", "\(friend.name) ile oda hikâyesi tamamlandı!")) } }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text(loc("Move here, then do \(friend.favoriteActivity.capitalized) together twice (\(store.friendStoryRoomProgress(for: friend.id))/2)", "Buraya gelin, sonra iki kez birlikte \(activityName(friend.favoriteActivity)) (\(store.friendStoryRoomProgress(for: friend.id))/2)"))
                    .font(.caption2).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    @ViewBuilder private var miniGames: some View {
        if store.friendshipLevel(for: friend.id) >= 2 {
            HStack(spacing: 8) {
                SocialButton(title: loc("Tea Party", "Çay Partisi"), icon: "cup.and.saucer.fill", tint: Theme.peach) { mini("teaParty") }
                if store.friendshipLevel(for: friend.id) >= 3 {
                    SocialButton(title: loc("Talent Show", "Yetenek Gösterisi"), icon: "star.fill", tint: Theme.sun) { mini("talentShow") }
                }
            }
        } else {
            Label(loc("Reach Friendship Lv. 2 to unlock Tea Party.", "Çay Partisi için Arkadaşlık Seviyesi 2\'ye ulaş."), systemImage: "lock.fill")
                .font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    private func success(_ text: String) { message = text; Feedback.play(.success, settings: store.playerSettings) }
    private func act(_ action: String) { if store.socialActivity(action, with: friend.id) { success(loc("Hangout complete with \(friend.name)! Friendship grew.", "\(friend.name) ile buluşma tamamlandı! Arkadaşlık güçlendi.")) } }
    private func mini(_ action: String) { if store.playFriendMiniGame(action, with: friend.id) { success(loc("Mini-game complete! Bonus friendship, coins and a star earned.", "Mini oyun tamamlandı! Ek arkadaşlık, jeton ve bir yıldız kazandın.")) } }
}

private struct QuestProgress<Footer: View>: View {
    let title: String
    let progress: Int
    let total: Int
    let footer: Footer
    init(title: String, progress: Int, total: Int, @ViewBuilder footer: () -> Footer) {
        self.title = title; self.progress = progress; self.total = total; self.footer = footer()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.heavy)).foregroundStyle(Theme.ink)
            ProgressView(value: Double(min(progress, total)), total: Double(total)).tint(Theme.pink)
            footer
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.pinkSoft.opacity(0.6)))
    }
}

private struct BadgeCollectionCard: View {
    @EnvironmentObject var store: GameStore
    @Binding var message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: loc("Surprise Badges", "Sürpriz Rozetler"), icon: "rosette")
            Text(loc("Collect all five original room-event badges.", "Beş özgün oda etkinliği rozetinin hepsini topla.")).font(.caption).foregroundStyle(Theme.inkSoft)
            ProgressView(value: Double(store.surpriseBadgeProgress), total: Double(store.surpriseBadges.count)).tint(Theme.sun)
            Text(loc("\(store.surpriseBadgeProgress)/\(store.surpriseBadges.count) badges collected", "\(store.surpriseBadgeProgress)/\(store.surpriseBadges.count) rozet toplandı")).font(.caption2).foregroundStyle(Theme.inkSoft)
            HStack(alignment: .top) {
                ForEach(store.surpriseBadges) { badge in
                    let earned = store.hasSurpriseBadge(for: badge.roomID)
                    VStack(spacing: 4) {
                        IconBadge(icon: earned ? badge.icon : "lock.fill", tint: earned ? Theme.roomTint(badge.roomID) : Color.gray.opacity(0.5), size: 40)
                        Text(earned ? trName(badge.name) : loc("Locked", "Kilitli")).font(.caption2.bold()).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            if store.isSurpriseBadgeCollectionRewardClaimed {
                Label(loc("Collection complete • 150 coins + 5 stars claimed", "Koleksiyon tamam • 150 jeton + 5 yıldız alındı"), systemImage: "trophy.fill").font(.caption.bold()).foregroundStyle(Theme.mint)
            } else if store.isSurpriseBadgeCollectionComplete {
                Button(loc("Claim Collection Reward • 150 coins + 5 stars", "Koleksiyon Ödülünü Al • 150 jeton + 5 yıldız")) {
                    if store.claimSurpriseBadgeCollectionReward() {
                        message = loc("Surprise Badge collection complete!", "Sürpriz Rozet koleksiyonu tamamlandı!")
                        Feedback.play(.success, settings: store.playerSettings)
                    }
                }
                .buttonStyle(PillButtonStyle(color: Theme.sun))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dreamCard()
    }
}

private struct KeepsakeCard: View {
    @EnvironmentObject var store: GameStore
    @Binding var message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: loc("Friendship Keepsakes", "Arkadaşlık Hatıraları"), icon: "heart.text.square.fill")
            Text(loc("Display a keepsake in one room to make your shared memories part of the house.", "Ortak anılarınız evin bir parçası olsun diye bir hatırayı bir odada sergile.")).font(.caption).foregroundStyle(Theme.inkSoft)
            ForEach(store.ownedFriendKeepsakes) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Label(trName(item.name), systemImage: item.icon).font(.caption.bold()).foregroundStyle(Theme.ink)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(store.rooms) { room in
                                let shown = store.displayedFriendKeepsakes(in: room.id).contains(where: { $0.id == item.id })
                                Button(shown ? "✓ \(trName(room.name))" : trName(room.name)) {
                                    _ = store.setFriendKeepsake(item.id, displayed: true, in: room.id)
                                    message = loc("\(item.name) is now displayed in the \(room.name).", "\(trName(item.name)) artık burada sergileniyor: \(trName(room.name)).")
                                    Feedback.play(.tap, settings: store.playerSettings)
                                }
                                .buttonStyle(PillButtonStyle(color: shown ? Theme.mint : Theme.roomTint(room.id)))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dreamCard()
    }
}

private struct SocialButton: View {
    let title: String
    let icon: String
    var tint: Color = Theme.lavender
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(TileButtonStyle(selected: false, tint: tint))
        .foregroundStyle(tint)
    }
}
