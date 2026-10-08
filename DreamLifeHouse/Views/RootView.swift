import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    var body: some View {
        VStack(spacing: 0) {
        if store.isSaveReadOnlyDueToNewerVersion {
            SaveWarningBanner(text: loc("This save is newer or has an unrecognized format. Changes will not be saved. Update the app to protect your progress.", "Bu kayıt daha yeni ya da tanınmayan bir biçimde. Değişiklikler kaydedilmeyecek. İlerlemeni korumak için uygulamayı güncelle."),
                              icon: "exclamationmark.triangle.fill", tint: Theme.peach)
                .accessibilityIdentifier("save.newerVersionWarning")
        }
        if store.isSaveReadOnlyDueToSequenceLimit {
            SaveWarningBanner(text: loc("This save has reached its journal limit. Your progress is protected, but new changes cannot be saved. Keep a backup of this device's data.", "Bu kayıt sınırına ulaştı. İlerlemen korunuyor ama yeni değişiklikler kaydedilemiyor. Bu cihazın verilerini yedekle."),
                              icon: "exclamationmark.triangle.fill", tint: Theme.peach)
                .accessibilityIdentifier("save.sequenceLimitWarning")
        }
        if store.isSaveReadOnlyDueToAmbiguousRecovery {
            SaveWarningBanner(text: loc("Conflicting save copies were found. All copies are preserved. New progress will not be saved until this is resolved. Ask a parent to back up this device.", "Birbiriyle çelişen kayıt kopyaları bulundu. Tüm kopyalar korunuyor. Sorun çözülene kadar yeni ilerleme kaydedilmeyecek. Bir ebeveynden bu cihazı yedeklemesini iste."),
                              icon: "exclamationmark.triangle.fill", tint: Theme.peach)
                .accessibilityIdentifier("save.ambiguousRecoveryWarning")
        }
        if store.isSaveReadOnlyDueToExternalChanges {
            SaveWarningBanner(text: loc("Your save changed outside this game session. Progress is protected; close and reopen the app to load the latest save.", "Kaydın bu oyun oturumunun dışında değişti. İlerlemen korunuyor; en son kaydı yüklemek için uygulamayı kapatıp yeniden aç."),
                              icon: "exclamationmark.arrow.triangle.2.circlepath", tint: Theme.sun)
                .accessibilityIdentifier("save.externalChangeWarning")
        }
        Group {
        if !store.playerSettings.hasCompletedOnboarding { OnboardingView() } else {
        // v2.56: five tabs instead of eight, so iPhone no longer hides
        // Adventures and Settings behind the system "More" list.
        TabView {
            HouseView()
                .tabItem { Label(loc("House", "Ev"), systemImage: "house.fill") }
            MeView()
                .tabItem { Label(loc("Me", "Ben"), systemImage: "person.crop.circle.fill") }
            PlayView()
                .tabItem { Label(loc("Play", "Oyna"), systemImage: "party.popper.fill") }
            TasksView()
                .tabItem { Label(loc("Adventures", "Maceralar"), systemImage: "star.fill") }
            SettingsView()
                .tabItem { Label(loc("Settings", "Ayarlar"), systemImage: "gearshape.fill") }
        }
        .tint(Theme.pink)
        }
        }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
    }
}

private struct SaveWarningBanner: View {
    let text: String
    let icon: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(Theme.ink)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.28))
            .accessibilityElement(children: .combine)
    }
}

/// "Me" tab: character creator and wardrobe in one place.
struct MeView: View {
    private enum MeSection: String, CaseIterable, Identifiable { case look, wardrobe; var id: String { rawValue }
        var title: String { self == .look ? loc("My Look", "Görünümüm") : loc("Wardrobe", "Gardırop") } }
    @State private var section: MeSection = .look
    var body: some View {
        VStack(spacing: 10) {
            TopBar()
            Picker(loc("Section", "Bölüm"), selection: $section) {
                ForEach(MeSection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            switch section {
            case .look: CharacterCreatorView()
            case .wardrobe: DressUpView()
            }
        }
        .background(AppBackground())
    }
}

/// "Play" tab: kitchen mini-game, pet care and friends.
struct PlayView: View {
    private enum PlaySection: String, CaseIterable, Identifiable { case kitchen, pet, friends; var id: String { rawValue }
        var title: String { switch self { case .kitchen: return loc("Kitchen", "Mutfak"); case .pet: return loc("Pet", "Evcil Hayvan"); case .friends: return loc("Friends", "Arkadaşlar") } } }
    @State private var section: PlaySection = .kitchen
    var body: some View {
        VStack(spacing: 10) {
            TopBar()
            Picker(loc("Section", "Bölüm"), selection: $section) {
                ForEach(PlaySection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            switch section {
            case .kitchen: KitchenView()
            case .pet: PetView()
            case .friends: FriendsView()
            }
        }
        .background(AppBackground())
    }
}
