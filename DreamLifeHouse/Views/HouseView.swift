import SwiftUI

// v2.56: the House screen was one ~6,000-character SwiftUI expression (which
// Xcode cannot type-check in reasonable time) and mixed Color/Material in a
// ternary (a compile error). It is now split into small views and redrawn as
// an illustrated room. Gameplay calls and accessibility identifiers are unchanged.
struct HouseView: View {
 @EnvironmentObject var store:GameStore; @State private var roomID="living"; @State private var activeSlot="main"; @State private var message=loc("Choose a room and make it yours.", "Bir oda seç ve onu kendine göre süsle.")
 @State private var pendingPurchase: RoomItem?
 @State private var pendingFurniture: FurnitureItem?
 @State private var speech: String?
 @State private var speechToken = 0
 @State private var showFarm = false
 var room:HouseRoom { store.rooms.first{$0.id==roomID} ?? store.rooms[0] }
 var interaction:(String,String,String) { switch roomID {case "bedroom":return("sleep",loc("Rest", "Dinlen"),"bed.double.fill");case "kitchen":return("snack",loc("Have Snack", "Atıştır"),"fork.knife");case "bathroom":return("shower",loc("Take Shower", "Duş Al"),"shower.fill");case "garden":return("play",loc("Play Outside", "Dışarıda Oyna"),"leaf.fill");default:return("dance",loc("Dance", "Dans Et"),"music.note")} }
 func contextMessage(_ action:String)->String { switch action {case "sleep":return loc("Bedtime! Energy restored.", "Uyku vakti! Enerji yenilendi.");case "dance":return loc("Dance zone! Fun increased.", "Dans pisti! Eğlence arttı.");case "snack":return loc("Kitchen stop! Hunger restored.", "Mutfak molası! Karnın doydu.");case "shower":return loc("Shower time! Cleanliness restored.", "Duş vakti! Tertemiz oldun.");case "play":return loc("Outdoor play! Fun increased.", "Dışarıda oyun! Eğlence arttı.");default:return loc("Activity complete!", "Etkinlik tamamlandı!")} }
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
            if store.interactWithRadiantChime(in:roomID) { message=loc("Radiant Chime rang! Visit Lumen Canopy next · Fun +2 · Energy +3", "Işıltı Çanı çaldı! Sırada Işık Gölgeliği var · Eğlence +2 · Enerji +3") }
          } label: { Label(loc("Ring Radiant Chime", "Işıltı Çanını Çal"),systemImage:"bell.fill") }
          .accessibilityIdentifier("living.radiantChime")
          .accessibilityHint(loc("Ring the chime, then visit Lumen Canopy to advance the Lightkeeper challenge.", "Önce çanı çal, sonra Işık Bekçisi görevi için Işık Gölgeliği\'ni ziyaret et."))
        }
        if store.isLumenCanopyUnlocked {
          Button {
            let newCrownSpark = store.isStarlightCrownEquipped && !store.isCrownCanopyMomentClaimedToday
            let newLightkeeper = store.isLightkeeperMomentReady
            if store.interactWithLumenCanopy(in:roomID) {
              message = newCrownSpark ? loc("Crown Spark earned! +35 coins · +1 star", "Taç Kıvılcımı kazanıldı! +35 jeton · +1 yıldız") :
                        newLightkeeper ? loc("Lightkeeper moment recorded!", "Işık Bekçisi anı kaydedildi!") : loc("Lumen Canopy glows! Fun +3 · Energy +4", "Işık Gölgeliği parlıyor! Eğlence +3 · Enerji +4")
            }
          } label: { Label(loc("Visit Lumen Canopy", "Işık Gölgeliğine Git"),systemImage:"moon.stars.fill") }
          .accessibilityIdentifier("living.lumenCanopy")
          .accessibilityHint(loc("Visit after ringing Radiant Chime. Wear Starlight Crown for a daily Crown Spark.", "Işıltı Çanı\'nı çaldıktan sonra git. Günlük Taç Kıvılcımı için Yıldız Işığı Tacı\'nı tak."))
        }
        if store.isCometHaloUnlocked {
          Button {
            if store.interactWithCometHalo(in:roomID) { message=loc("Comet Halo glimmers! Fun +2 · Energy +2", "Kuyruklu Yıldız Halesi parıldıyor! Eğlence +2 · Enerji +2") }
          } label: { Label(loc("Admire Comet Halo", "Kuyruklu Yıldız Halesine Bak"),systemImage:"sparkle") }
          .accessibilityIdentifier("living.cometHalo")
          .accessibilityHint(loc("Admire your earned decoration to increase Fun and Energy.", "Eğlence ve Enerji için kazandığın dekorasyona bak."))
        }
      }.buttonStyle(PillButtonStyle(color: Theme.lavender)).padding(.horizontal).padding(.vertical,4)
    }
  }
 }

 @Environment(\.horizontalSizeClass) private var hSize
 @Environment(\.verticalSizeClass) private var vSize
 /// Phone in landscape, or iPad: room on the left, controls on the right.
 private var wide: Bool { vSize == .compact || hSize == .regular }

 var body: some View {
  NavigationStack {
   Group {
    if wide { wideLayout } else { tallLayout }
   }
   .background(AppBackground())
   .toolbar(.hidden, for: .navigationBar)
   .confirmationDialog(pendingPurchase.map { loc("Buy \($0.name)?", "\(trName($0.name)) alınsın mı?") } ?? loc("Buy decoration?", "Dekorasyon alınsın mı?"),
                       isPresented: Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } }),
                       titleVisibility: .visible, presenting: pendingPurchase) { item in
    Button(loc("Buy for \(item.cost) coins", "\(item.cost) jetona al")) { place(item) }
    Button(loc("Not now", "Şimdi değil"), role: .cancel) { }
   } message: { item in
    Text(loc("\(item.name) costs \(item.cost) coins. You have \(store.coins) coins.", "\(trName(item.name)) \(item.cost) jeton. Sende \(store.coins) jeton var."))
   }
  }
 }

 // MARK: Layouts

 private var tallLayout: some View {
  ScrollView(.vertical) {
   VStack(spacing: 14) {
    TopBar()
    RoutineLauncherCard()
    roomPicker
    needsPanel
    RoomStage(roomID: roomID, activeSlot: $activeSlot, message: $message, onDrop: { contextMessage($0) }, speech: speech, onFurnitureTap: { announce($0) })
     .padding(.horizontal)
    actionRow
    feedback
    radiantDecorationControls
    if roomID == "garden" { gardenActions }
    if roomID == "living" { LivingRoomCollection(message: $message) }
    furnitureShop
    decorShop
    HouseGoals(message: $message)
   }
   .padding(.bottom, 28)
  }
 }

 private var wideLayout: some View {
  VStack(spacing: 6) {
   TopBar()
   GeometryReader { geo in
    HStack(alignment: .top, spacing: 4) {
     VStack(spacing: 8) {
      RoomStage(roomID: roomID, activeSlot: $activeSlot, message: $message, onDrop: { contextMessage($0) }, speech: speech, onFurnitureTap: { announce($0) }, stageHeight: nil)
       .frame(minHeight: 200)
       .padding(.leading)
      actionRow
     }
     .frame(maxWidth: .infinity, maxHeight: .infinity)
     .padding(.bottom, 8)
     ScrollView(.vertical) {
      VStack(spacing: 14) {
       RoutineLauncherCard()
       roomPicker
       needsPanel
       feedback
       radiantDecorationControls
       if roomID == "garden" { gardenActions }
       if roomID == "living" { LivingRoomCollection(message: $message) }
       furnitureShop
       decorShop
       HouseGoals(message: $message)
      }
      .padding(.vertical, 6)
      .padding(.bottom, 24)
     }
     .frame(width: min(480, geo.size.width * 0.46))
    }
   }
  }
 }

 private var feedback: some View {
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
 }

 // MARK: Room picker & needs

 private var roomPicker: some View {
  ScrollView(.horizontal, showsIndicators: false) {
   HStack(spacing: 10) {
    ForEach(store.rooms) { r in
     Button {
      roomID = r.id; message = loc("Welcome to the \(r.name)!", "Hoş geldin: \(trName(r.name))!")
      Feedback.play(.tap, settings: store.playerSettings)
     } label: {
      VStack(spacing: 4) {
       Image(systemName: r.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.roomTint(r.id))
       Text(trName(r.name)).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.8)
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
   NeedMeter(name: loc("Energy", "Enerji"), icon: "bolt.fill", value: store.characterNeeds.energy, tint: Theme.sun)
   NeedMeter(name: loc("Fun", "Eğlence"), icon: "face.smiling.inverse", value: store.characterNeeds.fun, tint: Theme.pink)
   NeedMeter(name: loc("Clean", "Temizlik"), icon: "drop.fill", value: store.characterNeeds.hygiene, tint: Theme.sky)
   NeedMeter(name: loc("Food", "Tokluk"), icon: "fork.knife", value: store.characterNeeds.hunger, tint: Theme.mint)
  }
  .padding(12)
  .dreamCard(cornerRadius: 20)
  .padding(.horizontal)
 }

 private var actionRow: some View {
  HStack(spacing: 10) {
   Button {
    if store.performInteraction(interaction.0, in: roomID) {
     message = loc("\(interaction.1) completed!", "\(interaction.1) tamamlandı!")
     Feedback.play(.success, settings: store.playerSettings)
    }
   } label: {
    Label(interaction.1, systemImage: interaction.2)
   }
   .buttonStyle(CandyButtonStyle(color: Theme.roomTint(roomID)))
   Text(trName(room.name))
    .font(.headline.weight(.heavy))
    .foregroundStyle(Theme.ink)
    .lineLimit(1).minimumScaleFactor(0.7)
  }
  .padding(.horizontal)
 }

 private var gardenActions: some View {
  HStack(spacing: 10) {
   GardenAction(title: loc("Swim", "Yüz"), icon: "figure.pool.swim", tint: Theme.sky) {
    if store.performGardenActivity("swim") { message = loc("Pool time! Fun increased.", "Havuz vakti! Eğlence arttı."); Feedback.play(.success, settings: store.playerSettings) }
   }
   GardenAction(title: loc("Lounge", "Güneşlen"), icon: "sun.max.fill", tint: Theme.sun) {
    if store.performGardenActivity("lounge") { message = loc("Relaxed by the pool.", "Havuz başında dinlendin."); Feedback.play(.success, settings: store.playerSettings) }
   }
   GardenAction(title: loc("Farm", "Çiftlik"), icon: "carrot.fill", tint: Theme.mint) {
    showFarm = true
    Feedback.play(.tap, settings: store.playerSettings)
   }
   .accessibilityIdentifier("garden.farm")
   GardenAction(title: loc("Pet Play", "Evcil Oyun"), icon: "pawprint.fill", tint: Theme.peach) {
    if store.performGardenActivity("petPlay") { message = loc("Garden play together!", "Bahçede birlikte oyun!"); Feedback.play(.success, settings: store.playerSettings) }
    else { message = loc("Bring your pet to the Garden first (Play › Pet).", "Önce evcil hayvanını Bahçe\'ye getir (Oyna › Evcil Hayvan).") }
   }
  }
  .padding(.horizontal)
  .fullScreenCover(isPresented: $showFarm) { GardenFarmView(standalone: true).environmentObject(store) }
 }

 // MARK: Room furniture

 private var furnitureShop: some View {
  VStack(alignment: .leading, spacing: 10) {
   SectionTitle(title: loc("Room furniture", "Oda Eşyaları"), icon: "house.lodge.fill")
    .padding(.horizontal)
   Text(loc("Tap to add. Your character says each new thing in Turkish and English!", "Eklemek için dokun. Karakterin her yeni eşyayı Türkçe ve İngilizce söyler!"))
    .font(.caption).foregroundStyle(Theme.inkSoft)
    .padding(.horizontal)
   ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {
     ForEach(store.furniture(in: roomID)) { item in
      let owned = store.ownsFurniture(item)
      let placed = store.isFurniturePlaced(item)
      Button { tapFurniture(item) } label: {
       VStack(spacing: 6) {
        FurnitureArt(item: item, size: 30)
         .frame(height: 40)
        Text(loc(item.name, item.nameTR)).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
        if owned {
         Text(placed ? loc("In room ✓", "Odada ✓") : loc("Put back", "Geri koy"))
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
      .accessibilityIdentifier("house.furniture.\(item.id)")
      .accessibilityLabel(owned ? loc("\(item.name), \(placed ? "in the room" : "stored")", "\(item.nameTR), \(placed ? "odada" : "kaldırıldı")") : loc("\(item.name), \(item.cost) coins", "\(item.nameTR), \(item.cost) jeton"))
      .accessibilityHint(placed ? loc("Takes it out of the room.", "Odadan kaldırır.") : loc("Puts it in the room.", "Odaya koyar."))
     }
    }
    .padding(.horizontal).padding(.vertical, 4)
   }
  }
  .confirmationDialog(pendingFurniture.map { loc("Buy \($0.name)?", "\($0.nameTR) alınsın mı?") } ?? loc("Buy furniture?", "Eşya alınsın mı?"),
                      isPresented: Binding(get: { pendingFurniture != nil }, set: { if !$0 { pendingFurniture = nil } }),
                      titleVisibility: .visible, presenting: pendingFurniture) { item in
   Button(loc("Buy for \(item.cost) coins", "\(item.cost) jetona al")) { placeFurniture(item) }
   Button(loc("Not now", "Şimdi değil"), role: .cancel) { }
  } message: { item in
   Text(loc("\(item.name) costs \(item.cost) coins. You have \(store.coins) coins.", "\(item.nameTR) \(item.cost) jeton. Sende \(store.coins) jeton var."))
  }
 }

 private func tapFurniture(_ item: FurnitureItem) {
  if store.isFurniturePlaced(item) {
   if store.storeFurniture(item) {
    message = loc("\(item.name) put away.", "\(item.nameTR) kaldırıldı.")
    Feedback.play(.tap, settings: store.playerSettings)
   }
   return
  }
  if store.ownsFurniture(item) { placeFurniture(item); return }
  guard store.coins >= item.cost else {
   message = loc("You need \(item.cost - store.coins) more coins for the \(item.name).", "\(item.nameTR) için \(item.cost - store.coins) jeton daha gerekiyor.")
   Feedback.play(.warning, settings: store.playerSettings)
   return
  }
  if store.playerSettings.purchaseConfirmation && item.cost > 0 { pendingFurniture = item } else { placeFurniture(item) }
 }

 private func placeFurniture(_ item: FurnitureItem) {
  let wasOwned = store.ownsFurniture(item)
  if store.placeFurniture(item) {
   message = loc("\(item.name) added to the \(room.name)!", "\(item.nameTR) eklendi: \(trName(room.name))!")
   Feedback.play(wasOwned ? .tap : .purchase, settings: store.playerSettings)
   announce(item)
  } else {
   message = loc("You need more coins.", "Daha fazla jeton gerekiyor.")
   Feedback.play(.warning, settings: store.playerSettings)
  }
 }

 /// The character says the item's name in both languages, with a speech bubble.
 private func announce(_ item: FurnitureItem) {
  let tr = "\(item.nameTR)!", en = L10n.english(item.name)
  withAnimation(store.motionAnimationDuration == 0 ? nil : .spring(duration: 0.3)) {
   speech = L10n.isTurkish ? "\(tr)  \(en)" : "\(en)  \(tr)"
  }
  Speaker.shared.sayBoth(turkish: item.nameTR, english: item.name, settings: store.playerSettings)
  speechToken += 1
  let token = speechToken
  Task { @MainActor in
   try? await Task.sleep(for: .seconds(3))
   if token == speechToken { withAnimation { speech = nil } }
  }
 }

 // MARK: Decor shop

 private func placedItem(_ slot: String) -> RoomItem? {
  let id = store.selectedItemsByRoomSlot[roomID]?[slot] ?? (slot == "main" ? store.selectedItemsByRoom[roomID] : nil)
  return store.roomItems.first { $0.id == id }
 }

 private var decorShop: some View {
  VStack(alignment: .leading, spacing: 10) {
   HStack {
    SectionTitle(title: loc("Decorate", "Dekore Et"), icon: "paintbrush.pointed.fill")
    Picker(loc("Slot", "Yer"), selection: $activeSlot) {
     Text(loc("Main spot", "Ana yer")).tag("main")
     Text(loc("Side spot", "Yan yer")).tag("side")
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
        Text(trName(item.name)).font(.caption.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.8)
        if owned {
         Text(placed ? loc("Placed ✓", "Yerleşti ✓") : loc("Owned", "Sende var"))
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
      .accessibilityLabel(owned ? loc("\(item.name), \(placed ? "placed" : "owned")", "\(trName(item.name)), \(placed ? "yerleşti" : "sende var")") : loc("\(item.name), \(item.cost) coins", "\(trName(item.name)), \(item.cost) jeton"))
      .accessibilityHint(loc("Places it in the \(activeSlot == "main" ? "main" : "side") spot of the \(room.name).", "\(trName(room.name)) odasında \(activeSlot == "main" ? "ana" : "yan") yere yerleştirir."))
     }
    }
    .padding(.horizontal).padding(.vertical, 4)
   }
  }
 }

 private func buy(_ item: RoomItem) {
  if store.ownsRoomItem(item) { place(item); return }
  guard store.coins >= item.cost else {
   message = loc("You need \(item.cost - store.coins) more coins for \(item.name).", "\(trName(item.name)) için \(item.cost - store.coins) jeton daha gerekiyor.")
   Feedback.play(.warning, settings: store.playerSettings)
   return
  }
  if store.playerSettings.purchaseConfirmation && item.cost > 0 { pendingPurchase = item } else { place(item) }
 }

 private func place(_ item: RoomItem) {
  let wasOwned = store.ownsRoomItem(item)
  if store.selectRoomItem(item, in: roomID, slot: activeSlot) {
   message = loc("\(item.name) placed in \(room.name)!", "\(trName(item.name)) yerleştirildi: \(trName(room.name))!")
   Feedback.play(wasOwned ? .tap : .purchase, settings: store.playerSettings)
  } else {
   message = loc("You need more coins.", "Daha fazla jeton gerekiyor.")
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
 var speech: String? = nil
 var onFurnitureTap: (FurnitureItem) -> Void = { _ in }
 var stageHeight: CGFloat? = 320
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
    furnitureLayer(w: w, h: h)
    actionZone(w: w, h: h)
    decorSlot("main", at: layout.mainDecor, w: w, h: h)
    decorSlot("side", at: layout.sideDecor, w: w, h: h)
    keepsakeShelf
    if store.petProfile.roomID == roomID {
     PetPortrait(species: store.petProfile.species, size: 54)
      .position(x: w * layout.petSpot.x, y: h * layout.petSpot.y)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(loc("\(store.petProfile.name) the \(store.petProfile.species) is here", "\(store.petProfile.name) (\(trName(store.petProfile.species))) burada"))
    }
    if let friend = store.activeFriend, store.socialProgress.friendRoomID == roomID {
     VStack(spacing: 0) {
      AvatarView(look: FriendLooks.look(for: friend.id), size: 62)
      NameTag(text: friend.name, tint: Theme.lavender)
     }
     .position(x: w * layout.friendSpot.x, y: h * layout.friendSpot.y)
     .accessibilityElement(children: .ignore)
     .accessibilityLabel(loc("\(friend.name) is visiting", "\(friend.name) ziyarette"))
    }
    player(w: w, h: h)
   }
  }
  .frame(height: stageHeight)
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
   message = loc("\(slot == "main" ? "Main" : "Side") spot selected. Pick a decoration below.", "\(slot == "main" ? "Ana" : "Yan") yer seçildi. Aşağıdan bir dekorasyon seç.")
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
    Text(slot == "main" ? loc("Main", "Ana") : loc("Side", "Yan"))
     .font(.system(size: 9, weight: .heavy, design: .rounded))
     .foregroundStyle(selected ? Color.white : Theme.ink)
     .padding(.horizontal, 6).padding(.vertical, 1)
     .background(Capsule().fill(selected ? Theme.pink : Color.white.opacity(0.8)))
   }
  }
  .buttonStyle(.plain)
  .position(x: w * point.x, y: h * point.y)
  .accessibilityLabel(loc("\(slot == "main" ? "Main" : "Side") decoration spot: \(item?.name ?? "empty")", "\(slot == "main" ? "Ana" : "Yan") dekorasyon yeri: \(item.map { trName($0.name) } ?? "boş")"))
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
        message = loc("A sweet memory with \(store.friends.first(where: { $0.id == keepsake.friendID })?.name ?? "a friend")!", "\(store.friends.first(where: { $0.id == keepsake.friendID })?.name ?? "Bir arkadaş") ile tatlı bir anı!")
        Feedback.play(.tap, settings: store.playerSettings)
       }
      } label: {
       VStack(spacing: 1) {
        Image(systemName: keepsake.icon).font(.system(size: 18)).foregroundStyle(Theme.pink.gradient)
        Text(trName(keepsake.name)).font(.system(size: 7, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
         .foregroundStyle(Theme.ink)
       }
       .frame(width: 54, height: 40)
       .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.88)))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(loc("Keepsake: \(keepsake.name)", "Hatıra: \(trName(keepsake.name))"))
     }
    }
    .padding(.top, 10)
    Spacer()
   }
  }
 }

 // Placed furniture. Tapping a piece makes the character say its name again.
 private func furnitureLayer(w: CGFloat, h: CGFloat) -> some View {
  ZStack {
   ForEach(store.placedFurniture(in: roomID)) { item in
    let spot = FurnitureSpots.spot(for: item.id)
    Button { onFurnitureTap(item) } label: {
     FurnitureArt(item: item, size: h * spot.size)
    }
    .buttonStyle(.plain)
    .position(x: w * spot.point.x, y: h * spot.point.y)
    .transition(.scale(scale: 0.3).combined(with: .opacity))
    .accessibilityLabel(loc(item.name, item.nameTR))
    .accessibilityHint(loc("Hear its name in Turkish and English.", "Adını Türkçe ve İngilizce dinle."))
    .accessibilityIdentifier("room.furniture.\(item.id)")
   }
  }
  .animation(store.motionAnimationDuration == 0 ? nil : .spring(duration: 0.4, bounce: 0.45), value: store.placedFurnitureIDs)
 }

 private func player(w: CGFloat, h: CGFloat) -> some View {
  let pos = store.characterPosition(in: roomID)
  let look = AvatarLook(profile: store.characterProfile, outfitID: store.selectedOutfitID)
  return VStack(spacing: 0) {
   AvatarView(look: look, size: 78)
   NameTag(text: store.characterProfile.name, tint: Theme.pink)
  }
  .overlay(alignment: .top) {
   if let speech {
    SpeechBubble(text: speech)
     .fixedSize()
     .offset(y: -34)
     .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
   }
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
      message = loc("Moved to a new spot.", "Yeni bir yere geçtin.")
     }
    }
  )
  .accessibilityElement(children: .ignore)
  .accessibilityLabel(loc("\(store.characterProfile.name), your character", "\(store.characterProfile.name), karakterin"))
  .accessibilityHint(loc("Drag to move around the room. Drop on the dotted area to do the room activity.", "Odada gezinmek için sürükle. Oda etkinliği için noktalı alana bırak."))
 }
}

private struct SpeechBubble: View {
 @EnvironmentObject var store: GameStore
 let text: String
 var body: some View {
  VStack(spacing: 0) {
   Text(text)
    .font(.system(size: 13, weight: .black, design: .rounded))
    .foregroundStyle(Theme.ink)
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(Capsule().fill(Color.white))
    .overlay(Capsule().strokeBorder(Theme.pink.opacity(0.6), lineWidth: 2))
   TriangleShape()
    .fill(Color.white)
    .frame(width: 12, height: 7)
    .rotationEffect(.degrees(180))
  }
  .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
  .accessibilityElement(children: .ignore)
  .accessibilityLabel(text)
  .onTapGesture { Speaker.shared.repeatLast(settings: store.playerSettings) }
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
    SectionTitle(title: loc("My Collection", "Koleksiyonum"), icon: "sparkles").padding(.horizontal)
    ScrollView(.horizontal, showsIndicators: false) {
     HStack(spacing: 10) {
      if store.isDreamHouseTrophyUnlocked {
       CollectibleTile(icon: "trophy.fill", title: loc("Dream House Trophy", "Rüya Ev Kupası"), subtitle: trName(store.dreamHouseTrophyLevel), tint: Theme.sun) {
        if store.interactWithDreamHouseTrophy(in: "living") { message = loc("Dream House Trophy admired! Fun +4 · visits: \(store.dreamHouseTrophyVisitCount)", "Rüya Ev Kupası\'na baktın! Eğlence +4 · ziyaret: \(store.dreamHouseTrophyVisitCount)") }
       }
      }
      if store.isAuroraMobileUnlocked {
       CollectibleTile(icon: "wind", title: loc("Aurora Mobile", "Aurora Mobili"), subtitle: loc("Shimmer", "Parıltı"), tint: Color(hex: 0x4FC9E0)) {
        if store.interactWithAuroraMobile(in: "living") {
         let fresh = store.recordAuroraDailyInteraction()
         message = fresh ? loc("Aurora Mobile shimmered! \(store.auroraCharacterReaction)", "Aurora Mobili parıldadı! \(trName(store.auroraCharacterReaction))") : loc("Aurora Mobile shimmered again! Energy +2 · Fun +2", "Aurora Mobili yine parıldadı! Enerji +2 · Eğlence +2")
        }
       }
      }
      if store.isPrismCharmUnlocked {
       CollectibleTile(icon: "diamond.fill", title: loc("Prism Charm", "Prizma Tılsımı"), subtitle: loc("Visits \(store.prismCharmVisitCount)", "Ziyaret \(store.prismCharmVisitCount)"), tint: Theme.lavender) {
        if store.interactWithPrismCharm(in: "living") { message = loc("Prism Charm glowed! Fun +2 · visits: \(store.prismCharmVisitCount)", "Prizma Tılsımı parladı! Eğlence +2 · ziyaret: \(store.prismCharmVisitCount)") }
       }
      }
      if store.isStarlightSuncatcherUnlocked {
       CollectibleTile(icon: "sun.max.fill", title: loc("Starlight Suncatcher", "Yıldız Işığı Güneş Yakalayıcı"), subtitle: loc("Step 1", "Adım 1"), tint: Theme.sun) {
        if store.interactWithStarlightSuncatcher(in: "living") { message = loc("Starlight Suncatcher shimmered! Fun +3 · Energy +2", "Güneş Yakalayıcı parıldadı! Eğlence +3 · Enerji +2") }
       }
      }
      if store.isMoonbeamTerrariumUnlocked {
       CollectibleTile(icon: "leaf.fill", title: loc("Moonbeam Terrarium", "Ay Işını Teraryumu"), subtitle: loc("Step 2", "Adım 2"), tint: Theme.mint) {
        if store.interactWithMoonbeamTerrarium(in: "living") { message = loc("Moonbeam Terrarium glowed! Energy +3", "Ay Işını Teraryumu parladı! Enerji +3") }
       }
      }
      if store.isCelestialLanternUnlocked {
       CollectibleTile(icon: "lamp.table.fill", title: loc("Celestial Lantern", "Gök Feneri"), subtitle: loc("Step 3", "Adım 3"), tint: Theme.peach) {
        if store.interactWithCelestialLantern(in: "living") { message = loc("Celestial Lantern twinkled! Fun +4", "Gök Feneri ışıldadı! Eğlence +4") }
       }
      }
      ForEach(store.unlockedTrophyDecorations, id: \.self) { name in
       CollectibleTile(icon: store.trophyDecorationIcons[name] ?? "sparkles", title: trName(name),
                       subtitle: loc("Visits \(store.trophyDecorationVisitCount(name))", "Ziyaret \(store.trophyDecorationVisitCount(name))"), tint: Theme.pink) {
        if store.interactWithTrophyDecoration(name, in: "living") { message = loc("\(name) sparkled! Visits: \(store.trophyDecorationVisitCount(name))", "\(trName(name)) ışıldadı! Ziyaret: \(store.trophyDecorationVisitCount(name))") }
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
   SectionTitle(title: loc("Today's Goals", "Bugünün Görevleri"), icon: "checklist").padding(.horizontal)
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

 // Model sentences rebuilt here so they can be shown in Turkish.
 private var buddyDetail: String {
  let buddy = store.dailyRoomSurpriseBuddy
  return loc(store.dailyRoomSurpriseBuddyDetail,
             "\(trName(store.dailyRoomSurpriseBuddyEventTitle)): sürprizi bulduktan sonra \(buddy.name) ile buraya gel ve birlikte \(activityPhrase(buddy.favoriteActivity)).")
 }
 private var comboTitleTR: String {
  let pair = store.dailyTrophyComboDecorations
  guard pair.count == 2 else { return trName(store.dailyTrophyComboTitle) }
  return "\(trName(pair[0])) + \(trName(pair[1])) Kombo Anı"
 }
 private var spotlightDetail: String {
  guard let friend = store.dailyMemorySpotlightFriend, let action = store.dailySpotlightFriendChallengeAction else {
   return trName(store.dailySpotlightFriendChallengeDetail)
  }
  return loc(store.dailySpotlightFriendChallengeDetail,
             "Bugünün hatırasını ziyaret et, \(friend.name) ile onun odasına git ve birlikte \(activityPhrase(action)).")
 }

 private func done(_ text: String) { message = text; Feedback.play(.success, settings: store.playerSettings) }

 @ViewBuilder private var dailyGoals: some View {
  QuestCard(icon: "gift.fill", tint: Theme.pink, title: loc("Room Surprise", "Oda Sürprizi"),
            detail: loc("Today: \(store.dailyRoomSurpriseRoomName) · \(store.isDailyRoomSurpriseReady ? "discovered" : "try its special activity")", "Bugün: \(trName(store.dailyRoomSurpriseRoomName)) · \(store.isDailyRoomSurpriseReady ? "bulundu" : "o odanın etkinliğini yap")")) {
   Button(store.isDailyRoomSurpriseClaimed ? loc("Claimed", "Alındı") : loc("Claim +25 ✦", "Al +25 ✦")){if store.claimDailyRoomSurprise(){done(loc("Room Surprise found! +25 coins, +1 star.", "Oda Sürprizi bulundu! +25 jeton, +1 yıldız."))}}.disabled(!store.isDailyRoomSurpriseReady || store.isDailyRoomSurpriseClaimed)
  }
  QuestCard(icon: "person.2.fill", tint: Theme.lavender, title: loc("Surprise Buddy", "Sürpriz Arkadaş"), detail: buddyDetail) {
   Button(store.isDailyRoomSurpriseBuddyClaimed ? loc("Claimed", "Alındı") : loc("Claim +\(store.dailyRoomSurpriseBuddyReward.coins) · \(store.dailyRoomSurpriseBuddyReward.stars)✦", "Al +\(store.dailyRoomSurpriseBuddyReward.coins) · \(store.dailyRoomSurpriseBuddyReward.stars)✦")){if store.claimDailyRoomSurpriseBuddy(){done(loc("\(store.dailyRoomSurpriseBuddyEventTitle) complete! +\(store.dailyRoomSurpriseBuddyReward.coins) coins, +\(store.dailyRoomSurpriseBuddyReward.stars) star(s).", "\(trName(store.dailyRoomSurpriseBuddyEventTitle)) tamamlandı! +\(store.dailyRoomSurpriseBuddyReward.coins) jeton, +\(store.dailyRoomSurpriseBuddyReward.stars) yıldız."))}}.disabled(!store.isDailyRoomSurpriseBuddyReady || store.isDailyRoomSurpriseBuddyClaimed)
  }
 }

 @ViewBuilder private var trophyGoals: some View {
  if store.unlockedTrophyDecorations.count >= 2 {
   QuestCard(icon: "sparkles", tint: Theme.sun, title: loc("Trophy Combo Moment", "Kupa Kombo Anı"), detail: loc("\(store.dailyTrophyComboTitle) · use both decorations today", "\(comboTitleTR) · bugün iki dekorasyonu da kullan")) {
    Button(store.isDailyTrophyComboClaimed ? loc("Claimed", "Alındı") : loc("Claim +35 ✦", "Al +35 ✦")){if store.claimDailyTrophyComboBonus(){done(loc("Combo Moment complete! +35 coins, +1 star, +2 Fun.", "Kombo Anı tamamlandı! +35 jeton, +1 yıldız, +2 Eğlence."))}}.disabled(!store.isDailyTrophyComboReady || store.isDailyTrophyComboClaimed)
   }
  }
  if store.unlockedTrophyDecorations.count == 3 {
   QuestCard(icon: "trophy.fill", tint: Theme.sun, title: loc("Weekly Trophy Finale", "Haftalık Kupa Finali"), detail: loc("Complete 3 Combo Moments this week · \(store.weeklyTrophyChainProgress)/3 · unlock Aurora Mobile", "Bu hafta 3 Kombo Anı tamamla · \(store.weeklyTrophyChainProgress)/3 · Aurora Mobili\'ni aç")) {
    Button(store.isWeeklyTrophyFinaleClaimed ? loc("Claimed", "Alındı") : loc("Claim +100 · 3✦", "Al +100 · 3✦")){if store.claimWeeklyTrophyFinale(){done(loc("Weekly Trophy Finale! Aurora Mobile unlocked · +100 coins, +3 stars.", "Haftalık Kupa Finali! Aurora Mobili açıldı · +100 jeton, +3 yıldız."))}}.disabled(!store.isWeeklyTrophyFinaleReady || store.isWeeklyTrophyFinaleClaimed)
   }
  }
  if store.isAuroraMobileUnlocked {
   QuestCard(icon: "wind", tint: Color(hex: 0x4FC9E0), title: loc("Aurora Shimmer Chain", "Aurora Parıltı Zinciri"), detail: loc("Use Aurora on 3 different days this week · \(store.auroraWeeklyInteractionProgress)/3 · unlock Prism Charm", "Bu hafta 3 farklı gün Aurora\'yı kullan · \(store.auroraWeeklyInteractionProgress)/3 · Prizma Tılsımı\'nı aç")) {
    Button(store.isAuroraWeeklyRewardClaimed ? loc("Claimed", "Alındı") : loc("Claim +60 · 2✦", "Al +60 · 2✦")){if store.claimAuroraWeeklyReward(){done(loc("Prism Charm unlocked! +60 coins, +2 stars.", "Prizma Tılsımı açıldı! +60 jeton, +2 yıldız."))}}.disabled(!store.isAuroraWeeklyRewardReady || store.isAuroraWeeklyRewardClaimed)
   }
  }
  if store.isPrismCharmUnlocked {
   QuestCard(icon: "diamond.fill", tint: Theme.lavender, title: loc("Aurora + Prism Moment", "Aurora + Prizma Anı"), detail: loc("Use Aurora Mobile and Prism Charm today · unlock a daily collection achievement", "Bugün Aurora Mobili ve Prizma Tılsımı\'nı kullan · günlük koleksiyon başarısı kazan")) {
    Button(store.isAuroraPrismComboClaimed ? loc("Claimed", "Alındı") : loc("Claim +45 · 2✦", "Al +45 · 2✦")){if store.claimAuroraPrismCombo(){done(loc("Aurora + Prism Moment complete! +45 coins, +2 stars.", "Aurora + Prizma Anı tamamlandı! +45 jeton, +2 yıldız."))}}.disabled(!store.isAuroraPrismComboReady || store.isAuroraPrismComboClaimed)
   }
   QuestCard(icon: "rainbow", tint: Theme.pink, title: loc("Radiant Collection · \(store.auroraPrismCollectionTier)", "Işıltı Koleksiyonu · \(trName(store.auroraPrismCollectionTier))"), detail: loc("Aurora + Prism days: \(store.auroraPrismCollectionCount) total · \(store.weeklyAuroraPrismProgress)/3 this week · rewards at 3, 7 & 14", "Aurora + Prizma günleri: toplam \(store.auroraPrismCollectionCount) · bu hafta \(store.weeklyAuroraPrismProgress)/3 · ödüller 3, 7 ve 14\'te")) {
    VStack(spacing: 4) {
     Button(store.isStarlightSuncatcherUnlocked ? "3 ✓" : loc("3 · Claim", "3 · Al")){if store.claimAuroraPrismSeriesReward(){done(loc("Starlight Suncatcher unlocked!", "Güneş Yakalayıcı açıldı!"))}}.disabled(!store.isAuroraPrismSeriesRewardReady)
     Button(store.isMoonbeamTerrariumUnlocked ? "7 ✓" : loc("7 · Claim", "7 · Al")){if store.claimMoonbeamTerrariumReward(){done(loc("Moonbeam Terrarium unlocked!", "Ay Işını Teraryumu açıldı!"))}}.disabled(!store.isMoonbeamTerrariumRewardReady)
     Button(store.isCelestialLanternUnlocked ? "14 ✓" : loc("14 · Claim", "14 · Al")){if store.claimCelestialLanternReward(){done(loc("Celestial Lantern unlocked!", "Gök Feneri açıldı!"))}}.disabled(!store.isCelestialLanternRewardReady)
    }
   }
  }
 }

 @ViewBuilder private var radiantGoals: some View {
  if store.isRadiantSetComplete {
   QuestCard(icon: "sun.haze.fill", tint: Theme.peach, title: loc("Radiant Room Event · \(min(store.isRadiantChimeUnlocked ? 4 : 3,store.radiantRoomEventStep))/\(store.isRadiantChimeUnlocked ? 4 : 3)", "Işıltılı Oda Etkinliği · \(min(store.isRadiantChimeUnlocked ? 4 : 3,store.radiantRoomEventStep))/\(store.isRadiantChimeUnlocked ? 4 : 3)"), detail: loc("\(store.radiantRoomAtmosphere) · \(store.radiantRoomEventReaction)", "\(trName(store.radiantRoomAtmosphere)) · \(trName(store.radiantRoomEventReaction))")) {
    Button(store.isRadiantRoomEventClaimedToday ? loc("Today ✓", "Bugün ✓") : loc("Claim", "Al")){if store.claimRadiantRoomEvent(){done(store.radiantRoomEventStep >= 4 ? loc("Chime Cascade! +120 coins · +4 stars", "Çan Şelalesi! +120 jeton · +4 yıldız") : loc("Radiant Room Event! +90 coins · +3 stars", "Işıltılı Oda Etkinliği! +90 jeton · +3 yıldız"))}}.disabled(!store.isRadiantRoomEventReady).accessibilityLabel(store.isRadiantRoomEventClaimedToday ? loc("Radiant Room Event reward claimed today", "Işıltılı Oda Etkinliği ödülü bugün alındı") : loc("Claim Radiant Room Event reward", "Işıltılı Oda Etkinliği ödülünü al")).accessibilityIdentifier("living.claimRadiantEvent")
   }
   QuestCard(icon: "bell.fill", tint: Theme.lavender, title: loc("Radiant Mastery · \(store.radiantRoomEventMasteryTier)", "Işıltı Ustalığı · \(trName(store.radiantRoomEventMasteryTier))"), detail: loc("Completed: \(store.radiantRoomEventAchievementCount) · Chime at 5 · Lumen Canopy at 10", "Tamamlanan: \(store.radiantRoomEventAchievementCount) · 5\'te Çan · 10\'da Işık Gölgeliği")) {
    VStack(spacing: 4) {
     Button(store.isRadiantChimeUnlocked ? loc("Chime ✓", "Çan ✓") : loc("Claim Chime", "Çanı Al")){if store.claimRadiantChimeReward(){done(loc("Radiant Chime unlocked! +140 coins · +5 stars", "Işıltı Çanı açıldı! +140 jeton · +5 yıldız"))}}.disabled(!store.isRadiantChimeRewardReady).accessibilityLabel(store.isRadiantChimeUnlocked ? loc("Radiant Chime unlocked", "Işıltı Çanı açıldı") : loc("Claim Radiant Chime", "Işıltı Çanı\'nı al")).accessibilityIdentifier("living.claimRadiantChime")
     Button(store.isLumenCanopyUnlocked ? loc("Canopy ✓", "Gölgelik ✓") : loc("Claim 10", "10 · Al")){if store.claimLightkeeperReward(){done(loc("Lumen Canopy unlocked! +220 coins · +7 stars", "Işık Gölgeliği açıldı! +220 jeton · +7 yıldız"))}}.disabled(!store.isLightkeeperRewardReady).accessibilityLabel(store.isLumenCanopyUnlocked ? loc("Lumen Canopy unlocked", "Işık Gölgeliği açıldı") : loc("Claim Lumen Canopy", "Işık Gölgeliği\'ni al")).accessibilityIdentifier("living.claimLumenCanopy")
    }
   }
   QuestCard(icon: "star.circle.fill", tint: Theme.sun, title: loc("Radiant Set Bonus", "Işıltı Seti Bonusu"), detail: loc("Complete 3-piece collection · +250 coins · +8 stars", "3 parçalı koleksiyonu tamamla · +250 jeton · +8 yıldız")) {
    Button(store.isRadiantSetBonusClaimed ? loc("Claimed", "Alındı") : loc("Claim", "Al")){if store.claimRadiantSetBonus(){done(loc("Radiant Set complete! +250 coins, +8 stars.", "Işıltı Seti tamamlandı! +250 jeton, +8 yıldız."))}}.disabled(store.isRadiantSetBonusClaimed)
   }
  }
 }

 @ViewBuilder private var lightkeeperGoals: some View {
  if store.isLumenCanopyUnlocked {
   QuestCard(icon: "moon.stars.fill", tint: Color(hex: 0x6E63C9), title: loc("Lightkeeper Weekly · \(store.weeklyLightkeeperProgress)/3", "Haftalık Işık Bekçisi · \(store.weeklyLightkeeperProgress)/3"), detail: loc("Ring Radiant Chime, then visit Lumen Canopy on 3 different days · +180 coins · +6 stars", "3 farklı gün önce Işıltı Çanı\'nı çal, sonra Işık Gölgeliği\'ne git · +180 jeton · +6 yıldız")) {
    Button(store.isWeeklyLightkeeperRewardClaimed ? loc("Week ✓", "Hafta ✓") : loc("Claim", "Al")){if store.claimWeeklyLightkeeperReward(){done(loc("Lightkeeper week complete! +180 coins · +6 stars", "Işık Bekçisi haftası tamamlandı! +180 jeton · +6 yıldız"))}}.disabled(!store.isWeeklyLightkeeperRewardReady).accessibilityLabel(store.isWeeklyLightkeeperRewardClaimed ? loc("Lightkeeper weekly reward claimed", "Haftalık Işık Bekçisi ödülü alındı") : loc("Claim Lightkeeper weekly reward", "Haftalık Işık Bekçisi ödülünü al")).accessibilityIdentifier("living.claimLightkeeperWeekly")
   }
   QuestCard(icon: "flame.fill", tint: Theme.peach, title: loc("Lightkeeper Streak · \(store.lightkeeperWeeklyStreak) week\(store.hasLightkeeperStreakCrown ? " · Crown ✓" : "")", "Işık Bekçisi Serisi · \(store.lightkeeperWeeklyStreak) hafta\(store.hasLightkeeperStreakCrown ? " · Taç ✓" : "")"), detail: loc("2 weeks: +125 coins · 4✦ · 4 weeks: +300 coins · 10✦ + Starlight Crown", "2 hafta: +125 jeton · 4✦ · 4 hafta: +300 jeton · 10✦ + Yıldız Işığı Tacı")) {
    VStack(spacing: 4) {
     Button(store.isLightkeeperStreak2Claimed ? "2W ✓" : loc("Claim 2W", "2H Al")){if store.claimLightkeeperStreak2Reward(){done(loc("2-week Lightkeeper streak! +125 coins · +4 stars", "2 haftalık Işık Bekçisi serisi! +125 jeton · +4 yıldız"))}}.disabled(!store.isLightkeeperStreak2Ready).accessibilityLabel(store.isLightkeeperStreak2Claimed ? loc("Two-week Lightkeeper reward claimed", "İki haftalık Işık Bekçisi ödülü alındı") : loc("Claim two-week Lightkeeper reward", "İki haftalık Işık Bekçisi ödülünü al")).accessibilityIdentifier("living.claimLightkeeperStreak2")
     Button(store.isLightkeeperStreak4Claimed ? "4W ✓" : loc("Claim 4W", "4H Al")){if store.claimLightkeeperStreak4Reward(){done(loc("4-week streak! Starlight Crown earned · +300 coins · +10 stars", "4 haftalık seri! Yıldız Işığı Tacı kazanıldı · +300 jeton · +10 yıldız"))}}.disabled(!store.isLightkeeperStreak4Ready).accessibilityLabel(store.isLightkeeperStreak4Claimed ? loc("Four-week Lightkeeper reward claimed", "Dört haftalık Işık Bekçisi ödülü alındı") : loc("Claim four-week Lightkeeper reward", "Dört haftalık Işık Bekçisi ödülünü al")).accessibilityIdentifier("living.claimLightkeeperStreak4")
    }
   }
  }
 }

 @ViewBuilder private var crownGoals: some View {
  if store.hasLightkeeperStreakCrown {
   QuestCard(icon: "crown.fill", tint: Theme.sun, title: loc("Crown Spark Weekly · \(store.weeklyCrownSparkProgress)/3", "Haftalık Taç Kıvılcımı · \(store.weeklyCrownSparkProgress)/3"), detail: loc("Wear Starlight Crown and visit Lumen Canopy on 3 different days this week · +150 coins · 5✦", "Bu hafta 3 farklı gün Yıldız Işığı Tacı\'nı takıp Işık Gölgeliği\'ne git · +150 jeton · 5✦")) {
    Button(store.isWeeklyCrownSparkClaimed ? loc("Week ✓", "Hafta ✓") : loc("Claim", "Al")){if store.claimWeeklyCrownSparkReward(){done(loc("Crown Spark week complete! +150 coins · +5 stars", "Taç Kıvılcımı haftası tamamlandı! +150 jeton · +5 yıldız"))}}.disabled(!store.isWeeklyCrownSparkReady).accessibilityLabel(store.isWeeklyCrownSparkClaimed ? loc("Crown Spark weekly reward claimed", "Haftalık Taç Kıvılcımı ödülü alındı") : loc("Claim Crown Spark weekly reward", "Haftalık Taç Kıvılcımı ödülünü al")).accessibilityIdentifier("living.claimCrownSparkWeekly")
   }
   QuestCard(icon: "sparkle", tint: Color(hex: 0x4FC9E0), title: loc("Crown Spark Collection · \(store.crownSparkWeeklyCollectionTier)", "Taç Kıvılcımı Koleksiyonu · \(trName(store.crownSparkWeeklyCollectionTier))"), detail: loc("Claimed weeks: \(store.crownSparkWeeksCollected)/3 · Comet Halo decoration at 3 weeks · +110 coins · 4✦", "Alınan haftalar: \(store.crownSparkWeeksCollected)/3 · 3 haftada Kuyruklu Yıldız Halesi · +110 jeton · 4✦")) {
    Button(store.isCometHaloUnlocked ? loc("Halo ✓", "Hale ✓") : loc("Claim Halo", "Haleyi Al")){if store.claimCometHaloReward(){done(loc("Comet Halo unlocked! +110 coins · +4 stars", "Kuyruklu Yıldız Halesi açıldı! +110 jeton · +4 yıldız"))}}.disabled(!store.isCometHaloRewardReady).accessibilityLabel(store.isCometHaloUnlocked ? loc("Comet Halo unlocked", "Kuyruklu Yıldız Halesi açıldı") : loc("Claim Comet Halo decoration", "Kuyruklu Yıldız Halesi dekorasyonunu al")).accessibilityIdentifier("living.claimCometHalo")
   }
   QuestCard(icon: "shield.lefthalf.filled", tint: Theme.lavender, title: loc("Starlight Guardian · \(store.crownCanopyCollectionTitle)", "Yıldız Işığı Koruyucusu · \(trName(store.crownCanopyCollectionTitle))"), detail: loc("Crown Spark days: \(store.crownCanopyAchievementCount)/7 · unlock Comet Veil at 7 · +160 coins · 5✦", "Taç Kıvılcımı günleri: \(store.crownCanopyAchievementCount)/7 · 7\'de Kuyruklu Yıldız Peçesi · +160 jeton · 5✦")) {
    Button(store.isCometVeilUnlocked ? loc("Veil ✓", "Peçe ✓") : loc("Claim", "Al")){if store.claimCometVeilReward(){done(loc("Comet Veil unlocked! +160 coins · +5 stars", "Kuyruklu Yıldız Peçesi açıldı! +160 jeton · +5 yıldız"))}}.disabled(!store.isCometVeilRewardReady).accessibilityLabel(store.isCometVeilUnlocked ? loc("Comet Veil unlocked", "Kuyruklu Yıldız Peçesi açıldı") : loc("Claim Comet Veil accessory", "Kuyruklu Yıldız Peçesi aksesuarını al")).accessibilityIdentifier("living.claimCometVeil")
   }
  }
 }

 @ViewBuilder private var keepsakeGoals: some View {
  if !store.ownedFriendKeepsakes.isEmpty {
   QuestCard(icon: "heart.fill", tint: Theme.pink, title: loc("Daily Memory Spark", "Günlük Anı Kıvılcımı"), detail: loc("Visit 2 different keepsakes · \(store.dailyKeepsakeMemoryProgress)/2", "2 farklı hatırayı ziyaret et · \(store.dailyKeepsakeMemoryProgress)/2")) {
    Button(store.isDailyKeepsakeMemoryClaimed ? loc("Claimed", "Alındı") : loc("Claim +40 ✦", "Al +40 ✦")){if store.claimDailyKeepsakeMemory(){done(loc("Daily Memory Spark complete! +40 coins, +1 star.", "Günlük Anı Kıvılcımı tamamlandı! +40 jeton, +1 yıldız."))}}.disabled(store.dailyKeepsakeMemoryProgress < 2 || store.isDailyKeepsakeMemoryClaimed)
   }
  }
  if let spotlight=store.dailyMemorySpotlightKeepsake {
   QuestCard(icon: "camera.filters", tint: Theme.peach, title: loc("Memory Spotlight", "Anı Spot Işığı"), detail: loc("Today: \(spotlight.name) · \(store.isDailyMemorySpotlightReady ? "visited" : "tap it in its room")", "Bugün: \(trName(spotlight.name)) · \(store.isDailyMemorySpotlightReady ? "ziyaret edildi" : "odasında ona dokun")")) {
    Button(store.isDailyMemorySpotlightClaimed ? loc("Claimed", "Alındı") : loc("Claim +20", "Al +20")){if store.claimDailyMemorySpotlight(){done(loc("Memory Spotlight complete! +20 coins.", "Anı Spot Işığı tamamlandı! +20 jeton."))}}.disabled(!store.isDailyMemorySpotlightReady || store.isDailyMemorySpotlightClaimed)
   }
  }
  if store.dailyMemorySpotlightFriend != nil && store.dailyMemorySpotlightKeepsake != nil {
   QuestCard(icon: "person.2.wave.2.fill", tint: Theme.mint, title: loc("Spotlight Friend Moment", "Spot Işığı Arkadaş Anı"), detail: spotlightDetail) {
    Button(store.isDailySpotlightFriendMomentClaimed ? loc("Claimed", "Alındı") : loc("Claim +30 ✦", "Al +30 ✦")){if store.claimDailySpotlightFriendMoment(){done(loc("Friend Moment complete! +30 coins, +1 star.", "Arkadaş Anı tamamlandı! +30 jeton, +1 yıldız."))}}.disabled(!store.isDailySpotlightFriendMomentReady || store.isDailySpotlightFriendMomentClaimed)
   }
  }
 }
}
