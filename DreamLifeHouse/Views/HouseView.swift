import SwiftUI

// v2.56: the House screen was one ~6,000-character SwiftUI expression (which
// Xcode cannot type-check in reasonable time) and mixed Color/Material in a
// ternary (a compile error). It is now split into small views and redrawn as
// an illustrated room. Gameplay calls and accessibility identifiers are unchanged.
struct HouseView: View {
 @EnvironmentObject var store:GameStore; @State private var roomID="living"; @State private var activeSlot="main"; @State private var message="Choose a room and make it yours."
 @State private var pendingPurchase: RoomItem?
 var room:HouseRoom { store.rooms.first{$0.id==roomID} ?? store.rooms[0] }
 var interaction:(String,String,String) { switch roomID {case "bedroom":return("sleep","Rest","bed.double.fill");case "kitchen":return("snack","Have Snack","fork.knife");case "bathroom":return("shower","Take Shower","shower.fill");case "garden":return("play","Play Outside","leaf.fill");default:return("dance","Dance","music.note")} }
 func contextMessage(_ action:String)->String { switch action {case "sleep":return "Bedtime! Energy restored.";case "dance":return "Dance zone! Fun increased.";case "snack":return "Kitchen stop! Hunger restored.";case "shower":return "Shower time! Cleanliness restored.";case "play":return "Outdoor play! Fun increased.";default:return "Activity complete!"} }
 // Keep late-game actions in a separate ViewBuilder to avoid growing the main
 // House screen's SwiftUI type-checking expression with every new collection.
 @ViewBuilder private var radiantDecorationControls: some View {
  // v2.34: these earned decorations previously had no tappable House control,
  // making the Lightkeeper and Crown Spark quest chains unreachable in normal play.
  if roomID == "living" && (store.isRadiantChimeUnlocked || store.isLumenCanopyUnlocked || store.isCometHaloUnlocked) {
    ScrollView(.horizontal,showsIndicators:false) {
      HStack(spacing:10) {
        if store.isRadiantChimeUnlocked {
          Button {
            if store.interactWithRadiantChime(in:roomID) { message="Radiant Chime rang! Visit Lumen Canopy next · Fun +2 · Energy +3" }
          } label: { Label("Ring Radiant Chime",systemImage:"bell.fill") }
          .accessibilityIdentifier("living.radiantChime")
          .accessibilityHint("Ring the chime, then visit Lumen Canopy to advance the Lightkeeper challenge.")
        }
        if store.isLumenCanopyUnlocked {
          Button {
            let newCrownSpark = store.isStarlightCrownEquipped && !store.isCrownCanopyMomentClaimedToday
            let newLightkeeper = store.isLightkeeperMomentReady
            if store.interactWithLumenCanopy(in:roomID) {
              message = newCrownSpark ? "Crown Spark earned! +35 coins · +1 star" :
                        newLightkeeper ? "Lightkeeper moment recorded!" : "Lumen Canopy glows! Fun +3 · Energy +4"
            }
          } label: { Label("Visit Lumen Canopy",systemImage:"moon.stars.fill") }
          .accessibilityIdentifier("living.lumenCanopy")
          .accessibilityHint("Visit after ringing Radiant Chime. Wear Starlight Crown for a daily Crown Spark.")
        }
        if store.isCometHaloUnlocked {
          Button {
            if store.interactWithCometHalo(in:roomID) { message="Comet Halo glimmers! Fun +2 · Energy +2" }
          } label: { Label("Admire Comet Halo",systemImage:"sparkle") }
          .accessibilityIdentifier("living.cometHalo")
          .accessibilityHint("Admire your earned decoration to increase Fun and Energy.")
        }
      }.buttonStyle(PillButtonStyle(color: Theme.lavender)).padding(.horizontal).padding(.vertical,4)
    }
  }
 }

 var body: some View {
  NavigationStack {
   ScrollView(.vertical) {
    VStack(spacing: 14) {
     TopBar()
     roomPicker
     needsPanel
     RoomStage(roomID: roomID, activeSlot: $activeSlot, message: $message, onDrop: { contextMessage($0) })
      .padding(.horizontal)
     actionRow
     Text(message)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Theme.ink)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16).padding(.vertical, 10)
      .frame(maxWidth: .infinity)
      .background(Capsule().fill(Color.white.opacity(0.85)))
      .padding(.horizontal)
      .accessibilityIdentifier("house.actionFeedback")
      .accessibilityAddTraits(.updatesFrequently)
     radiantDecorationControls
     if roomID == "garden" { gardenActions }
     if roomID == "living" { LivingRoomCollection(message: $message) }
     decorShop
     HouseGoals(message: $message)
    }
    .padding(.bottom, 28)
   }
   .background(AppBackground())
   .toolbar(.hidden, for: .navigationBar)
   .confirmationDialog(pendingPurchase.map { "Buy \($0.name)?" } ?? "Buy decoration?",
                       isPresented: Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } }),
                       titleVisibility: .visible, presenting: pendingPurchase) { item in
    Button("Buy for \(item.cost) coins") { place(item) }
    Button("Not now", role: .cancel) { }
   } message: { item in
    Text("\(item.name) costs \(item.cost) coins. You have \(store.coins) coins.")
   }
  }
 }

 // MARK: Room picker & needs

 private var roomPicker: some View {
  ScrollView(.horizontal, showsIndicators: false) {
   HStack(spacing: 10) {
    ForEach(store.rooms) { r in
     Button {
      roomID = r.id; message = "Welcome to the \(r.name)!"
      Feedback.play(.tap, settings: store.playerSettings)
     } label: {
      VStack(spacing: 4) {
       Image(systemName: r.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.roomTint(r.id))
       Text(r.name).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(width: 92, height: 64)
     }
     .buttonStyle(TileButtonStyle(selected: roomID == r.id, tint: Theme.roomTint(r.id)))
     .accessibilityAddTraits(roomID == r.id ? .isSelected : [])
    }
   }
   .padding(.horizontal).padding(.vertical, 4)
  }
 }

 private var needsPanel: some View {
  HStack(spacing: 10) {
   NeedMeter(name: "Energy", icon: "bolt.fill", value: store.characterNeeds.energy, tint: Theme.sun)
   NeedMeter(name: "Fun", icon: "face.smiling.inverse", value: store.characterNeeds.fun, tint: Theme.pink)
   NeedMeter(name: "Clean", icon: "drop.fill", value: store.characterNeeds.hygiene, tint: Theme.sky)
   NeedMeter(name: "Food", icon: "fork.knife", value: store.characterNeeds.hunger, tint: Theme.mint)
  }
  .padding(12)
  .dreamCard(cornerRadius: 20)
  .padding(.horizontal)
 }

 private var actionRow: some View {
  HStack(spacing: 10) {
   Button {
    if store.performInteraction(interaction.0, in: roomID) {
     message = "\(interaction.1) completed!"
     Feedback.play(.success, settings: store.playerSettings)
    }
   } label: {
    Label(interaction.1, systemImage: interaction.2)
   }
   .buttonStyle(CandyButtonStyle(color: Theme.roomTint(roomID)))
   Text(room.name)
    .font(.headline.weight(.heavy))
    .foregroundStyle(Theme.ink)
    .lineLimit(1).minimumScaleFactor(0.7)
  }
  .padding(.horizontal)
 }

 private var gardenActions: some View {
  HStack(spacing: 10) {
   GardenAction(title: "Swim", icon: "figure.pool.swim", tint: Theme.sky) {
    if store.performGardenActivity("swim") { message = "Pool time! Fun increased."; Feedback.play(.success, settings: store.playerSettings) }
   }
   GardenAction(title: "Lounge", icon: "sun.max.fill", tint: Theme.sun) {
    if store.performGardenActivity("lounge") { message = "Relaxed by the pool."; Feedback.play(.success, settings: store.playerSettings) }
   }
   GardenAction(title: "Pet Play", icon: "pawprint.fill", tint: Theme.peach) {
    if store.performGardenActivity("petPlay") { message = "Garden play together!"; Feedback.play(.success, settings: store.playerSettings) }
    else { message = "Bring your pet to the Garden first (Play › Pet)." }
   }
  }
  .padding(.horizontal)
 }

 // MARK: Decor shop

 private func placedItem(_ slot: String) -> RoomItem? {
  let id = store.selectedItemsByRoomSlot[roomID]?[slot] ?? (slot == "main" ? store.selectedItemsByRoom[roomID] : nil)
  return store.roomItems.first { $0.id == id }
 }

 private var decorShop: some View {
  VStack(alignment: .leading, spacing: 10) {
   HStack {
    SectionTitle(title: "Decorate", icon: "paintbrush.pointed.fill")
    Picker("Slot", selection: $activeSlot) {
     Text("Main spot").tag("main")
     Text("Side spot").tag("side")
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 190)
   }
   .padding(.horizontal)
   ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {
     ForEach(store.roomItems) { item in
      let owned = store.ownsRoomItem(item)
      let placed = placedItem(activeSlot)?.id == item.id
      Button { buy(item) } label: {
       VStack(spacing: 6) {
        Image(systemName: item.icon)
         .font(.system(size: 30))
         .symbolRenderingMode(.multicolor)
         .foregroundStyle(Theme.roomTint(roomID))
         .frame(height: 36)
        Text(item.name).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.8)
        if owned {
         Text(placed ? "Placed ✓" : "Owned")
          .font(.caption2.weight(.bold))
          .foregroundStyle(placed ? Theme.mint : Theme.inkSoft)
        } else {
         HStack(spacing: 3) {
          Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Theme.peach)
          Text("\(item.cost)")
         }
         .font(.caption2.weight(.heavy))
        }
       }
       .frame(width: 104, height: 100)
      }
      .buttonStyle(TileButtonStyle(selected: placed, tint: Theme.roomTint(roomID)))
      .accessibilityLabel(owned ? "\(item.name), \(placed ? "placed" : "owned")" : "\(item.name), \(item.cost) coins")
      .accessibilityHint("Places it in the \(activeSlot == "main" ? "main" : "side") spot of the \(room.name).")
     }
    }
    .padding(.horizontal).padding(.vertical, 4)
   }
  }
 }

 private func buy(_ item: RoomItem) {
  if store.ownsRoomItem(item) { place(item); return }
  guard store.coins >= item.cost else {
   message = "You need \(item.cost - store.coins) more coins for \(item.name)."
   Feedback.play(.warning, settings: store.playerSettings)
   return
  }
  if store.playerSettings.purchaseConfirmation && item.cost > 0 { pendingPurchase = item } else { place(item) }
 }

 private func place(_ item: RoomItem) {
  let wasOwned = store.ownsRoomItem(item)
  if store.selectRoomItem(item, in: roomID, slot: activeSlot) {
   message = "\(item.name) placed in \(room.name)!"
   Feedback.play(wasOwned ? .tap : .purchase, settings: store.playerSettings)
  } else {
   message = "You need more coins."
   Feedback.play(.warning, settings: store.playerSettings)
  }
 }
}

// MARK: - Illustrated room stage

private struct RoomStage: View {
 @EnvironmentObject var store: GameStore
 let roomID: String
 @Binding var activeSlot: String
 @Binding var message: String
 let onDrop: (String) -> String
 @GestureState private var dragOffset: CGSize = .zero

 private var layout: RoomLayout { RoomLayout.forRoom(roomID) }

 private func placedItem(_ slot: String) -> RoomItem? {
  let id = store.selectedItemsByRoomSlot[roomID]?[slot] ?? (slot == "main" ? store.selectedItemsByRoom[roomID] : nil)
  return store.roomItems.first { $0.id == id }
 }

 var body: some View {
  GeometryReader { geo in
   let w = geo.size.width, h = geo.size.height
   ZStack {
    RoomBackdrop(roomID: roomID)
    actionZone(w: w, h: h)
    decorSlot("main", at: layout.mainDecor, w: w, h: h)
    decorSlot("side", at: layout.sideDecor, w: w, h: h)
    keepsakeShelf
    if store.petProfile.roomID == roomID {
     PetPortrait(species: store.petProfile.species, size: 54)
      .position(x: w * layout.petSpot.x, y: h * layout.petSpot.y)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(store.petProfile.name) the \(store.petProfile.species) is here")
    }
    if let friend = store.activeFriend, store.socialProgress.friendRoomID == roomID {
     VStack(spacing: 0) {
      AvatarView(look: FriendLooks.look(for: friend.id), size: 62)
      NameTag(text: friend.name, tint: Theme.lavender)
     }
     .position(x: w * layout.friendSpot.x, y: h * layout.friendSpot.y)
     .accessibilityElement(children: .ignore)
     .accessibilityLabel("\(friend.name) is visiting")
    }
    player(w: w, h: h)
   }
  }
  .frame(height: 320)
  .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white, lineWidth: 4))
  .shadow(color: Theme.roomTint(roomID).opacity(0.25), radius: 14, y: 8)
 }

 private func actionZone(w: CGFloat, h: CGFloat) -> some View {
  let z = layout.actionZone
  return RoundedRectangle(cornerRadius: 18, style: .continuous)
   .strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
   .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.12)))
   .overlay(alignment: .top) {
    Text(layout.zoneLabel)
     .font(.system(size: 9, weight: .heavy, design: .rounded))
     .foregroundStyle(Theme.ink)
     .padding(.horizontal, 6).padding(.vertical, 2)
     .background(Capsule().fill(Color.white.opacity(0.85)))
     .offset(y: -8)
   }
   .frame(width: w * z.width, height: h * z.height)
   .position(x: w * z.midX, y: h * z.midY)
   .accessibilityHidden(true)
 }

 private func decorSlot(_ slot: String, at point: CGPoint, w: CGFloat, h: CGFloat) -> some View {
  let item = placedItem(slot)
  let selected = activeSlot == slot
  return Button {
   activeSlot = slot
   message = "\(slot == "main" ? "Main" : "Side") spot selected. Pick a decoration below."
  } label: {
   VStack(spacing: 2) {
    ZStack {
     if let item {
      Image(systemName: item.icon)
       .font(.system(size: slot == "main" ? 46 : 34))
       .symbolRenderingMode(.multicolor)
       .foregroundStyle(Theme.roomTint(roomID).gradient)
       .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
     } else {
      Image(systemName: "plus")
       .font(.system(size: 18, weight: .black))
       .foregroundStyle(Theme.inkSoft)
       .frame(width: 44, height: 44)
       .background(Circle().strokeBorder(Theme.inkSoft.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
     }
    }
    .padding(6)
    .background(Circle().fill(Color.white.opacity(selected ? 0.75 : 0)))
    Text(slot == "main" ? "Main" : "Side")
     .font(.system(size: 9, weight: .heavy, design: .rounded))
     .foregroundStyle(selected ? Color.white : Theme.ink)
     .padding(.horizontal, 6).padding(.vertical, 1)
     .background(Capsule().fill(selected ? Theme.pink : Color.white.opacity(0.8)))
   }
  }
  .buttonStyle(.plain)
  .position(x: w * point.x, y: h * point.y)
  .accessibilityLabel("\(slot == "main" ? "Main" : "Side") decoration spot: \(item?.name ?? "empty")")
  .accessibilityAddTraits(selected ? .isSelected : [])
 }

 // Keepsakes sit on a wall shelf so up to five never overlap each other.
 @ViewBuilder private var keepsakeShelf: some View {
  let keepsakes = store.displayedFriendKeepsakes(in: roomID)
  if !keepsakes.isEmpty {
   VStack {
    HStack(spacing: 4) {
     ForEach(keepsakes) { keepsake in
      Button {
       if store.interactWithDisplayedKeepsake(keepsake.id, in: roomID) {
        message = "A sweet memory with \(store.friends.first(where: { $0.id == keepsake.friendID })?.name ?? "a friend")!"
        Feedback.play(.tap, settings: store.playerSettings)
       }
      } label: {
       VStack(spacing: 1) {
        Image(systemName: keepsake.icon).font(.system(size: 18)).foregroundStyle(Theme.pink.gradient)
        Text(keepsake.name).font(.system(size: 7, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
         .foregroundStyle(Theme.ink)
       }
       .frame(width: 54, height: 40)
       .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.88)))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Keepsake: \(keepsake.name)")
     }
    }
    .padding(.top, 10)
    Spacer()
   }
  }
 }

 private func player(w: CGFloat, h: CGFloat) -> some View {
  let pos = store.characterPosition(in: roomID)
  let look = AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID)
  return VStack(spacing: 0) {
   AvatarView(look: look, size: 78)
   NameTag(text: store.characterProfile.name, tint: Theme.pink)
  }
  .scaleEffect(dragOffset == .zero ? 1 : 1.08)
  .position(x: w * pos.x, y: h * pos.y)
  .offset(dragOffset)
  .gesture(
   DragGesture()
    .updating($dragOffset) { value, state, _ in state = value.translation }
    .onEnded { value in
     // Use the avatar's new centre (start + translation) and keep it inside the stage.
     let x = min(0.9, max(0.1, (w * pos.x + value.translation.width) / max(1, w)))
     let y = min(0.85, max(0.3, (h * pos.y + value.translation.height) / max(1, h)))
     if let action = store.dropCharacter(in: roomID, x: x, y: y) {
      message = onDrop(action)
      Feedback.play(.success, settings: store.playerSettings)
     } else {
      message = "Moved to a new spot."
     }
    }
  )
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(store.characterProfile.name), your character")
  .accessibilityHint("Drag to move around the room. Drop on the dotted area to do the room activity.")
 }
}

private struct NameTag: View {
 let text: String
 let tint: Color
 var body: some View {
  Text(text)
   .font(.system(size: 10, weight: .heavy, design: .rounded))
   .foregroundStyle(.white)
   .lineLimit(1)
   .padding(.horizontal, 7).padding(.vertical, 2)
   .background(Capsule().fill(tint.gradient))
 }
}

private struct GardenAction: View {
 let title: String; let icon: String; let tint: Color; let action: () -> Void
 var body: some View {
  Button(action: action) {
   VStack(spacing: 4) {
    Image(systemName: icon).font(.title3.weight(.bold)).foregroundStyle(tint)
    Text(title).font(.caption.weight(.heavy))
   }
   .frame(maxWidth: .infinity).padding(.vertical, 10)
  }
  .buttonStyle(TileButtonStyle(selected: false, tint: tint))
 }
}

// MARK: - Living-room collection shelf
// Earned collectibles used to be absolutely positioned inside the room and
// overlapped one another late in the game. They now live on a scrollable shelf.

private struct LivingRoomCollection: View {
 @EnvironmentObject var store: GameStore
 @Binding var message: String

 private var hasAny: Bool {
  store.isDreamHouseTrophyUnlocked || store.isAuroraMobileUnlocked || store.isPrismCharmUnlocked ||
  store.isStarlightSuncatcherUnlocked || store.isMoonbeamTerrariumUnlocked || store.isCelestialLanternUnlocked ||
  !store.unlockedTrophyDecorations.isEmpty
 }

 var body: some View {
  if hasAny {
   VStack(alignment: .leading, spacing: 8) {
    SectionTitle(title: "My Collection", icon: "sparkles").padding(.horizontal)
    ScrollView(.horizontal, showsIndicators: false) {
     HStack(spacing: 10) {
      if store.isDreamHouseTrophyUnlocked {
       CollectibleTile(icon: "trophy.fill", title: "Dream House Trophy", subtitle: store.dreamHouseTrophyLevel, tint: Theme.sun) {
        if store.interactWithDreamHouseTrophy(in: "living") { message = "Dream House Trophy admired! Fun +4 · visits: \(store.dreamHouseTrophyVisitCount)" }
       }
      }
      if store.isAuroraMobileUnlocked {
       CollectibleTile(icon: "wind", title: "Aurora Mobile", subtitle: "Shimmer", tint: Color(hex: 0x4FC9E0)) {
        if store.interactWithAuroraMobile(in: "living") {
         let fresh = store.recordAuroraDailyInteraction()
         message = fresh ? "Aurora Mobile shimmered! \(store.auroraCharacterReaction)" : "Aurora Mobile shimmered again! Energy +2 · Fun +2"
        }
       }
      }
      if store.isPrismCharmUnlocked {
       CollectibleTile(icon: "diamond.fill", title: "Prism Charm", subtitle: "Visits \(store.prismCharmVisitCount)", tint: Theme.lavender) {
        if store.interactWithPrismCharm(in: "living") { message = "Prism Charm glowed! Fun +2 · visits: \(store.prismCharmVisitCount)" }
       }
      }
      if store.isStarlightSuncatcherUnlocked {
       CollectibleTile(icon: "sun.max.fill", title: "Starlight Suncatcher", subtitle: "Step 1", tint: Theme.sun) {
        if store.interactWithStarlightSuncatcher(in: "living") { message = "Starlight Suncatcher shimmered! Fun +3 · Energy +2" }
       }
      }
      if store.isMoonbeamTerrariumUnlocked {
       CollectibleTile(icon: "leaf.fill", title: "Moonbeam Terrarium", subtitle: "Step 2", tint: Theme.mint) {
        if store.interactWithMoonbeamTerrarium(in: "living") { message = "Moonbeam Terrarium glowed! Energy +3" }
       }
      }
      if store.isCelestialLanternUnlocked {
       CollectibleTile(icon: "lamp.table.fill", title: "Celestial Lantern", subtitle: "Step 3", tint: Theme.peach) {
        if store.interactWithCelestialLantern(in: "living") { message = "Celestial Lantern twinkled! Fun +4" }
       }
      }
      ForEach(store.unlockedTrophyDecorations, id: \.self) { name in
       CollectibleTile(icon: store.trophyDecorationIcons[name] ?? "sparkles", title: name,
                       subtitle: "Visits \(store.trophyDecorationVisitCount(name))", tint: Theme.pink) {
        if store.interactWithTrophyDecoration(name, in: "living") { message = "\(name) sparkled! Visits: \(store.trophyDecorationVisitCount(name))" }
       }
      }
     }
     .padding(.horizontal).padding(.vertical, 4)
    }
   }
  }
 }
}

private struct CollectibleTile: View {
 @EnvironmentObject var store: GameStore
 let icon: String; let title: String; let subtitle: String; let tint: Color; let action: () -> Void
 var body: some View {
  Button {
   action()
   Feedback.play(.tap, settings: store.playerSettings)
  } label: {
   VStack(spacing: 4) {
    IconBadge(icon: icon, tint: tint, size: 40)
    Text(title).font(.caption2.weight(.heavy)).lineLimit(2).multilineTextAlignment(.center)
    Text(subtitle).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.inkSoft)
   }
   .frame(width: 96, height: 104)
  }
  .buttonStyle(TileButtonStyle(selected: false, tint: tint))
 }
}

// MARK: - Goals

private struct HouseGoals: View {
 @EnvironmentObject var store: GameStore
 @Binding var message: String

 var body: some View {
  VStack(alignment: .leading, spacing: 10) {
   SectionTitle(title: "Today's Goals", icon: "checklist").padding(.horizontal)
   VStack(spacing: 10) {
    dailyGoals
    trophyGoals
    radiantGoals
    lightkeeperGoals
    crownGoals
    keepsakeGoals
   }
   .padding(.horizontal)
  }
 }

 private func done(_ text: String) { message = text; Feedback.play(.success, settings: store.playerSettings) }

 @ViewBuilder private var dailyGoals: some View {
  QuestCard(icon: "gift.fill", tint: Theme.pink, title: "Room Surprise",
            detail: "Today: \(store.dailyRoomSurpriseRoomName) · \(store.isDailyRoomSurpriseReady ? "discovered" : "try its special activity")") {
   Button(store.isDailyRoomSurpriseClaimed ? "Claimed" : "Claim +25 ✦"){if store.claimDailyRoomSurprise(){done("Room Surprise found! +25 coins, +1 star.")}}.disabled(!store.isDailyRoomSurpriseReady || store.isDailyRoomSurpriseClaimed)
  }
  QuestCard(icon: "person.2.fill", tint: Theme.lavender, title: "Surprise Buddy", detail: store.dailyRoomSurpriseBuddyDetail) {
   Button(store.isDailyRoomSurpriseBuddyClaimed ? "Claimed" : "Claim +\(store.dailyRoomSurpriseBuddyReward.coins) · \(store.dailyRoomSurpriseBuddyReward.stars)✦"){if store.claimDailyRoomSurpriseBuddy(){done("\(store.dailyRoomSurpriseBuddyEventTitle) complete! +\(store.dailyRoomSurpriseBuddyReward.coins) coins, +\(store.dailyRoomSurpriseBuddyReward.stars) star(s).")}}.disabled(!store.isDailyRoomSurpriseBuddyReady || store.isDailyRoomSurpriseBuddyClaimed)
  }
 }

 @ViewBuilder private var trophyGoals: some View {
  if store.unlockedTrophyDecorations.count >= 2 {
   QuestCard(icon: "sparkles", tint: Theme.sun, title: "Trophy Combo Moment", detail: "\(store.dailyTrophyComboTitle) · use both decorations today") {
    Button(store.isDailyTrophyComboClaimed ? "Claimed" : "Claim +35 ✦"){if store.claimDailyTrophyComboBonus(){done("Combo Moment complete! +35 coins, +1 star, +2 Fun.")}}.disabled(!store.isDailyTrophyComboReady || store.isDailyTrophyComboClaimed)
   }
  }
  if store.unlockedTrophyDecorations.count == 3 {
   QuestCard(icon: "trophy.fill", tint: Theme.sun, title: "Weekly Trophy Finale", detail: "Complete 3 Combo Moments this week · \(store.weeklyTrophyChainProgress)/3 · unlock Aurora Mobile") {
    Button(store.isWeeklyTrophyFinaleClaimed ? "Claimed" : "Claim +100 · 3✦"){if store.claimWeeklyTrophyFinale(){done("Weekly Trophy Finale! Aurora Mobile unlocked · +100 coins, +3 stars.")}}.disabled(!store.isWeeklyTrophyFinaleReady || store.isWeeklyTrophyFinaleClaimed)
   }
  }
  if store.isAuroraMobileUnlocked {
   QuestCard(icon: "wind", tint: Color(hex: 0x4FC9E0), title: "Aurora Shimmer Chain", detail: "Use Aurora on 3 different days this week · \(store.auroraWeeklyInteractionProgress)/3 · unlock Prism Charm") {
    Button(store.isAuroraWeeklyRewardClaimed ? "Claimed" : "Claim +60 · 2✦"){if store.claimAuroraWeeklyReward(){done("Prism Charm unlocked! +60 coins, +2 stars.")}}.disabled(!store.isAuroraWeeklyRewardReady || store.isAuroraWeeklyRewardClaimed)
   }
  }
  if store.isPrismCharmUnlocked {
   QuestCard(icon: "diamond.fill", tint: Theme.lavender, title: "Aurora + Prism Moment", detail: "Use Aurora Mobile and Prism Charm today · unlock a daily collection achievement") {
    Button(store.isAuroraPrismComboClaimed ? "Claimed" : "Claim +45 · 2✦"){if store.claimAuroraPrismCombo(){done("Aurora + Prism Moment complete! +45 coins, +2 stars.")}}.disabled(!store.isAuroraPrismComboReady || store.isAuroraPrismComboClaimed)
   }
   QuestCard(icon: "rainbow", tint: Theme.pink, title: "Radiant Collection · \(store.auroraPrismCollectionTier)", detail: "Aurora + Prism days: \(store.auroraPrismCollectionCount) total · \(store.weeklyAuroraPrismProgress)/3 this week · rewards at 3, 7 & 14") {
    VStack(spacing: 4) {
     Button(store.isStarlightSuncatcherUnlocked ? "3 ✓" : "3 · Claim"){if store.claimAuroraPrismSeriesReward(){done("Starlight Suncatcher unlocked!")}}.disabled(!store.isAuroraPrismSeriesRewardReady)
     Button(store.isMoonbeamTerrariumUnlocked ? "7 ✓" : "7 · Claim"){if store.claimMoonbeamTerrariumReward(){done("Moonbeam Terrarium unlocked!")}}.disabled(!store.isMoonbeamTerrariumRewardReady)
     Button(store.isCelestialLanternUnlocked ? "14 ✓" : "14 · Claim"){if store.claimCelestialLanternReward(){done("Celestial Lantern unlocked!")}}.disabled(!store.isCelestialLanternRewardReady)
    }
   }
  }
 }

 @ViewBuilder private var radiantGoals: some View {
  if store.isRadiantSetComplete {
   QuestCard(icon: "sun.haze.fill", tint: Theme.peach, title: "Radiant Room Event · \(min(store.isRadiantChimeUnlocked ? 4 : 3,store.radiantRoomEventStep))/\(store.isRadiantChimeUnlocked ? 4 : 3)", detail: "\(store.radiantRoomAtmosphere) · \(store.radiantRoomEventReaction)") {
    Button(store.isRadiantRoomEventClaimedToday ? "Today ✓" : "Claim"){if store.claimRadiantRoomEvent(){done(store.radiantRoomEventStep >= 4 ? "Chime Cascade! +120 coins · +4 stars" : "Radiant Room Event! +90 coins · +3 stars")}}.disabled(!store.isRadiantRoomEventReady).accessibilityLabel(store.isRadiantRoomEventClaimedToday ? "Radiant Room Event reward claimed today" : "Claim Radiant Room Event reward").accessibilityIdentifier("living.claimRadiantEvent")
   }
   QuestCard(icon: "bell.fill", tint: Theme.lavender, title: "Radiant Mastery · \(store.radiantRoomEventMasteryTier)", detail: "Completed: \(store.radiantRoomEventAchievementCount) · Chime at 5 · Lumen Canopy at 10") {
    VStack(spacing: 4) {
     Button(store.isRadiantChimeUnlocked ? "Chime ✓" : "Claim Chime"){if store.claimRadiantChimeReward(){done("Radiant Chime unlocked! +140 coins · +5 stars")}}.disabled(!store.isRadiantChimeRewardReady).accessibilityLabel(store.isRadiantChimeUnlocked ? "Radiant Chime unlocked" : "Claim Radiant Chime").accessibilityIdentifier("living.claimRadiantChime")
     Button(store.isLumenCanopyUnlocked ? "Canopy ✓" : "Claim 10"){if store.claimLightkeeperReward(){done("Lumen Canopy unlocked! +220 coins · +7 stars")}}.disabled(!store.isLightkeeperRewardReady).accessibilityLabel(store.isLumenCanopyUnlocked ? "Lumen Canopy unlocked" : "Claim Lumen Canopy").accessibilityIdentifier("living.claimLumenCanopy")
    }
   }
   QuestCard(icon: "star.circle.fill", tint: Theme.sun, title: "Radiant Set Bonus", detail: "Complete 3-piece collection · +250 coins · +8 stars") {
    Button(store.isRadiantSetBonusClaimed ? "Claimed" : "Claim"){if store.claimRadiantSetBonus(){done("Radiant Set complete! +250 coins, +8 stars.")}}.disabled(store.isRadiantSetBonusClaimed)
   }
  }
 }

 @ViewBuilder private var lightkeeperGoals: some View {
  if store.isLumenCanopyUnlocked {
   QuestCard(icon: "moon.stars.fill", tint: Color(hex: 0x6E63C9), title: "Lightkeeper Weekly · \(store.weeklyLightkeeperProgress)/3", detail: "Ring Radiant Chime, then visit Lumen Canopy on 3 different days · +180 coins · +6 stars") {
    Button(store.isWeeklyLightkeeperRewardClaimed ? "Week ✓" : "Claim"){if store.claimWeeklyLightkeeperReward(){done("Lightkeeper week complete! +180 coins · +6 stars")}}.disabled(!store.isWeeklyLightkeeperRewardReady).accessibilityLabel(store.isWeeklyLightkeeperRewardClaimed ? "Lightkeeper weekly reward claimed" : "Claim Lightkeeper weekly reward").accessibilityIdentifier("living.claimLightkeeperWeekly")
   }
   QuestCard(icon: "flame.fill", tint: Theme.peach, title: "Lightkeeper Streak · \(store.lightkeeperWeeklyStreak) week\(store.hasLightkeeperStreakCrown ? " · Crown ✓" : "")", detail: "2 weeks: +125 coins · 4✦ · 4 weeks: +300 coins · 10✦ + Starlight Crown") {
    VStack(spacing: 4) {
     Button(store.isLightkeeperStreak2Claimed ? "2W ✓" : "Claim 2W"){if store.claimLightkeeperStreak2Reward(){done("2-week Lightkeeper streak! +125 coins · +4 stars")}}.disabled(!store.isLightkeeperStreak2Ready).accessibilityLabel(store.isLightkeeperStreak2Claimed ? "Two-week Lightkeeper reward claimed" : "Claim two-week Lightkeeper reward").accessibilityIdentifier("living.claimLightkeeperStreak2")
     Button(store.isLightkeeperStreak4Claimed ? "4W ✓" : "Claim 4W"){if store.claimLightkeeperStreak4Reward(){done("4-week streak! Starlight Crown earned · +300 coins · +10 stars")}}.disabled(!store.isLightkeeperStreak4Ready).accessibilityLabel(store.isLightkeeperStreak4Claimed ? "Four-week Lightkeeper reward claimed" : "Claim four-week Lightkeeper reward").accessibilityIdentifier("living.claimLightkeeperStreak4")
    }
   }
  }
 }

 @ViewBuilder private var crownGoals: some View {
  if store.hasLightkeeperStreakCrown {
   QuestCard(icon: "crown.fill", tint: Theme.sun, title: "Crown Spark Weekly · \(store.weeklyCrownSparkProgress)/3", detail: "Wear Starlight Crown and visit Lumen Canopy on 3 different days this week · +150 coins · 5✦") {
    Button(store.isWeeklyCrownSparkClaimed ? "Week ✓" : "Claim"){if store.claimWeeklyCrownSparkReward(){done("Crown Spark week complete! +150 coins · +5 stars")}}.disabled(!store.isWeeklyCrownSparkReady).accessibilityLabel(store.isWeeklyCrownSparkClaimed ? "Crown Spark weekly reward claimed" : "Claim Crown Spark weekly reward").accessibilityIdentifier("living.claimCrownSparkWeekly")
   }
   QuestCard(icon: "sparkle", tint: Color(hex: 0x4FC9E0), title: "Crown Spark Collection · \(store.crownSparkWeeklyCollectionTier)", detail: "Claimed weeks: \(store.crownSparkWeeksCollected)/3 · Comet Halo decoration at 3 weeks · +110 coins · 4✦") {
    Button(store.isCometHaloUnlocked ? "Halo ✓" : "Claim Halo"){if store.claimCometHaloReward(){done("Comet Halo unlocked! +110 coins · +4 stars")}}.disabled(!store.isCometHaloRewardReady).accessibilityLabel(store.isCometHaloUnlocked ? "Comet Halo unlocked" : "Claim Comet Halo decoration").accessibilityIdentifier("living.claimCometHalo")
   }
   QuestCard(icon: "shield.lefthalf.filled", tint: Theme.lavender, title: "Starlight Guardian · \(store.crownCanopyCollectionTitle)", detail: "Crown Spark days: \(store.crownCanopyAchievementCount)/7 · unlock Comet Veil at 7 · +160 coins · 5✦") {
    Button(store.isCometVeilUnlocked ? "Veil ✓" : "Claim"){if store.claimCometVeilReward(){done("Comet Veil unlocked! +160 coins · +5 stars")}}.disabled(!store.isCometVeilRewardReady).accessibilityLabel(store.isCometVeilUnlocked ? "Comet Veil unlocked" : "Claim Comet Veil accessory").accessibilityIdentifier("living.claimCometVeil")
   }
  }
 }

 @ViewBuilder private var keepsakeGoals: some View {
  if !store.ownedFriendKeepsakes.isEmpty {
   QuestCard(icon: "heart.fill", tint: Theme.pink, title: "Daily Memory Spark", detail: "Visit 2 different keepsakes · \(store.dailyKeepsakeMemoryProgress)/2") {
    Button(store.isDailyKeepsakeMemoryClaimed ? "Claimed" : "Claim +40 ✦"){if store.claimDailyKeepsakeMemory(){done("Daily Memory Spark complete! +40 coins, +1 star.")}}.disabled(store.dailyKeepsakeMemoryProgress < 2 || store.isDailyKeepsakeMemoryClaimed)
   }
  }
  if let spotlight=store.dailyMemorySpotlightKeepsake {
   QuestCard(icon: "camera.filters", tint: Theme.peach, title: "Memory Spotlight", detail: "Today: \(spotlight.name) · \(store.isDailyMemorySpotlightReady ? "visited" : "tap it in its room")") {
    Button(store.isDailyMemorySpotlightClaimed ? "Claimed" : "Claim +20"){if store.claimDailyMemorySpotlight(){done("Memory Spotlight complete! +20 coins.")}}.disabled(!store.isDailyMemorySpotlightReady || store.isDailyMemorySpotlightClaimed)
   }
  }
  if store.dailyMemorySpotlightFriend != nil && store.dailyMemorySpotlightKeepsake != nil {
   QuestCard(icon: "person.2.wave.2.fill", tint: Theme.mint, title: "Spotlight Friend Moment", detail: store.dailySpotlightFriendChallengeDetail) {
    Button(store.isDailySpotlightFriendMomentClaimed ? "Claimed" : "Claim +30 ✦"){if store.claimDailySpotlightFriendMoment(){done("Friend Moment complete! +30 coins, +1 star.")}}.disabled(!store.isDailySpotlightFriendMomentReady || store.isDailySpotlightFriendMomentClaimed)
   }
  }
 }
}
