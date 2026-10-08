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
                Section("Play experience") {
                    Toggle("Sound", isOn: binding(\.soundEnabled))
                    Toggle("Haptics", isOn: binding(\.hapticsEnabled))
                    Toggle("Reduce motion", isOn: binding(\.reducedMotion))
                }
                Section("Family-friendly controls") {
                    Toggle("Confirm purchases", isOn: binding(\.purchaseConfirmation))
                    Text("When on, the game asks before spending in-game coins on decorations and outfits. DreamLife House has no real-money purchases, ads or accounts.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if store.isSaveReadOnlyDueToAmbiguousRecovery {
                    Section("Save recovery · for parents") {
                        Text("Different save copies have the same sequence number. Neither will be deleted or replaced automatically.")
                            .font(.footnote)
                        Text("These are separate saved copies. The app cannot safely tell which conflicting copy is correct.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let recoveryInspection {
                            Text(recoveryInspection.summary)
                                .font(.subheadline)
                                .accessibilityIdentifier("settings.recoverySummary")
                            ForEach(recoveryInspection.previews) { preview in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preview.title).font(.headline)
                                    Text(preview.summary).font(.footnote)
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
                            Text("Review unavailable or out of date. Refresh the inspection before exporting.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("Exact-byte matches help identify duplicate copies, even if their visible totals are identical. Different bytes do not prove which copy is correct.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Review only: no copy is selected, restored, or changed.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button {
                            refreshRecoveryInspection()
                        } label: {
                            Label("Refresh save inspection", systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("settings.refreshRecoveryInspection")
                        .accessibilityHint("Read the current copies again before exporting.")
                        Button {
                            // A child should not be able to open the Files exporter
                            // accidentally with a single tap. Confirm explicitly.
                            showRecoveryExportConfirmation = true
                        } label: {
                            Label("Export preserved save copies", systemImage: "square.and.arrow.up")
                        }
                        .disabled(recoveryInspection == nil)
                        .accessibilityIdentifier("settings.exportRecovery")
                        .accessibilityHint("Ask a parent to save this file somewhere safe.")
                        Text("The export includes integrity checks to detect accidental damage, but is not encrypted or tamper-proof. Share it only with a trusted adult. Exporting does not restore your game.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("All progress is stored only on this device. Nothing is collected or uploaded.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Accessibility") {
                    Label(store.playerSettings.reducedMotion ? "Motion effects minimized" : "Standard motion effects", systemImage: "figure.walk.motion")
                    Text("Controls use text labels as well as symbols so important actions are not communicated by icons alone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(Theme.pink)
            .navigationTitle("Settings")
            .onAppear { refreshRecoveryInspection() }
            .confirmationDialog(
                "Export private save data?",
                isPresented: $showRecoveryExportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue to Files") { confirmRecoveryExport() }
                    .accessibilityIdentifier("settings.confirmRecoveryExport")
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This archive may contain player names, progress and preferences. It is not encrypted. Save it only in a trusted location. The game does not upload or change saved copies.")
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
            .alert("Unable to export", isPresented: $showExportError) {
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
            exportErrorMessage = "Save copies changed after inspection. Refresh and review the copies before exporting."
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
