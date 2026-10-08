# DreamLife House — iOS Prototype

Original kids' dollhouse / life-play game. It does not use Barbie names, characters, logos, artwork, music, house designs, or other protected assets.

## Included in v0.2
- Interactive house/decor screen
- Character style/outfit screen
- Cooking mini-game with one-time recipe rewards
- Daily adventure/task system
- Coins + stars progression economy
- Persistent local save game via UserDefaults + Codable
- Permanent ownership for purchased decor/outfits (no repeat charging)
- Reset-ready save architecture
- iPhone + iPad target
- Unit tests for rewards, ownership, persistence, and one-time recipe rewards

## Run
1. Install Xcode 26+ and XcodeGen (`brew install xcodegen`).
2. In this folder run `xcodegen generate`.
3. Open `DreamLifeHouse.xcodeproj`.
4. Select an iPhone/iPad simulator and Run.

## Product direction
Next milestones: multi-room world, avatar creator, drag/drop props, pet system, pool/garden, parental gate, StoreKit 2, localization, original art/audio, accessibility, App Store privacy metadata.

## v0.4
- Persistent original character profile: name, hair style, hair color, skin tone and accessory.
- New Character Creator tab with live preview and option pickers.
- Character name appears inside the house so the avatar identity follows room exploration.
- Character option validation, name sanitization and persistence regression tests.


## v0.5
- Interactive room actions: sleep, dance, shower, snack and garden play.
- Persistent Energy/Fun/Hygiene/Hunger needs model with 0...100 clamping.
- House HUD displays current needs and room-specific action.
- Regression tests cover interaction routing, clamping and persistence.


## v0.6
- Daily Adventures now unlock from real gameplay state instead of manual completion.
- Persistent room interaction counters support multi-step challenges.
- Added regression tests for interaction counters and duplicate task rewards.


## v0.7
- Drag the character freely inside each room; positions persist independently per room.
- Rooms now have two independent decor placement slots (Main + Side).
- Decor-slot validation prevents invalid placements from spending coins.
- Added persistence/clamping regression tests for character movement and multi-slot decor.

## v0.8
- Contextual drag-and-drop activity zones: dropping the character onto room-specific zones now triggers sleep, dance, snack, shower, or outdoor play.
- Character movement now commits on drag end to avoid excessive persistence writes while dragging.
- Added regression coverage for contextual drops, non-activity drops, and persistence.


## v1.1
- Morning / afternoon / evening daily-life cycle
- End-of-day character and pet need decay
- Ordered three-step daily chain with streak bonuses
- Persistent day, phase, chain and streak progress

## v1.3
- Added an original Friends/NPC system with Luna, Rio and Ivy.
- Friends can be invited to hangouts; dance, decorating and garden activities build persistent friendship XP and levels.
- Favorite activities grant bonus XP and coin rewards; social progress and active friend persist across launches.
- Added Friends tab and three social regression tests.

## v1.5
Added persistent player settings for sound, haptics, reduced motion and purchase confirmation, plus a dedicated Settings tab and regression coverage for persistence/reset behavior.

## v1.6 production hardening
Added a three-step first-launch onboarding flow, persistent onboarding completion, accessible step/button labels, and save-game recovery using a last-known-good backup. Corrupt primary save data now falls back to the backup and restores the primary automatically.


## v2.12
- Room Surprise rotates a hidden daily activity through all five house rooms.
- Correct room play unlocks a one-time 25 coin + 1 star reward.
- Daily reset and wrong-room behavior are covered by regression tests.

- Surprise Buddy connects daily Room Surprise discoveries with rotating friend moments and one-time rewards.

## v2.33 — Crown Spark Weekly and Comet Veil
- Earn 3 Crown Spark moments on different game days in a single game week for a weekly reward.
- Claim the original Comet Veil accessory after 7 lifetime Crown Spark moments; equip it in Dress Up.
- House content now scrolls vertically to keep the growing quest list accessible on smaller screens.
- Run the Linux gameplay smoke checks with `bash Tools/run_model_smoke.sh` (requires Swift); see `V2.33_TEST_REPORT.md` for the limits of this verification.

## v2.34 — Playability repair and Comet Halo
- Fixed missing House buttons for Radiant Chime and Lumen Canopy. These now enable the Lightkeeper and Crown Spark quest chains through normal gameplay.
- Crown Spark Collection tracks claimed weekly rewards, with a 3-week Comet Halo decoration milestone (+110 coins, +4 stars). Comet Halo can be admired in the Living Room.
- Comet Veil has a reduced-motion-aware glow preview in Dress Up.
- Run `bash Tools/run_model_smoke.sh` and `python3 Tools/check_house_wiring.py` for offline verification. See `V2.34_TEST_REPORT.md` for limitations.

## v2.35 — Newer-save protection and accessible late-game actions
- A save created by a newer app version is **never overwritten** by an older build, even when a compatible older backup exists. Older builds show a visible accessible warning and allow non-persistent preview play; installing the newer build preserves the original save.
- Truly corrupt primary saves still recover from a compatible backup and remain writable.
- Improved VoiceOver hints, unique accessibility identifiers for late-game claim actions, and frequently updated House action feedback.
- Added three save-integrity XCTest regression methods (170 total), 69 Linux model smoke assertions, and 18 static UI wiring checks. Real iOS Xcode build/UI tests are still outstanding.

## v2.36 — Future-backup protection and claim accessibility
- Preserve newer-schema backup data during ordinary saves from a compatible primary; if no compatible save exists, avoid overwriting a newer backup and use read-only preview mode.
- Give six additional Radiant/Lightkeeper/Comet reward claim controls distinct VoiceOver labels and UI identifiers.
- `bash Tools/run_model_smoke.sh` runs 69 prior + 15 new Linux model assertions; `python3 Tools/check_house_wiring.py` verifies 24 static UI contracts.
- See `V2.36_CHANGELOG.md` and `V2.36_TEST_REPORT.md` for details and unverified iOS release gates.

## v2.37 — Unknown-save-schema protection
- Preserves primary and backup saves when their explicit schema version is unrecognized or malformed, rather than treating them as legacy. A genuinely absent schema marker remains migratable.
- Detects a future-format primary that replaces the current save during the same session before writing.
- Clearer read-only preview warning, six new XCTest source methods (180 total), 108 Linux smoke assertions and 25 UI wiring checks.
- Run `bash Tools/run_model_smoke.sh` and `python3 Tools/check_house_wiring.py`. See `V2.37_TEST_REPORT.md` for limitations.

## v2.38 — interrupted-save recovery
- Save commits now stage a complete snapshot in `save.pending` before updating backup and primary keys. On launch, a valid pending snapshot finishes an interrupted commit.
- A corrupt primary is no longer eligible to rotate over a known-good backup. After backup recovery, the first subsequent gameplay write retains the original backup.
- A pending save with a future or unrecognized schema is preserved and triggers read-only preview mode rather than being overwritten.
- Adds 8 XCTest source tests (188 total) and 23 runnable Linux model assertions (131 total).
- Run `bash Tools/run_model_smoke.sh` and `python3 Tools/check_house_wiring.py` to reproduce offline checks.
- **Note:** UserDefaults is not a transactional database and does not guarantee a durable multi-key fsync. Staging reduces interrupted-write exposure but is not a full atomic filesystem commit.
- iOS build, XCTest runtime, Simulator and physical-device tests remain outstanding. See `V2.38_TEST_REPORT.md`.

## v2.39 — ordered save-journal recovery
- Adds backward-compatible monotonic commit sequences to prevent stale pending-save rollback.
- Recovery prefers a newer compatible backup over an older pending journal, while retaining legacy journal migration.
- Adds seven XCTest regressions and 24 executable Linux model assertions. See `V2.39_CHANGELOG.md` and `V2.39_TEST_REPORT.md`.

## v2.40 — interrupted-backup recovery, stale-session protection, UI-test target
- Fixes a data-loss case where a newer valid backup could be ignored when no pending journal existed; recovery now selects the newer backup and preserves it.
- Pending replay retains an intermediate backup if that backup is newer than the old primary.
- A stale running game instance cannot overwrite another instance's newer compatible save, a same-sequence external edit, or an externally staged journal. A visible VoiceOver-accessible warning instructs players to restart and load current progress.
- Includes two XCUITest source cases (fresh onboarding and newer-save warning) and a DEBUG-only isolated test save domain; the normal player save is never reset by test fixtures.
- `xcodegen generate && xcodebuild -project DreamLifeHouse.xcodeproj -scheme DreamLifeHouse -destination 'platform=iOS Simulator,name=iPhone 16' test` is an **example** Xcode test command; select a simulator installed on your Mac. Real Xcode tests have not been run in this Linux environment.
- Offline verification: `bash Tools/run_model_smoke.sh` and `python3 Tools/check_house_wiring.py`. See `V2.40_TEST_REPORT.md`.

## v2.41 — House Adventure reward hardening and UI tests
- Four adventure claims now validate the actual gameplay prerequisites and fixed reward amounts inside `GameStore` (not only through disabled buttons). Duplicate/unknown/unearned claims are rejected.
- Adventure controls and the coin balance have stable VoiceOver-friendly accessibility identifiers. Added isolated DEBUG fixtures for a ready dance reward, persistent relaunch, and external-save conflict.
- Five XCUITest source cases cover onboarding, newer-save warning, external-save warning, locked rewards, and dance reward claim/persistence. They require Xcode to execute.
- Offline verification: `bash Tools/run_model_smoke.sh` (206 executable assertions), `python3 Tools/check_house_wiring.py` (34 contracts). See `V2.41_TEST_REPORT.md`.

## v2.42 — Verified item prices and side-slot Adventures
- Adventure decoration readiness now accepts valid placed items in either Main or Side slot, including after save/reload. The model and UI share one readiness predicate.
- Item and outfit purchases verify exact catalog records (including price) before charging or granting ownership; fabricated cheaper items cannot bypass the economy.
- Rainbow Cupcake rewards are fixed to the implemented recipe and 75 coins + 1 star; unknown recipes or caller-supplied inflated rewards do not mint currency.
- House Adventures uses a fully scrollable, vertically stacked layout to keep claim controls reachable on narrow iPhones and with larger text sizes.
- Adds seven XCTest source cases, one XCUITest source case, and 33 executable Linux model assertions. See `V2.42_TEST_REPORT.md` for test limits and pending iOS validation.

## v2.43 — Extreme-save arithmetic hardening
- Oversized/corrupt-but-decodable local progress counters are bounded before gameplay uses them.
- Currency grants and activity counters use saturating arithmetic to avoid integer-overflow crashes.
- New XCTest cases, Linux model smoke checks and a DEBUG-only UI fixture cover oversized restores and safe navigation.
- Details and verification limits: `V2.43_CHANGELOG.md`, `V2.43_TEST_REPORT.md`.

## v2.44 — Terminal save-journal safety
- A save with `commitSequence == Int.max` is now a **valid, readable terminal save** rather than being discarded as corrupt.
- The game preserves terminal saves and displays a read-only warning instead of overflowing the integer sequence or rolling back to an older backup.
- When a save is at `Int.max - 1`, loading it does not consume the last available commit; the next gameplay write can commit once at `Int.max`.
- Interrupted terminal writes and terminal backup recovery are tested; see `V2.44_TEST_REPORT.md`.
- This is an extreme restored-save edge case. It does not guarantee filesystem durability on sudden power loss or replace on-device iOS testing.

## v2.45 — Ambiguous save conflict protection
- Equal-sequence but byte-different pending/backup saves are **not** automatically ordered if the committed primary is missing, invalid or older. The game previews the backup read-only while preserving all original on-disk save candidates for recovery.
- A VoiceOver-addressable warning explains that new progress will not be saved until the conflict is resolved. This is a rare corruption/restoration scenario, not normal gameplay.
- Five new model XCTest source methods, a Linux smoke suite and an XCUITest source case cover the conflict. See `V2.45_CHANGELOG.md` and `V2.45_TEST_REPORT.md`.

## v2.46 — Parent-controlled recovery export
- Ambiguous save conflicts can now be exported from Settings by a parent without overwriting the primary, backup, or pending journal.
- The exported JSON contains all three **raw** save slots, Base64-encoded, including corrupt or missing primary bytes, plus a version and reason. It does not resolve or import conflicts.
- Added a SwiftUI Files document exporter, a guarded Settings button, four XCTest source cases, a UI test source case and Linux model smoke coverage.
- Recovery exports contain personal game progress; only share them with a trusted adult.
- The game's planned feature scope remains 100%, but iOS device and App Store readiness have not been verified.


## v2.47 — Recovery export integrity checks
- Recovery exports now use format v2, with per-slot CRC32 + byte-count checksums. Missing and empty slots have distinct markers.
- Format v1 archives remain decodable but are labeled **legacy/unverified**. Unsupported versions, swapped slots, missing checksums and damaged bytes are rejected by the validator.
- `python3 Tools/verify_recovery_archive.py path/to/export.json` verifies an exported file offline without uploading or printing its gameplay data. Checksums detect accidental damage; they do **not** provide encryption or authenticity.
- The parent-facing export explanation now states these limits. No automatic import or merge has been added.

## v2.48 — Parent-facing recovery previews
- When a journal conflict locks saves, Settings lists **Primary / Backup / Pending** summaries (readable/missing/corrupt/newer-format; sequence, coins, stars and completed tasks where readable).
- These previews never change saved bytes or select a winner. A parent can still export the three original copies for offline verification.
- Model tests and UI source contracts are included; Xcode device/simulator validation remains outstanding. See `V2.48_CHANGELOG.md` and `V2.48_TEST_REPORT.md`.

## v2.49 — Equal-sequence primary/backup recovery
- When primary and backup contain **different** readable snapshots with the same positive journal number and no pending journal, preserve both and enter read-only recovery preview instead of overwriting either copy.
- Detect a newly introduced primary/backup conflict before saving from an already-running session.
- Existing parent-facing preview and local export now support this case; no automatic merge/restore or cloud upload.
- Five new XCTest source tests, one UI test source case, 26 new runnable Linux assertions, and expanded wiring checks. See `V2.49_CHANGELOG.md` and `V2.49_TEST_REPORT.md`.

## v2.50 — Equal-sequence pending journal protection
- Prevented an interrupted journal with the same positive sequence but different bytes from being discarded as stale.
- Such conflicts now preserve every raw candidate and enable parent-only preview/export in read-only mode.
- New isolated UI fixture and Linux regression tests protect both fresh loads and external edits during gameplay.
- See `V2.50_CHANGELOG.md` and `V2.50_TEST_REPORT.md` for results and platform limitations.

## v2.51 — Preserve all three save copies when a journal masks a conflict
- Fixed a v2.50 recovery bug: an older or newer pending journal could hide a same-sequence primary/backup conflict, deleting a valid save candidate.
- The loader and active-session writer now lock this ambiguous state before any journal cleanup or backup rotation; all three raw copies remain available for parent review/export.
- Added a three-way UI-test fixture, five XCTest source cases and 24 runnable Linux assertions. See `V2.51_CHANGELOG.md` and `V2.51_TEST_REPORT.md`.

## v2.52 — Inspection-bound recovery export
- The parent recovery screen now captures an explicit read-only inspection session. Export requires the same token and checks that the **exact bytes** of primary, backup and pending still match what was inspected, including invisible fields.
- A changed copy invalidates export; the parent is asked to refresh and review again. Refresh revokes the old token. The export button is disabled until a valid inspection exists.
- This is best-effort cross-session consistency with UserDefaults, **not** an atomic multi-process transaction. Recovery exports are not encrypted and CRC32 is not authentication.
- Added five XCTest source methods, one XCUITest source method, 20 executable Linux model assertions, and seven static wiring contracts. See `V2.52_CHANGELOG.md` and `V2.52_TEST_REPORT.md`.

## v2.53 — Exact-copy hints in parent recovery inspection
- Primary, Backup and Pending rows now identify other present slots with **identical raw bytes**. Absent slots never appear as matches; corrupt but byte-identical copies can still be recognized.
- Comparison text is VoiceOver-accessible, uses the inspection's already captured bytes and does not change, restore or choose any save. Parents are reminded that different bytes cannot establish which save is correct.
- A dedicated UI fixture and regression suites cover identical, different, absent and corrupt copies. See `V2.53_CHANGELOG.md` and `V2.53_TEST_REPORT.md`.

## v2.54 — Parent recovery overview and explicit private export confirmation

- Parent recovery inspection now displays present, distinct, readable, damaged and newer-version copy counts from the same captured bytes used by the export. This overview is accessible to VoiceOver.
- Export requires an explicit privacy confirmation, followed by a fresh exact-byte validation before opening Files. The archive can contain player data and is not encrypted; the dialog is not an adult identity check.
- `bash Tools/run_model_smoke.sh` now runs all v2.33–v2.54 Linux model smoke suites concurrently in isolated binaries, followed by the archive verifier, Python tests and static UI checks. See `V2.54_CHANGELOG.md` and `V2.54_TEST_REPORT.md`. Actual Apple-platform testing remains pending.

## v2.55 — Interleaved save-write protection
- A running game now refuses to overwrite an already-present pending journal from another session, including an undecodable journal.
- Immediately after staging its own journal, it verifies that primary and backup still match the captured bytes; after backup rotation, it checks again before committing primary.
- If a detected race forces an abort, the game enters external-change read-only mode and removes only its own unchanged staged journal, never a different pending payload.
- Legacy corrupt-journal cleanup remains available at startup only when a readable committed copy exists and there is no ambiguous or newer-schema conflict.
- Five XCTest source cases and 24 Linux model assertions cover deterministic interleavings; see `V2.55_CHANGELOG.md` and `V2.55_TEST_REPORT.md`.
- **Limit:** UserDefaults does not provide an atomic cross-process compare-and-swap. These extra checks reduce, but cannot eliminate, write races. Apple-device tests are still required.


## v2.56 — Build fixes, App Store assets and visual redesign
- Fixed UI compile errors (TopBar title parameter, Color/Material ternaries) and split oversized SwiftUI expressions.
- Added app icon, launch screen, iPad orientations and export-compliance key.
- New pastel theme, drawn character that reflects the creator choices, illustrated rooms, 5-tab layout.
- Purchase confirmation, sound and haptics settings now work. See `V2.56_CHANGELOG.md`.
