# Film Space — Session Handoff

**Project:** `/Users/avinash/Desktop/MediaHouseOS/film-your-space` (Xcode project: `film space.xcodeproj`, target `film space`)
**Stack:** Swift, SwiftUI, RealityKit (no SceneKit anywhere in this project), ARKit, iOS 18.0 min deployment.
**Build verification method used throughout:** `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project "film space.xcodeproj" -scheme "film space" -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator build`. No simulator UI-automation tool is available in this environment — every fix in this session was verified by compiling, not by tapping through the app. **Manual on-device/simulator testing is still owed for most of the work below.**

---

## ⚠️ Git status — nothing from this session is committed

```
834e744 Savepoint: working 4K warehouse before mannequin overhaul   <-- HEAD, last real commit
6b59386 Prepare app for TestFlight with iOS 18 support...
```

Everything described in this document happened **after** `834e744` and is still sitting uncommitted in the working tree. Current `git status --short`:

```
 D film space/Assets.xcassets/warehouse360.imageset/Contents.json
 D film space/Assets.xcassets/warehouse360.imageset/warehouse360.png
 M film space/ContentView.swift
 M film space/Models/SceneState.swift
 M film space/Services/HumanFigureFactory.swift
 D film space/Services/LocationEnvironmentFactory.swift
 M film space/Services/SceneContentBuilder.swift
 M film space/Services/SceneEnvironment.swift
 M film space/Views/ARCameraView.swift
 M film space/Views/LocationPreviewView.swift
 M film space/Views/StudioToolbar.swift
 M film space/Views/VirtualStudioView.swift
?? film space/Models/RoomLayout.swift
?? film space/Services/CameraContentBuilder.swift
?? film space/Services/CameraNodeFactory.swift
?? film space/Services/RoomEnvironmentBuilder.swift
?? film space/Services/RoomLayoutProcessor.swift
?? film space/Views/CameraPanel.swift
?? film space/Views/CameraViewfinderView.swift
```

**Next step for whoever picks this up:** once manual testing below passes, commit. Nothing has been pushed.

---

## Current app structure (4 tabs)

`ContentView.swift` hosts a native `TabView(selection: $sceneState.mode)` with tabs in this order: **Location → Character → Camera → Motion** (`AppSection` enum in `SceneState.swift`). `SceneState` (`@Observable`) and `OrbitCameraController` are owned once by `ContentView` and passed by reference into tabs, so character/camera data (not the render entities — see architecture note below) persists across tab switches.

- **Location** (`LocationPreviewView.swift`) — upload a room photo, generates a 3D room layout, lets you review/delete false-detection props.
- **Character** (`VirtualStudioView.swift` + `CharacterControlPanel`-equivalent controls in `ContentView.swift`) — place/pose/tilt/lift mannequins.
- **Camera** (`CameraViewfinderView.swift` + `CameraPanel.swift`) — place/aim/lens virtual cameras, preview through them, capture PNG storyboards.
- **Motion** (`ARCameraView.swift` + `StudioToolbar.swift`) — the original handheld AR-style camera + video recording (unchanged core logic, just relocated/renamed from "Camera" to "Motion").

---

## What was completed this session (chronological)

### 1. Character name tags
- `Services/NameTagFactory.swift` — floating billboard card (RealityKit `BillboardComponent`) always facing camera, rendered above each character's head.
- Wired into `Services/SceneContentBuilder.swift` sync logic.

### 2. Character pose system (10 poses)
- `Models/SceneState.swift` — `CharacterPose` enum: Standing, Sitting, Kneeling, Lying, Crouch, Lean, Fall, Stance, Sprint, Walk.
- `Services/HumanFigureFactory.swift` — full joint-rig rewrite: hip→knee→ankle leg chains and shoulder→elbow arm chains (each pose defined as hip/knee/ankle/shoulder/elbow angles in a `PoseRig`/`LegRig`/`ArmRig` struct).
- **Key decision:** floor-grounding is computed generically from actual mesh bounds after posing (`SceneContentBuilder` rotates the bounding box corners and grounds to the lowest point), not hand-tuned per pose — this made adding new poses cheap and robust.
- **Mannequin mesh overhaul:** replaced box-and-stick limbs with `MeshResource.generateCylinder` segments + sphere "ball joints" at every pivot (shoulder/elbow/hip/knee/ankle) for clean deformation with no gaps. **Note:** `MeshResource` has **no** `generateCapsule` in this SDK (only `ShapeResource` does, for collision) — confirmed by inspecting the actual `.swiftinterface`; don't reach for it again.

### 3. Character tilt/lift/sway gestures
- `HumanPlacement` gained `tiltPitch`, `tiltRoll`, `liftHeight` fields.
- Sway (pitch/roll) pivots at a **ground-level hinge**, not the mesh's own origin — a two-level rig (`HumanHinge` → `HumanFigure`) in `SceneContentBuilder.swift` so leaning genuinely pivots from a planted foot instead of the whole body floating to dodge floor-clipping.
- Lift is clamped `>= 0` (can raise, never sink below floor) in `SceneState.liftSelectedHuman`.
- **Key bug fixed twice this session:**
  - Gesture-priority bug: hold-buttons using raw `.gesture(DragGesture)` were losing touches to the RealityView's own full-screen gestures underneath. Fixed by switching to `.highPriorityGesture` — applied to `StudioToolbar`'s rotate/vertical/joystick controls and all new character adjustment buttons.
  - Floor-grounding bug (see item 9 below) — drag handler was hardcoding Y to 0 instead of preserving/computing relative-to-floor height.

### 4. UI redesign attempt — reverted
- A hand-drawn-sketch-driven redesign consolidated all Character-tab controls into one big card; user rejected it ("built a full modal... can't see characters," icons replaced with text against instructions). **Reverted in full** back to individual floating buttons/pills at the screen edges (left cluster: rotate/add/delete/lift; right cluster: sway D-pad/joystick/up-down/lock), matching the original established visual style. Current `ContentView.swift`/`StudioToolbar.swift` reflect this reverted (working) state — do not redo the "single card" layout without new explicit direction.

### 5. Location module — 360° warehouse sphere (built, then fully removed later)
- Originally built as a RealityKit sphere (`LocationEnvironmentFactory`, since **deleted**) with a `warehouse360` texture (asset since **deleted**), `faceCulling = .none` for inside-out rendering. This entire feature was later ripped out per explicit instruction (see item 8).

### 6. Four-tab navigation restructure
- Renamed `AppMode` → `AppSection` with the Location/Character/Camera/Motion cases described above.
- `StudioToolbar.swift` simplified to Motion-only (rotate/add/delete/joystick moved to Character-tab-local controls).

### 7. Camera tab — multi-camera "virtual production" viewfinder
- `Models/SceneState.swift` — `CameraPlacement` (position, `rotationY` yaw, `rotationPitch` pitch, name, `lens: CameraLens`), `CameraLens` enum (24/35/50/85mm, **vertical** FOV computed from a fixed 24mm sensor height — this is the RealityKit equivalent of `SCNCamera.focalLength` + `sensorHeight`, since this project has no SceneKit).
- `Services/CameraNodeFactory.swift` — camera prop visual: **not** a solid box (that blocked its own lens when active — see bug below) but a small semi-transparent wireframe frustum (built from thin `addLine`-style box segments) with the apex at the camera's eye point.
- `Services/CameraContentBuilder.swift` — syncs camera nodes + name tags; no longer rebuilds on selection (visuals don't depend on selection state — see next item).
- `Views/CameraViewfinderView.swift` — `ARView`-backed (`UIViewRepresentable`, `cameraMode: .nonAR`), reused for `ARView.snapshot` capture capability. RealityKit has no `SCNView.pointOfView`-style switch, so selecting a camera snaps the one live render camera's transform + `PerspectiveCameraComponent` to the selected `CameraPlacement`'s data.
- `Views/CameraPanel.swift` — camera list (tap to select + lock POV), rename field, lens selector, move/rotate D-pad (relative to camera's own facing), height arrows, "Capture Storyboard" button (`ARView.snapshot` → PNG via `PHPhotoLibrary`, mirroring the existing `SceneRecorder` save-to-Photos convention).
- **Bugs fixed in this subsystem:**
  - Camera's own opaque mesh blocked its own view when active → now **all** camera helper nodes/name-tags are hidden (`Entity.isEnabled = false`) whenever any camera is the active viewpoint, and force-hidden again immediately before every `captureStoryboard()` snapshot (restored right after), independent of current lock state.
  - No way to drag/reposition cameras → added tap-to-select + pan-to-move (relative to the camera's own facing) via dedicated `UIGestureRecognizer`s on the `ARView`.
  - Camera height was fixed → added `SceneState.updateCameraHeight` (Y-only, clamped `>= 0`) and up/down arrow buttons (replaced an earlier vertical slider per explicit request — "clean on-screen overlay arrows" instead).
  - No pitch/yaw control → two-finger pan gesture (`UIPanGestureRecognizer` capped to exactly 2 touches, separate from the one-finger move/orbit pan capped to 1 touch so they can't compete) drives `SceneState.adjustSelectedCameraAim(yawDelta:pitchDelta:)`, with pitch clamped to ±85° to avoid flipping past vertical.

### 8. Warehouse removal + image-driven 3D room pipeline
- **Deleted:** `Services/LocationEnvironmentFactory.swift`, `Assets.xcassets/warehouse360.imageset/` (both files). Confirmed via repo-wide grep: zero remaining references to "warehouse"/"Skybox"/"LocationEnvironmentFactory".
- **New:** `Models/RoomLayout.swift` — `Codable` struct: `roomDimensions` (width/length/height), `detectedProps: [Prop]` (`type: String`, `position: SIMD3<Float>`, `scale: SIMD3<Float>`, plus an `id: UUID` for selection).
- **New:** `Services/RoomLayoutProcessor.swift` — **explicitly a stub** (the user asked for exactly this): takes a `UIImage`, generates a plausible mock `RoomLayout` on a background queue, calls back on main. This is the seam where real computer vision / a server call would eventually go. Do not mistake the mock furniture placement for real detection.
- **New:** `Services/RoomEnvironmentBuilder.swift` — the scene-clearing routine. Owns exactly one child of the shared studio root, named `"EnvironmentGeometry"`; purges/rebuilds only that node, leaving character hinges / camera nodes / name tags (separate siblings, each tagged by their own component) untouched. Falls back to the original default grid when `roomLayout == nil`. Dedups via an `EnvironmentLayoutComponent` (`Equatable`) so repeated syncs with the same layout are cheap no-ops.
- `Services/SceneEnvironment.swift` — slimmed down to just shared color constants + an empty root factory; grid-building logic moved into `RoomEnvironmentBuilder`.
- `Models/SceneState.swift` — added `var roomLayout: RoomLayout?`, the shared session state that Character/Camera/Motion all read via `RoomEnvironmentBuilder.sync(layout:into:)` in their respective view/coordinator update methods.
- `Views/LocationPreviewView.swift` — fully rewritten: native `PhotosPicker` "Upload Location Image" button, a `ProcessingOverlay` while the stub runs, live 3D preview of the result.

### 9. Character-disappears-on-tab-switch bug — root cause found and fixed
- **Initial (wrong) hypothesis, started then reverted mid-way:** built a "single persistent shared RealityKit scene" architecture (`SceneState.worldRoot` + `attachWorldRoot`) on the theory that each tab's independently-rebuilt scene copy was desyncing. **User interrupted with the actual diagnosis before this was finished; it was fully reverted** (`SceneState.swift` and `VirtualStudioView.swift` restored to their pre-refactor state, confirmed by rebuilding). **Do not resurrect this half-finished approach without new direction** — the three tabs (Character/Camera/Motion) still each independently call `SceneEnvironment.makeStudioRoot()` + sync from the same `SceneState` data; that per-tab-independent-copy architecture is intentional/current and was not the actual bug.
- **Actual root cause:** `VirtualStudioView`'s drag handler hardcoded `newPosition.y = 0` on every drag update, unconditionally resetting the stored Y position to a literal world-origin value rather than preserving it or computing it relative to the actual floor.
- **Fix applied:**
  - `Services/RoomEnvironmentBuilder.swift` — tags one entity `"RoomFloor"` (`floorReferenceName`) in both the default grid and every generated room.
  - `Services/SceneContentBuilder.swift` — new `floorHeight(in:)` looks up that entity via `findEntity(named:)` + `position(relativeTo:)`; `applyTransform` now grounds each character at `floorHeight + placement.position.y + liftHeight` instead of assuming world Y=0. This is centralized, so it applies to Character/Camera/Motion automatically.
  - `Views/VirtualStudioView.swift` — drag handler now sets `newPosition.y = start.y` (preserve, don't reset) and re-applies the position on `.onEnded` as a defensive final clamp.
  - `Models/SceneState.swift` — `updateHumanPosition` now clamps `position.y = max(0, ...)` universally.
  - Audited `selectHuman(id:)` — confirmed it never touches `position` (no separate deselect-reset bug existed).

### 10. Prop cleanup (tap-to-select-and-delete false detections)
- Scoped to the **Location tab only** (deliberate choice — Character/Camera tabs already claim tap gestures for their own selection).
- `Services/RoomEnvironmentBuilder.swift` — props now carry `RoomPropComponent` (`propID`, `baseColor`) + `CollisionComponent`/`InputTargetComponent` (they had neither before — not tappable at all). Selected prop is tinted `systemYellow`; `updatePropHighlight` restores `baseColor` on deselect without needing a full rebuild.
- `Models/SceneState.swift` — `selectedPropID`, `selectProp(id:)`, `deleteSelectedProp()` (removes from `roomLayout.detectedProps`).
- `Views/LocationPreviewView.swift` — `SpatialTapGesture` (high priority) to select a prop, plain `TapGesture` to deselect on empty space (mirrors the exact pattern already used for character selection in `VirtualStudioView`), a small bar (prop type label + trash button) appears on selection.

---

## Key architectural decisions worth knowing before continuing

1. **No SceneKit anywhere.** When a request mentions `SCNView`/`SCNCamera`/`PHPickerViewController` etc., translate to the RealityKit/PhotosUI equivalent and say so — don't assume SceneKit is present.
2. **Per-tab independent scene copies, shared data.** Character/Camera/Motion each build their own `Entity` root and independently call `SceneContentBuilder.syncHumans` / `CameraContentBuilder.syncCameras` / `RoomEnvironmentBuilder.sync` from the *same* `SceneState`. This is the current, working architecture — confirmed intentional after the "single shared scene" detour was reverted.
3. **Floor is not assumed to be world Y=0 anymore.** Any new code that positions/grounds something relative to the floor should go through `SceneContentBuilder.floorHeight(in:)` (or the `RoomEnvironmentBuilder.floorReferenceName` tag directly), not a hardcoded 0.
4. **`.highPriorityGesture` is required** for any custom SwiftUI button/control overlaid directly on a RealityView or ARView — plain `.gesture()` will lose touches to the 3D view's own full-screen gestures. This bit us twice; use `.highPriorityGesture` by default for new overlay controls in this app.
5. **This environment cannot run the simulator interactively** — no UI-automation tool is available. All verification in this session was `xcodebuild` compilation only. Several APIs assumed-then-disproven this session: `MeshResource.generateCapsule` (doesn't exist — use `generateCylinder`), `SceneKit` types (don't exist in this project at all). Double-check RealityKit API surface against the actual `.swiftinterface` under Xcode's SDK before assuming a method exists, rather than trusting memory.
6. **Xcode toolchain location for builds in this environment:** `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` (not on `$PATH` by default — `xcode-select` points at Command Line Tools only).

---

## Next steps (what we were planning to do / should do next)

1. **Manual testing pass (highest priority, nothing in this session has been tapped-through)**, specifically:
   - Character: add/pose/tilt/lift/sway/rotate a mannequin; confirm no gesture is dead due to priority conflicts.
   - Camera: add a camera, select it from the list (confirm view isn't blocked by its own geometry), drag it, two-finger pitch/yaw it, adjust height with the arrows, capture a storyboard PNG and confirm it lands in Photos with no frustum/gizmo visible in frame.
   - Location: upload a photo, confirm the mock room generates, confirm the room appears in Character/Camera/Motion after switching tabs, tap a prop to select/highlight it, delete it, confirm it's gone everywhere.
   - Cross-tab: add a character in Character tab, switch to Camera then Motion then back — confirm it never disappears and stays correctly grounded (this was the just-fixed bug).
2. **Commit the work.** Nothing since `834e744` is committed. Suggest committing in logical chunks (poses/gestures, camera tab, warehouse removal + room pipeline, floor-grounding fix, prop cleanup) or as one large "post-savepoint" commit if the user prefers — ask which.
3. **`RoomLayoutProcessor` is a stub by design.** The next real step here (whenever the user wants it) is swapping the mock `mockLayout(for:)` function for a real vision model or backend call — the function signature (`UIImage` in, `RoomLayout` completion out) was deliberately kept simple so only that one function needs to change.
4. **Prop cleanup is Location-tab-only.** If the user wants to delete false-detection props from Character or Camera tabs too, that needs new tap-gesture wiring there (currently those tabs' tap gestures are claimed by character/camera selection).
5. **Open question, not yet re-raised:** whether a genuinely single shared RealityKit scene (vs. the current per-tab independent copies synced from shared data) is still wanted for some other reason. It was explored and reverted specifically because it wasn't the fix for the disappearing-character bug (that turned out to be the floor-grounding bug instead) — but the user never said the *idea* itself was unwanted, only that it wasn't the right fix at that moment. Worth confirming before ever revisiting it.
