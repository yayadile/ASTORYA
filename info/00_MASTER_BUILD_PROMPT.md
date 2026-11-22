# MASTER BUILD PROMPT — ASTORYA

Build the complete native Android application **ASTORYA** from the files contained in this `ASTORYA_AI_BUILD_PACK_v1.0` folder.

## Non-negotiable instruction

Before writing code, read **every file** under `specs/`, `data/`, and `README.md`. Treat the supplied reference screenshots and production assets as authoritative inputs. Do not redesign, reinterpret, simplify, rename, omit, or add product features unless a specification explicitly requires it.

ASTORYA is an Android portrait educational AR application integrating:
1. a physical 10-page coloring/story book as Augmented Image targets,
2. physical wayang figures as marker targets for character information,
3. local bilingual Indonesian/English narration,
4. child-friendly UI using the ASTORYA golden-cream visual identity.

## Required technology

Use only the technology defined in `specs/08_TECH_STACK.md`.
Do not replace the platform with Flutter, React Native, Unity, a web app, or another framework.
Do not introduce a backend, login system, cloud database, analytics SDK, or online dependency unless explicitly required.

## Build order

Implement in this order:
1. project foundation and design tokens,
2. local data and repositories,
3. navigation and application state,
4. Splash Screen,
5. Main Menu,
6. Petunjuk,
7. Tentang,
8. camera permission handling,
9. AR scanner shell,
10. ARCore Augmented Images database and marker detection,
11. book-marker-to-scene mapping,
12. wayang-marker-to-character mapping,
13. audio ID/EN,
14. tracking lost/recovery,
15. exit confirmation and lifecycle handling,
16. automated tests,
17. build verification.

## Visual source of truth

For visual appearance, use this priority:
1. supplied reference screenshot for that screen,
2. `03_UI_UX_SPEC.md`,
3. `05_DESIGN_SYSTEM.md`,
4. production image assets,
5. PRD narrative.

Do not invent visual components when a supplied production asset already exists.
Do not add bottom navigation, app bar, hamburger menu, floating action button, cards, gradients, shadows, characters, or decorations that are not shown or specified.

The reference Figma frame is **412 × 917 px**, but implementation must use responsive dp/sp layout rather than hardcoded pixel coordinates.

## Behavioral source of truth

For behavior, use this priority:
1. `09_ACCEPTANCE_TESTS.md`,
2. `02_SRS_ASTORYA.md`,
3. `07_STATE_MACHINE.md`,
4. `06_AR_SPEC.md`,
5. `04_USER_FLOW.md`,
6. `01_PRD_ASTORYA.md`.

If two files appear to conflict, apply the higher-priority source for the affected topic and document the conflict in `BUILD_NOTES.md`. Do not silently reinterpret it.

## Data rules

Use only data defined by the JSON files in `data/`.
Do not hardcode story or character content inside UI composables.
Do not fabricate missing story content.
Do not rename marker IDs, scene IDs, or character IDs.

If a JSON record contains `TODO_FROM_FINAL_CONTENT`, preserve the field as unresolved development data and keep the code capable of consuming the final value later.

## AR rules

Implement image recognition according to `06_AR_SPEC.md` using ARCore Augmented Images.
Book markers and wayang markers use the same AR scanner but produce different domain events and UI states.
Only one content experience is considered active at a time.
Do not restart narration on every AR frame update.
Do not create duplicate anchors for the same active marker.
Respect the tracking-loss grace period defined in `data/app_config.json`.

## Permission rules

Do not create a custom camera-permission onboarding screen unless the specification explicitly requires a rationale after denial.
Pressing `Mulai` checks camera permission. If permission is not granted, invoke the native Android permission flow. If denied permanently, show the specified app-level recovery state with `Buka Pengaturan` and `Kembali`.

## Asset rules

Follow `data/asset_manifest.json` exactly.
Asset filenames in the application must use lowercase `snake_case` without spaces, `&`, or other special characters.
If the user's current asset filename differs from the canonical filename, rename/copy it during project preparation and update references consistently.

Never generate a new logo, emblem, character, background, or ornament if the production asset is provided.

## Quality rules

- No placeholder UI may remain in release build when the corresponding production asset is available.
- No TODO may remain in executable behavior that is covered by the supplied data.
- No screen may be unreachable or dead-ended.
- No duplicated audio playback.
- No crash when permission is denied.
- No crash when a marker is absent or lost.
- No network is required for core operation.
- Keep camera processing off the Compose main UI path where appropriate.
- Keep screen state immutable and event-driven.
- Keep business logic outside composables.

## Completion procedure

Before declaring completion:
1. run a clean build,
2. run unit tests,
3. run available instrumentation/UI tests,
4. execute or document each applicable acceptance test,
5. confirm all routes and back behavior,
6. verify camera permission handling,
7. verify AR session lifecycle,
8. verify marker mapping,
9. verify ID/EN audio exclusivity,
10. verify offline operation,
11. create `BUILD_NOTES.md` listing build commands, unresolved content-only TODOs, tested devices/emulators, and any limitation caused by missing physical AR hardware/assets.

The project is not complete merely because it compiles. It is complete only when it satisfies the specifications and acceptance tests.
