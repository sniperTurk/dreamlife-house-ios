"""Static UI wiring contract; this is not a replacement for iOS UI tests."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root/'DreamLifeHouse/Views/HouseView.swift').read_text()
root_source=(root/'DreamLifeHouse/Views/RootView.swift').read_text()
checks={
    'radiant controls are rendered': r'\bradiantDecorationControls\s*\n',
    'chime action is reachable': r'if store\.isRadiantChimeUnlocked\s*\{\s*Button\s*\{\s*if store\.interactWithRadiantChime\(in:roomID\)',
    'canopy action is reachable': r'if store\.isLumenCanopyUnlocked\s*\{\s*Button\s*\{[^}]*store\.interactWithLumenCanopy\(in:roomID\)',
    'halo action is reachable': r'if store\.isCometHaloUnlocked\s*\{\s*Button\s*\{\s*if store\.interactWithCometHalo\(in:roomID\)',
    'chime accessibility id': r'\.accessibilityIdentifier\("living\.radiantChime"\)',
    'canopy accessibility id': r'\.accessibilityIdentifier\("living\.lumenCanopy"\)',
    'halo accessibility id': r'\.accessibilityIdentifier\("living\.cometHalo"\)',
    'controls restricted to living room': r'if roomID == "living" && \(store\.isRadiantChimeUnlocked',
    'collection claim wired': r'store\.claimCometHaloReward\(\)',
    'chime VoiceOver hint': r'\.accessibilityIdentifier\("living\.radiantChime"\)\s*\.accessibilityHint',
    'canopy VoiceOver hint': r'\.accessibilityIdentifier\("living\.lumenCanopy"\)\s*\.accessibilityHint',
    'halo VoiceOver hint': r'\.accessibilityIdentifier\("living\.cometHalo"\)\s*\.accessibilityHint',
    'weekly lightkeeper unique action': r'\.accessibilityIdentifier\("living\.claimLightkeeperWeekly"\)',
    'weekly crown unique action': r'\.accessibilityIdentifier\("living\.claimCrownSparkWeekly"\)',
    'halo claim unique action': r'\.accessibilityIdentifier\("living\.claimCometHalo"\)',
    'radiant event unique claim': r'\.accessibilityIdentifier\("living\.claimRadiantEvent"\)',
    'radiant chime unique claim': r'\.accessibilityIdentifier\("living\.claimRadiantChime"\)',
    'lumen canopy unique claim': r'\.accessibilityIdentifier\("living\.claimLumenCanopy"\)',
    'lightkeeper two-week unique claim': r'\.accessibilityIdentifier\("living\.claimLightkeeperStreak2"\)',
    'lightkeeper four-week unique claim': r'\.accessibilityIdentifier\("living\.claimLightkeeperStreak4"\)',
    'comet veil unique claim': r'\.accessibilityIdentifier\("living\.claimCometVeil"\)',
    'screen-reader action feedback': r'\.accessibilityIdentifier\("house\.actionFeedback"\)',
}
for name, pattern in checks.items():
    if not re.search(pattern,source,re.S):
        raise SystemExit(f'FAIL: {name}')
if not re.search(r'if store\.isSaveReadOnlyDueToNewerVersion\s*\{',root_source):
    raise SystemExit('FAIL: root view does not display newer-save warning')
if not re.search(r'\.accessibilityIdentifier\("save\.newerVersionWarning"\)',root_source):
    raise SystemExit('FAIL: newer-save warning not accessible')
if not re.search(r'if store\.isSaveReadOnlyDueToExternalChanges\s*\{', root_source):
    raise SystemExit('FAIL: root view does not display external-save warning')
if not re.search(r'\.accessibilityIdentifier\("save\.externalChangeWarning"\)', root_source):
    raise SystemExit('FAIL: external-save warning has no accessibility id')
if not re.search(r'if store\.isSaveReadOnlyDueToSequenceLimit\s*\{', root_source):
    raise SystemExit('FAIL: root view does not display terminal-sequence warning')
if not re.search(r'\.accessibilityIdentifier\("save\.sequenceLimitWarning"\)', root_source):
    raise SystemExit('FAIL: terminal-sequence warning has no accessibility id')
if not re.search(r'if store\.isSaveReadOnlyDueToAmbiguousRecovery\s*\{', root_source):
    raise SystemExit('FAIL: ambiguous recovery warning not shown')
if not re.search(r'\.accessibilityIdentifier\("save\.ambiguousRecoveryWarning"\)', root_source):
    raise SystemExit('FAIL: ambiguous recovery warning missing accessibility id')
if 'unrecognized format' not in root_source:
    raise SystemExit('FAIL: read-only warning does not explain unrecognized save schemas')
tasks_source=(root/'DreamLifeHouse/Views/TasksView.swift').read_text()
app_source=(root/'DreamLifeHouse/DreamLifeHouseApp.swift').read_text()
ui_test_source=(root/'DreamLifeHouseUITests/DreamLifeHouseUITests.swift').read_text()
for label, condition in {
    'task claims validate in model': 'store.claimAdventureTask(task.id)' in tasks_source,
    'task claims have stable accessibility IDs': 'adventures.claim.\\(task.id)' in tasks_source,
    'ready task fixture': '--dreamlife-ui-test-task-ready' in app_source,
    'resume fixture does not clear progress': 'if !arguments.contains("--dreamlife-ui-test-resume")' in app_source,
    'external change warning fixture': '--dreamlife-ui-test-external' in app_source,
    'reward UI test source': 'testAdventureRewardClaimsOnceAndPersistsAfterRelaunch' in ui_test_source,
    'external warning UI test source': 'testExternalSessionSaveChangeShowsWarning' in ui_test_source,
    'side-slot decoration readiness in UI': 'isReady:{ $0.hasPlacedAdventureDecoration }' in tasks_source,
    'side-slot decoration fixture': '--dreamlife-ui-test-decor-side' in app_source,
    'side-slot decoration UI test': 'testSideSlotDecorationRewardIsReachableAndPersists' in ui_test_source,
    'scrollable adventure content': 'ScrollView {' in tasks_source and 'adventures.scrollContent' in tasks_source,
    'adaptive stacked adventure cards': 'VStack(alignment: .leading, spacing: 10)' in tasks_source,
}.items():
    if not condition: raise SystemExit(f'FAIL: {label}')
extra = {
    'oversized save UI fixture': '--dreamlife-ui-test-extreme-save' in app_source,
    'oversized save UI test': 'testExtremeRestoredSaveStillAllowsAdventuresNavigation' in ui_test_source,
    'oversized save smoke suite': (root/'Tools/ModelSmokeV243.swift').exists(),
    'terminal-sequence fixture': '--dreamlife-ui-test-sequence-limit' in app_source,
    'terminal-sequence UI test': 'testTerminalSequenceSaveShowsReadOnlyWarning' in ui_test_source,
    'terminal-sequence smoke suite': (root/'Tools/ModelSmokeV244.swift').exists(),
    'equal-sequence recovery smoke suite': (root/'Tools/ModelSmokeV245.swift').exists(),
    'ambiguous save fixture': '--dreamlife-ui-test-ambiguous-save' in app_source,
    'ambiguous warning UI test': 'testAmbiguousSaveConflictShowsReadOnlyWarning' in ui_test_source,
}
settings_source=(root/'DreamLifeHouse/Views/SettingsView.swift').read_text()
model_source=(root/'DreamLifeHouse/Models/GameStore.swift').read_text()
export_doc_source=(root/'DreamLifeHouse/Views/SaveRecoveryDocument.swift').read_text()
extra.update({
    'recovery export button gated on ambiguity': 'if store.isSaveReadOnlyDueToAmbiguousRecovery {' in settings_source,
    'recovery export accessibility id': 'settings.exportRecovery' in settings_source,
    'recovery export uses system Files picker': '.fileExporter(' in settings_source,
    'recovery export reads raw slots': 'let before = keys.map { defaults.data(forKey: $0) }' in model_source,
    'recovery export checks for concurrent edits': 'return before == after ? before : nil' in model_source,
    'recovery document uses FileDocument': 'struct SaveRecoveryDocument: FileDocument' in export_doc_source,
    'recovery export UI test source': 'testAmbiguousSaveOffersParentRecoveryExportInSettings' in ui_test_source,
    'recovery export model smoke suite': (root/'Tools/ModelSmokeV246.swift').exists(),
    'recovery integrity marker in model': 'crc32:%08X' in model_source,
    'recovery integrity checked before export': 'roundTrip.integrityStatus == .verified' in model_source,
    'recovery archive verification smoke suite': (root/'Tools/ModelSmokeV247.swift').exists(),
    'recovery archive integrity notice': 'not encrypted or tamper-proof' in settings_source,
    'recovery integrity privacy UI test source': 'testV247RecoveryExportExplainsIntegrityAndPrivacyLimits' in ui_test_source,
    'read-only preview guarded on conflict': 'store.beginRecoveryInspection()' in settings_source,
    'preview row identifiers': 'settings.recoveryPreview.\\(preview.id)' in settings_source,
    'preview does not select save': 'no copy is selected, restored, or changed' in settings_source,
    'preview model has no writes': 'func previewAmbiguousRecoverySlots()' in model_source,
    'preview UI test source': 'testV248RecoveryPreviewListsConflictingCopySummaries' in ui_test_source,
    'preview model smoke suite': (root/'Tools/ModelSmokeV248.swift').exists(),
    'equal primary backup fixture': '--dreamlife-ui-test-equal-primary-backup' in app_source,
    'equal primary backup UI test': 'testV249EqualPrimaryBackupWithoutJournalShowsReadOnlyRecovery' in ui_test_source,
    'equal primary backup conflict checked at load': 'hasUnresolvedPrimaryBackupConflict' in model_source,
    'equal primary backup smoke suite': (root/'Tools/ModelSmokeV249.swift').exists(),
    'equal primary pending fixture': '--dreamlife-ui-test-equal-primary-pending' in app_source,
    'equal primary pending UI test': 'testV250EqualPrimaryPendingConflictPreservesJournalInParentPreview' in ui_test_source,
    'equal primary pending guard on load': 'hasUnresolvedPrimaryPendingConflict(primary: primary, pending: pending)' in model_source,
    'equal primary pending guard before save': 'primary: diskPrimary, pending: defaults.data(forKey: pendingKey)' in model_source,
    'equal primary pending smoke suite': (root/'Tools/ModelSmokeV250.swift').exists(),
    'three-way conflict fixture': '--dreamlife-ui-test-equal-backup-with-pending' in app_source,
    'three-way conflict UI test': 'testV251ThreeWayRecoveryConflictKeepsAllCopiesVisible' in ui_test_source,
    'three-way conflict smoke suite': (root/'Tools/ModelSmokeV251.swift').exists(),
    'inspection token is required for parent export': 'exportAmbiguousRecoveryArchive(inspectionID: inspection.id)' in settings_source,
    'inspection refresh button accessible': 'settings.refreshRecoveryInspection' in settings_source,
    'inspection refresh invalidates stale UI state': 'recoveryInspection = nil' in settings_source,
    'model verifies exact inspection bytes': '(expectedBytes.map({ $0 == bytes }) ?? true)'  in model_source,
    'model rechecks slots after encoding': 'readRecoverySlotsConsistently() == bytes' in model_source,
    'inspection regression smoke suite': (root/'Tools/ModelSmokeV252.swift').exists(),
    'inspection UI test source': 'testV252RecoveryInspectionCanBeRefreshed' in ui_test_source,
    'exact-byte duplicate comparison in model': 'Exact bytes match ' in model_source,
    'comparison is shown in parent UI': 'preview.byteComparisonSummary' in settings_source,
    'comparison limitations explained': 'Different bytes do not prove which copy is correct' in settings_source,
    'comparison smoke suite': (root/'Tools/ModelSmokeV253.swift').exists(),
    'comparison UI test source': 'testV253ParentPreviewDistinguishesExactCopies' in ui_test_source,
    'duplicate-copy UI fixture': '--dreamlife-ui-test-matching-copies' in app_source,
})
extra.update({
    'parent summary visible': 'Text(recoveryInspection.summary)' in settings_source,
    'parent summary accessibility id': 'settings.recoverySummary' in settings_source,
    'parent summary derived from captured bytes': 'makeRecoveryInspectionSummary(bytes, previews: previews)' in model_source,
    'export confirmation is explicit': '.confirmationDialog(' in settings_source and 'Export private save data?' in settings_source,
    'export confirmation describes privacy risk': 'may contain player names, progress and preferences' in settings_source,
    'export confirmation rechecks inspected bytes': '"Continue to Files"' in settings_source and '{ confirmRecoveryExport() }' in settings_source and 'store.exportAmbiguousRecoveryArchive(inspectionID: inspection.id)' in settings_source,
    'export confirmation accessible': 'settings.confirmRecoveryExport' in settings_source,
    'confirmation smoke suite': (root/'Tools/ModelSmokeV254.swift').exists(),
    'confirmation UI test source': 'testV254ParentRecoveryOverviewAndPrivateExportConfirmation' in ui_test_source,
})
extra.update({
    'v2.55 foreign pending journal guard': 'if diskPending != nil {' in model_source,
    'v2.55 staged primary compare': 'defaults.data(forKey: saveKey) == diskPrimary' in model_source,
    'v2.55 staged backup compare': 'defaults.data(forKey: backupKey) == diskBackup' in model_source,
    'v2.55 precommit backup compare': 'defaults.data(forKey: backupKey) == expectedBackup' in model_source,
    'v2.55 safe pending cleanup': 'private func discardOurPendingJournal(_ data: Data)' in model_source,
    'v2.55 interleaving smoke suite': (root/'Tools/ModelSmokeV255.swift').exists(),
})
for label, ok in extra.items():
    if not ok: raise SystemExit(f'FAIL: {label}')
print(f'DreamLife House v2.55 UI static wiring: {len(checks)+21+len(extra)}/{len(checks)+21+len(extra)} PASS')
