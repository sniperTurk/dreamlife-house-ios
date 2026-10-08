import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showRecoveryExporter = false
    @State private var showRecoveryExportConfirmation = false
    @State private var recoveryDocument: SaveRecoveryDocument?
    @State private var exportErrorMessage = ""
    @State private var showExportError = false
    @State private var recoveryInspection: SaveRecoveryInspection?


    var body: some View {
        NavigationStack {
            Form {
                Section(loc("Play experience", "Oyun deneyimi")) {
                    Toggle(loc("Sound", "Ses"), isOn: binding(\.soundEnabled))
                    Toggle(loc("Haptics", "Titreşim"), isOn: binding(\.hapticsEnabled))
                    Toggle(loc("Reduce motion", "Hareketi azalt"), isOn: binding(\.reducedMotion))
                }
                Section(loc("Family-friendly controls", "Aile dostu ayarlar")) {
                    Toggle(loc("Confirm purchases", "Satın almaları onayla"), isOn: binding(\.purchaseConfirmation))
                    Text(loc("When on, the game asks before spending in-game coins on decorations and outfits. DreamLife House has no real-money purchases, ads or accounts.", "Açıkken oyun, dekorasyon ve kıyafetlere jeton harcamadan önce sorar. DreamLife House\'ta gerçek parayla satın alma, reklam ya da hesap yoktur."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if store.isSaveReadOnlyDueToAmbiguousRecovery {
                    Section(loc("Save recovery · for parents", "Kayıt kurtarma · ebeveynler için")) {
                        Text(loc("Different save copies have the same sequence number. Neither will be deleted or replaced automatically.", "Farklı kayıt kopyaları aynı sıra numarasına sahip. Hiçbiri otomatik olarak silinmeyecek ya da değiştirilmeyecek."))
                            .font(.footnote)
                        Text(loc("These are separate saved copies. The app cannot safely tell which conflicting copy is correct.", "Bunlar ayrı kayıt kopyaları. Uygulama hangisinin doğru olduğunu güvenle bilemez."))
                            .font(.footnote).foregroundStyle(.secondary)
                        if let recoveryInspection {
                            Text(recoveryInspection.summary)
                                .font(.subheadline)
                                .accessibilityIdentifier("settings.recoverySummary")
                            ForEach(recoveryInspection.previews) { preview in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trName(preview.title)).font(.headline)
                                    Text(trName(preview.summary)).font(.footnote)
                                        .foregroundStyle(.secondary)
                                    if let comparison = preview.byteComparisonSummary {
                                        Text(comparison).font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("settings.recoveryPreview.\(preview.id)")
                            }
                        } else {
                            Text(loc("Review unavailable or out of date. Refresh the inspection before exporting.", "İnceleme yok ya da güncel değil. Dışa aktarmadan önce incelemeyi yenile."))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(loc("Exact-byte matches help identify duplicate copies, even if their visible totals are identical. Different bytes do not prove which copy is correct.", "Birebir aynı kopyalar, toplamları aynı görünse bile kopyaları ayırt etmeye yardım eder. Farklı olmaları hangisinin doğru olduğunu kanıtlamaz."))
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(loc("Review only: no copy is selected, restored, or changed.", "Yalnızca inceleme: hiçbir kopya seçilmez, geri yüklenmez ya da değiştirilmez."))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button {
                            refreshRecoveryInspection()
                        } label: {
                            Label(loc("Refresh save inspection", "Kayıt incelemesini yenile"), systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("settings.refreshRecoveryInspection")
                        .accessibilityHint(loc("Read the current copies again before exporting.", "Dışa aktarmadan önce güncel kopyaları yeniden oku."))
                        Button {
                            // A child should not be able to open the Files exporter
                            // accidentally with a single tap. Confirm explicitly.
                            showRecoveryExportConfirmation = true
                        } label: {
                            Label(loc("Export preserved save copies", "Korunan kayıt kopyalarını dışa aktar"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(recoveryInspection == nil)
                        .accessibilityIdentifier("settings.exportRecovery")
                        .accessibilityHint(loc("Ask a parent to save this file somewhere safe.", "Bir ebeveynden bu dosyayı güvenli bir yere kaydetmesini iste."))
                        Text(loc("The export includes integrity checks to detect accidental damage, but is not encrypted or tamper-proof. Share it only with a trusted adult. Exporting does not restore your game.", "Dışa aktarılan dosya kazara bozulmayı fark eden kontroller içerir ama şifreli değildir ve değiştirilmeye karşı korumalı değildir. Yalnızca güvendiğin bir yetişkinle paylaş. Dışa aktarmak oyununu geri yüklemez."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section(loc("About", "Hakkında")) {
                    LabeledContent(loc("Version", "Sürüm"), value: appVersion)
                    Text(loc("All progress is stored only on this device. Nothing is collected or uploaded.", "Tüm ilerleme yalnızca bu cihazda saklanır. Hiçbir şey toplanmaz ya da yüklenmez."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section(loc("Accessibility", "Erişilebilirlik")) {
                    Label(store.playerSettings.reducedMotion ? loc("Motion effects minimized", "Hareket efektleri azaltıldı") : loc("Standard motion effects", "Standart hareket efektleri"), systemImage: "figure.walk.motion")
                    Text(loc("Controls use text labels as well as symbols so important actions are not communicated by icons alone.", "Önemli işlemler yalnızca simgelerle değil, yazılı etiketlerle de gösterilir."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(Theme.pink)
            .navigationTitle(loc("Settings", "Ayarlar"))
            .onAppear { refreshRecoveryInspection() }
            .confirmationDialog(
                loc("Export private save data?", "Özel kayıt verileri dışa aktarılsın mı?"),
                isPresented: $showRecoveryExportConfirmation,
                titleVisibility: .visible
            ) {
                Button(loc("Continue to Files", "Dosyalar\'a devam et")) { confirmRecoveryExport() }
                    .accessibilityIdentifier("settings.confirmRecoveryExport")
                Button(loc("Cancel", "Vazgeç"), role: .cancel) { }
            } message: {
                Text(loc("This archive may contain player names, progress and preferences. It is not encrypted. Save it only in a trusted location. The game does not upload or change saved copies.", "Bu arşiv oyuncu adlarını, ilerlemeyi ve tercihleri içerebilir. Şifreli değildir. Yalnızca güvenli bir yere kaydet. Oyun kayıt kopyalarını yüklemez ya da değiştirmez."))
            }
            .fileExporter(
                isPresented: $showRecoveryExporter,
                document: recoveryDocument,
                contentType: .json,
                defaultFilename: "DreamLifeHouse-Save-Recovery"
            ) { result in
                recoveryDocument = nil
                if case .failure(let error) = result {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            }
            .alert(loc("Unable to export", "Dışa aktarılamadı"), isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private func refreshRecoveryInspection() {
        recoveryDocument = nil
        recoveryInspection = store.beginRecoveryInspection()
    }

    private func confirmRecoveryExport() {
        // Recheck at confirmation time: the copies might have changed while
        // the privacy dialog was open. Never export a stale inspection.
        guard let inspection = recoveryInspection,
              let data = store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id) else {
            recoveryInspection = nil
            recoveryDocument = nil
            exportErrorMessage = loc("Save copies changed after inspection. Refresh and review the copies before exporting.", "Kayıt kopyaları incelemeden sonra değişti. Dışa aktarmadan önce yenile ve kopyaları gözden geçir.")
            showExportError = true
            return
        }
        recoveryDocument = SaveRecoveryDocument(data: data)
        showRecoveryExporter = true
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.playerSettings[keyPath: keyPath] }, set: { value in
            switch keyPath {
            case \.soundEnabled: store.updateSettings(soundEnabled: value)
            case \.hapticsEnabled: store.updateSettings(hapticsEnabled: value)
            case \.reducedMotion: store.updateSettings(reducedMotion: value)
            case \.purchaseConfirmation: store.updateSettings(purchaseConfirmation: value)
            default: break
            }
        })
    }
}
