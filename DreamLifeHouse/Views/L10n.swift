import Foundation

// MARK: - Localisation (English + Turkish)
//
// The UI picks Turkish when the app runs in Turkish (device language or the
// per-app language in iOS Settings), otherwise English. Every visible string is
// written once in both languages at the call site with `loc(en, tr)`, so
// interpolated values and Turkish word order stay correct and compiler-checked.
// English stays the base language, which keeps the UI tests unchanged.

enum L10n {
    static let isTurkish: Bool = {
        let preferred = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("tr")
    }()
}

/// Returns the Turkish text when the app is running in Turkish, otherwise the English text.
func loc(_ en: String, _ tr: String) -> String { L10n.isTurkish ? tr : en }

/// Translates display names and sentences that come from the game model.
/// Unknown strings fall back to the original English text.
func trName(_ en: String) -> String {
    guard L10n.isTurkish else { return en }
    return L10n.names[en] ?? en
}

/// "dance" → "Dance" / "Dans" (friend favourite activities).
func activityName(_ id: String) -> String {
    switch id {
    case "dance": return loc("Dance", "Dans")
    case "decorate": return loc("Decorate", "Dekorasyon")
    case "garden": return loc("Garden", "Bahçe")
    case "style": return loc("Style", "Stil")
    case "cook": return loc("Cook", "Yemek")
    case "teaParty": return loc("Tea Party", "Çay Partisi")
    case "talentShow": return loc("Talent Show", "Yetenek Gösterisi")
    default: return id.capitalized
    }
}

/// Short verb phrase used inside sentences: "do dance" → "dans edin".
func activityPhrase(_ id: String) -> String {
    switch id {
    case "dance": return loc("dance", "dans edin")
    case "decorate": return loc("decorate", "dekorasyon yapın")
    case "garden": return loc("garden", "bahçede oynayın")
    case "style": return loc("style", "stil denemesi yapın")
    case "cook": return loc("cook", "yemek yapın")
    case "teaParty": return loc("host a Tea Party", "çay partisi verin")
    default: return id
    }
}

extension L10n {
    static let names: [String: String] = [
        // Rooms
        "Living Room": "Oturma Odası", "Bedroom": "Yatak Odası", "Kitchen": "Mutfak",
        "Bathroom": "Banyo", "Garden": "Bahçe",
        // Decorations
        "Pastel Sofa": "Pastel Kanepe", "Star Lamp": "Yıldız Lamba", "Flower Corner": "Çiçek Köşesi",
        "Music Spot": "Müzik Köşesi", "Cloud Seat": "Bulut Koltuk", "Happy Plant": "Neşeli Bitki",
        // Character options
        "Waves": "Dalgalı", "Bob": "Kısa Kesim", "Curls": "Bukleli", "Ponytail": "At Kuyruğu",
        "Chestnut": "Kestane", "Midnight": "Gece Siyahı", "Honey": "Bal Sarısı", "Berry": "Böğürtlen",
        "Light": "Açık", "Warm": "Buğday", "Deep": "Esmer",
        "None": "Yok", "Glasses": "Gözlük", "Star Clip": "Yıldız Toka", "Flower Clip": "Çiçek Toka",
        "Starlight Crown": "Yıldız Işığı Tacı", "Comet Veil": "Kuyruklu Yıldız Peçesi",
        // Outfits
        "Sunny": "Güneşli", "Party": "Parti", "Sport": "Spor", "Creative": "Yaratıcı",
        // Keepsakes
        "Moonlight Music Box": "Ay Işığı Müzik Kutusu", "Rainbow Sketchbook": "Gökkuşağı Defteri",
        "Tiny Garden Terrarium": "Minik Bahçe Teraryumu", "Starlight Style Pin": "Yıldız Işığı Broşu",
        "Sunny Recipe Tin": "Güneşli Tarif Kutusu",
        // Surprise badges
        "Dance-Off Star": "Dans Yıldızı", "Cozy Fort Builder": "Sıcacık Kale Ustası",
        "Taste-Test Hero": "Tadım Kahramanı", "Bubble Beat": "Köpük Ritmi", "Garden Explorer": "Bahçe Kâşifi",
        // Surprise buddy events
        "Living Room Dance-Off": "Oturma Odası Dans Yarışması", "Bedroom Pillow Fort": "Yatak Odası Yastık Kalesi",
        "Kitchen Taste Test": "Mutfak Tadım Testi", "Bathroom Bubble Beats": "Banyo Köpük Ritimleri",
        "Garden Treasure Hunt": "Bahçe Hazine Avı",
        // Day phases and chain
        "Morning": "Sabah", "Afternoon": "Öğleden Sonra", "Evening": "Akşam",
        "Take a shower in the bathroom": "Banyoda duş al",
        "Place a decoration in any room": "Herhangi bir odaya dekorasyon yerleştir",
        "Sleep in the bedroom": "Yatak odasında uyu",
        // Trophies and collections
        "Bronze": "Bronz", "Silver": "Gümüş", "Gold": "Altın", "Diamond": "Elmas",
        "Sparkle Garland": "Pırıltılı Girlant", "Memory Pedestal": "Anı Kaidesi", "Dreamlight Crown": "Rüya Işığı Tacı",
        "Glow Seeker": "Işıltı Avcısı", "Prism Keeper": "Prizma Bekçisi", "Aurora Curator": "Aurora Küratörü",
        "Radiant Master": "Işıltı Ustası",
        "The mobile is waiting for its first shimmer.": "Mobil, ilk parıltısını bekliyor.",
        "A soft rainbow dances across the room.": "Yumuşak bir gökkuşağı odada dans ediyor.",
        "The colors swirl brighter together.": "Renkler birlikte daha parlak dönüyor.",
        "A prism sparkle fills the whole room!": "Prizma ışıltısı bütün odayı dolduruyor!",
        "Cozy Daylight": "Sıcak Gün Işığı", "Starwash": "Yıldız Yağmuru", "Moonmist": "Ay Sisi",
        "Celestial Glow": "Gök Işıltısı", "Chime Cascade": "Çan Şelalesi",
        "Use Starlight → Moonbeam → Celestial in order.": "Sırayla Yıldız Işığı → Ay Işını → Gök Feneri'ni kullan.",
        "The sun-catcher paints tiny stars across the room.": "Güneş yakalayıcı odaya minik yıldızlar çiziyor.",
        "Moonlight joins the colors — one sparkle remains.": "Ay ışığı renklere katıldı; bir ışıltı kaldı.",
        "Event ready — ring the Radiant Chime for a bonus finale.": "Etkinlik hazır; bonus final için Işıltı Çanı'nı çal.",
        "Radiant Room Event ready! The whole room is glowing.": "Işıltılı Oda Etkinliği hazır! Bütün oda parlıyor.",
        "Chime Cascade ready! Claim the enhanced Radiant Room reward.": "Çan Şelalesi hazır! Güçlendirilmiş ödülünü al.",
        "First Glow": "İlk Işıltı", "Room Illuminator": "Oda Aydınlatıcı", "Radiant Host": "Işıltılı Ev Sahibi",
        "Lightkeeper": "Işık Bekçisi",
        "Waiting for Starlight": "Yıldız Işığı Bekleniyor", "Crown Spark": "Taç Kıvılcımı",
        "Canopy Keeper": "Gölgelik Bekçisi", "Starlight Guardian": "Yıldız Işığı Koruyucusu",
        "First Spark": "İlk Kıvılcım", "Shimmer Keeper": "Parıltı Bekçisi", "Comet Collector": "Kuyruklu Yıldız Koleksiyoncusu",
        "Skyward Legend": "Gökyüzü Efsanesi",
        "Unlock a Trophy Mastery decoration to begin daily collection moments.": "Günlük koleksiyon anları için bir Kupa Ustalığı dekorasyonu aç.",
        "Unlock two Trophy decorations to discover Combo Moments.": "Kombo Anları için iki Kupa dekorasyonu aç.",
        "Earn and display a friendship keepsake to unlock today's challenge.": "Bugünün görevini açmak için bir arkadaşlık hatırası kazan ve sergile.",
        // Save recovery (parent screen)
        "Primary copy": "Ana kopya", "Backup copy": "Yedek kopya", "Pending copy": "Bekleyen kopya",
        "Unknown copy": "Bilinmeyen kopya", "No copy present": "Kopya yok",
        "Requires a newer app or has an unrecognized save format": "Daha yeni bir uygulama gerekiyor ya da kayıt biçimi tanınmıyor",
        "Damaged or unreadable copy": "Hasarlı ya da okunamayan kopya",
        "No other copy has identical bytes": "Başka hiçbir kopya birebir aynı değil",
        "Rainbow Cupcake": "Gökkuşağı Keki",
        // Pet species
        "cat": "kedi", "dog": "köpek",
    ]
}
