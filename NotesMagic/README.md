# NotesMagic — UX + Dev Starter Blueprint

A practical, opinionated plan to get you building fast in Cursor and shipping a clean native iOS + macOS app in Xcode. This covers UX flows, command palette taxonomy, data model, AI pipeline, and a ready-to-implement project structure.

---

## 0) Cursor ↔ Xcode: the clean workflow

**Goal:** Keep code-generation and refactors in Cursor, keep build, signing, previews, and assets in Xcode. Use Swift Packages so Xcode auto-refreshes without you hand-adding files.

**Repo layout**

```
NotesMagic/
  App/
    NotesMagicApp.xcodeproj
    NotesMagicApp/
      App.swift
      Assets.xcassets
      Info.plist
  Packages/
    Domain/                # Entities, protocols, use cases
    Data/                  # Storage, sync, embeddings
    Features/Editor/       # Editor UI, context bar
    Features/Library/      # Inbox, search, related panel
    Features/Onboarding/
    UIComponents/          # Shared SwiftUI components
    MLKit/                 # On-device inference helpers
  Tools/
    scripts/, swiftlint.yml, swiftformat.yml
  README.md
```

**Why this works**

* You write code in **Packages/** with Cursor. Each subfolder is a Swift Package. Xcode watches Packages and rebuilds automatically.
* The app target in **App/** depends on those packages. No file-dragging in Xcode, less project merge pain.
* Because it’s SwiftUI + Swift Packages, you can build once and deploy to **iOS and macOS** with almost no code changes.

**Setup steps**

1. In Xcode: File → New → Project → *Multiplatform App* → `NotesMagicApp` under `App/NotesMagicApp`.
2. In Xcode: File → Add Packages… → “Add Local…” → select each `Packages/*` folder as a separate Swift Package.
3. Add package products to both iOS and macOS targets (General → Frameworks, Libraries, and Embedded Content).
4. In Cursor, open the repo root, set **Packages** as your working dirs for code-gen. Commit from Cursor, build and run from Xcode.
5. For previews: keep small demo models in each package so SwiftUI Previews compile without the full app.

**File management rules**

* Never create files inside the .xcodeproj from Cursor. Create in `Packages/*` or `App/NotesMagicApp` folders, then Xcode picks them up.
* Keep assets, entitlements, Signing in the **App** target only.

---

## 1) UX pillars

1. **Capture-first**: one primary screen with a big blinking caret, zero chrome until you need it.
2. **Suggestions, not interruptions**: a context bar slides in only when the model is confident.
3. **Views, not databases**: you never set up tables. The app proposes “Topic” views you can pin.
4. **Radical reversibility**: every AI write is a suggestion with a diff and one-tap undo.
5. **Seamless beauty**: minimal typography, generous spacing, fluid gestures, and organic animations create an interface that feels invisible.
6. **Calm presence**: color palette is subdued, actions are whisper‑light, transitions are springy but subtle. The user feels peace, not clutter.

---

## 2) macOS specifics

* **Menus + Shortcuts**: Command palette (Cmd+K) integrates with macOS menu bar and Spotlight-like UX.
* **Windowing**: Support multiple note windows, with the same unified editor view.
* **Drag-and-drop**: Drag text, images, or files from Finder into the note canvas.
* **iCloud Drive integration**: macOS users can drop .md files into the app’s folder and watch them import.
* **Universal purchase**: Ship as a Universal App so one download works across iPhone, iPad, and Mac.

---

## 3) Critical flows

### A) First-run (under 2 minutes)

1. **Welcome**: three bullets, “Write first, structure emerges.” Button: Start.
2. **Choose style**: Keep Raw, Suggest, Auto-organize (you can change later).
3. **Optional import**: Apple Notes, Bear, Markdown. Progress shows “Imported → Titled → Tagged → Linked.” Users can skip.
4. **Personal index**: auto-create three starter views: Projects, Open Questions, People. Each item links back to source notes.

**Success criteria**: user sees at least one helpful suggestion and one pinned view in the first session.

### B) “Organize this” interaction (command palette driven)

1. User invokes Cmd+K or pull down (on macOS: also Cmd+Shift+P style overlay).
2. Palette shows top intents based on the note: Title, TL;DR, Tag, Link to X, Make Topic, Extract Tasks, Make Brief.
3. Selecting an intent renders a staged card with a **diff** and provenance badge. Accept adds annotations, Undo reverts.
4. After acceptance, a toast offers “Pin a view” when relevant.

### C) Editor anatomy

* **Text canvas**: high-performance text view, monospaced option, markdown-lite.
* **Context bar** below the caret: ghosted pills for title, tags, related notes, tasks. Tap to accept or swipe to dismiss.
* **Related panel** (right-edge slide-in): shows 3 most related notes with reason phrases like “mentions Radar, 2 shared tags.”

---

(Other sections remain the same; SwiftUI + Swift Packages mean nearly all code is shared. Only platform tweaks are gestures vs. menus, and iOS vs. macOS windowing.)

---

## 15) macOS support — what to do

You have three good paths. Recommended order depends on how “Mac-native” you want to be.

**A) SwiftUI Multi‑platform (recommended long‑term)**

* Create a **separate macOS App target** that depends on the same Packages. Keep UI in SwiftUI, platform tweaks behind `#if os(macOS)`.
* Pros: best Mac UX (menus, multiple windows, menu bar extra), no UIKit shims.
* Cons: adds a second app target (but still 90% shared code).

**B) Mac Catalyst (fastest to try)**

* Keep the iOS app target and **check “Mac Catalyst”** in the iOS target settings.
* Pros: single target, quickest to see it running on Mac.
* Cons: feels iPad‑on‑Mac until you add Mac affordances; some APIs differ.

**C) Ship both**

* Start on Catalyst for speed, introduce a dedicated macOS target before beta to nail Mac ergonomics.

### Minimal Xcode steps (multi‑platform target)

1. **Add a macOS App target** (App → macOS → App). Name: `NotesMagicMac`.
2. Under `General → Frameworks…`, add the **same Package products** as iOS.
3. **Signing/Bundle ID**: unique bundle id, same team.
4. **Entitlements**:

   * App Sandbox (enabled by default on Mac).
   * `com.apple.security.files.user-selected.read-write` for imports.
   * If using iCloud: iCloud + CloudKit with the **same container** as iOS.
5. **Deployment**: macOS 13+ to get Menu Bar Extra and modern SwiftUI.

### Storage & sync differences

* Use platform‑safe paths:

  ```swift
  let url = try FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask,
           appropriateFor: nil, create: true)
      .appendingPathComponent("NotesMagic", isDirectory: true)
  ```
* On Mac, create the directory if missing; on iOS it’s auto‑created by the system.
* If you support **CloudKit**, use the **same container** and record schemas; your local SQLite remains per‑device cache.

### Keyboard, menus, and windowing (Mac polish)

* Add native menus with SwiftUI \`\`:

  ```swift
  @main struct NotesMagicMacApp: App {
    var body: some Scene {
      WindowGroup { LibraryView() }
      .commands {
        CommandGroup(replacing: .newItem) { Button("New Note", action: newNote).keyboardShortcut("n", modifiers: .command) }
        CommandMenu("Go To") { Button("Command Palette", action: openPalette).keyboardShortcut("k", modifiers: .command) }
      }
    }
  }
  ```
* Support **multiple windows** for Note, Topic View, and Quick Capture (use additional `WindowGroup`s).
* Add a **Menu Bar Extra** (macOS 13+) for Quick Capture:

  ```swift
  #if os(macOS)
  @available(macOS 13.0, *)
  struct NotesMagicMenuBarExtra: Scene {
    var body: some Scene { MenuBarExtra("NotesMagic") { QuickCaptureView() } }
  }
  #endif
  ```
* Make shortcuts first‑class: Cmd+K, Cmd+F, Cmd+N, Cmd+Shift+F (global search), Cmd+Ctrl+L (Toggle AI suggestions).

### Drag & drop and importers

* Support dragging text/files into the editor (`.onDrop` for `UTType.plainText`, `UTType.markdown`).
* Provide **File → Import…** using SwiftUI `.fileImporter` for Markdown/Bear exports.
* Spotlight: index canonical Topic pages with **Core Spotlight** (optional).

### Catalyst‑specific tweaks (if you go that route)

* In target settings, check **“Optimize interface for Mac”**.
* Gate iOS‑only code with `#if targetEnvironment(macCatalyst)`.
* Provide Mac toolbar items via `UIMenuSystem` bridges or SwiftUI `Toolbar`.

### Core ML / embeddings on Mac

* Works out of the box on macOS; you can run **bigger local models**. Put your on‑device model inside a shared resource bundle and load conditionally by platform.

### QA checklist (Mac)

* Menu items and shortcuts work without touching the mouse.
* Multiple windows: open Note in new window, Topic view in another; state restores.
* Drag a `.md` file in → creates a new note and shows enrichment pills.
* CloudKit sync across iPhone ↔ Mac with the same Apple ID.

That’s it — you don’t need a rewrite. Add either a Catalyst checkbox for a quick run on Mac, or a small macOS target that reuses the same packages and you’ll be fully native on both platforms.

---

## 16) Design language — seamless, beautiful, minimal

A small, opinionated system that keeps the product quiet until it’s helpful.

### Core principles

1. **Silence by default**: nothing moves or talks until the user finishes a thought.
2. **One focus**: show one primary action at any moment; the rest is discoverable.
3. **Soft hierarchy**: rely on spacing and weight before borders and color.
4. **Latency is a design element**: if an AI result isn’t confident in <500 ms, stage it as a subtle pill later.
5. **Reversible by design**: every suggestion appears as a diff card with a single, predictable undo.
6. **System-native**: feel like Apple Notes’ calm with the power of a pro editor.

### Layout & spacing

* **Grid**: 8pt base.
* **Spacing scale**: 4, 8, 12, 16, 24, 32, 48.
* **Content width**: 680–760 pt for long-form on Mac/iPad; edge-to-edge on iPhone with 20pt gutters.

### Typography

* **Family**: SF Pro Text / Display.
* **Sizes**: 28/32 (H1), 22/28 (H2), 17/24 (Body), 15/22 (Secondary), 13/18 (Meta).
* **Weights**: Regular for body, Semibold for headings, Medium for interactive labels.
* **Monospace toggle** for drafting: SF Mono 15/22.

### Color

* **Base**: grayscale only in UI; a single **accent** (systemBlue by default).
* **Pills** (tags/suggestions): 6% fill, 24% on hover/focus (Mac), 12% when pending; 0% when dismissed.
* **States**: Success uses subtle tick + accent ring, not green fills. Error uses text + thin border only.
* **Dark mode first**: #0C0C0C background, #EAEAEA primary text, #8A8A8A secondary.

### Motion

* **Context bar**: spring 0.6 / 0.9, 120 ms fade-in, 80 ms fade-out.
* **Diff card**: slide-up 140 ms, easing out; accept animates changed spans with a 200 ms highlight pulse.
* **Related panel**: edge slide 180 ms with overshoot of 8pt.
* **Reduced Motion**: replace movement with cross-fades.

### Components (specs)

**A. Context Bar (beneath caret)**

* Max 3 pills visible; horizontally scrollable.
* Pill anatomy: icon 14, label 13, optional confidence dot (opacity maps to confidence ≥0.7 solid, 0.4 ghosted).
* Interactions: Tap = accept; swipe down = dismiss; hold = preview diff.

**B. Diff Card**

* Title, change preview with added/removed spans, provenance (model, version, time), buttons: Accept (primary), Undo/Close (tertiary).
* Accept animates into the text; card collapses to a toast with “Undo”.

**C. Command Palette**

* Full-width overlay, 560 pt on Mac, 92% width on iPhone.
* Sections: Create / Organize / Understand / Navigate / Control; recent intents pinned at top.
* Keyboard: Up/Down to move; Enter to run top; Tab cycles scope (This Note / All Notes / Topic).

**D. Related Panel**

* Right slide-over, 320 pt. Each item shows reason phrases: “shares 2 tags”, “mentions ‘Radar’”.
* Actions: Open, Merge, Link.

**E. Empty States**

* Editor: “Just start typing.” ghost text. No buttons.
* Library: “No pinned views yet.” + secondary link “Create a Topic view from a tag.”

### Microinteractions catalogue

* **Type pause ≥600 ms** → propose title/tag pills (if confidence ≥0.6).
* **Select text + Cmd+K** → palette scopes to ‘Transform’ actions.
* **Paste Slack URL** → smart paste sheet: “Turn into meeting notes?” with owners/dates extraction.
* **Drag file** (.md or .txt) → inline import preview; dropping commits and shows enrichment pills.
* **Dismissal memory**: if the same suggestion is dismissed 2× in a note, suppress it for that note.

### Copy tone

* **Short, neutral verbs**: “Add title,” “Link notes,” “Make topic,” “Undo”.
* Avoid jargon. Prefer “Linked 3 notes” over “Graph edges created: 3”.
* Show confidence as plain language on hover: “Likely: 78%”.

### Accessibility

* Contrast: 4.5:1 minimum for text; 3:1 for pill labels.
* Target sizes: 44×44 pt min touch; 28×28 pt min on Mac pointers.
* VoiceOver: announce provenance and diff summary, e.g., “Suggested title: ‘Radar Brief’. From local model. Double‑tap to accept.”

### Performance budgets (user‑perceived)

* First keystroke to paint < 16 ms.
* Pause to suggestion pill < 500 ms (local); deep synthesis staged up to 3 s with passive toast.
* Search to results list < 200 ms for local corpus of 1k notes.

### Visual dos & don’ts

* **Do** prefer whitespace and weight to lines and boxes.
* **Do** keep only one accent color; tags inherit a low-sat tint derived from accent.
* **Don’t** stack more than one panel at once (related OR diff, not both).
* **Don’t** use loaders unless work >700 ms; otherwise show optimistic placement.

---

## 17) Sample flows (spec’d)

**Flow 1: Capture → Title**

1. User types 2–3 sentences and pauses.
2. Local model proposes one title pill (ghosted). Tap accepts; hold previews diff that replaces the first line with title and keeps body intact.

**Flow 2: Import → Enrich**

1. User drops a `.md` file. A non-modal strip shows: Imported → Titled → Tagged → Linked. Each step ticks in sequence.
2. At the end, a “Pin Topic view” nudge appears if ≥3 notes share a tag.

**Flow 3: Merge**

1. Related panel shows “3 partials on ‘Fraud Insights’.”
2. Tap Merge → side-by-side diff → Accept merges, writes provenance to the new canonical note.

**Flow 4: Command Palette ‘Organize this’**

1. Cmd+K → top intents sorted by confidence.
2. Enter on ‘Make Topic’ → creates view, opens with subtle anchor highlight on the driving tag.

---

## 18) macOS visual polish checklist

* Native **commands { }** for menus; no custom menu chrome.
* Multiple `WindowGroup`s: Note, Topic, Quick Capture.
* Menu Bar Extra with single‑field Quick Capture.
* Respect system sidebar style and toolbar sizing.

---

## 19) Liquid Glass — minimal, production-safe

**Goal:** keep only what’s needed right now. One tasteful liquid-glass element: the floating **+** button. Everything else stays flat/minimal.

### Glass FAB (only component to add)

```swift
struct GlassFAB: View {
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .font(.system(size: 18, weight: .semibold))
        .padding(16)
    }
    .foregroundStyle(.primary)
    .background(
      Group {
        if #available(iOS 18.0, macOS 15.0, *) {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .glassBackgroundEffect()
        } else {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(.white.opacity(0.12))
    )
    .shadow(radius: 12, y: 8)
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityLabel("New note")
  }
}
```

**Usage** (Library screen):

```swift
ZStack(alignment: .bottomTrailing) {
  LibraryView()
  GlassFAB { createNewNote() }
    .padding(20)
}
```

### Remove / postpone

* No glass search, no glass pills, no toolbar materials.
* Keep list cells flat. Accent is used only for selection/highlight.

### Settings & accessibility (optional but tiny)

* If you have a Settings toggle, add **Reduce Glass** → fallback to `.thinMaterial` or solid fill; otherwise omit for now.

This keeps the app minimal while adding a single, modern touch that’s easy to ship and maintain. Further glass elements can be layered in later if needed.

---

## 20) Essential operations (create • paste • delete)

Ship these now so the product feels complete while staying minimal.

### Data & domain

Add soft‑delete to the schema so Undo/Trash are possible.

```sql
-- Notes table additions
ALTER TABLE notes ADD COLUMN deletedAt REAL; -- unix epoch seconds, NULL if active
```

```swift
protocol NotesStore {
  func create(_ body: String) -> Note
  func update(_ note: Note)
  func trash(_ id: Note.ID) throws       // soft delete: set deletedAt
  func restore(_ id: Note.ID) throws     // clear deletedAt
  func purge(olderThan days: Int) throws // hard delete from Trash
  func activeNotes() -> [Note]
  func trashedNotes() -> [Note]
}
```

* **Behavior**: moving to Trash never asks for confirmation; **Undo** is offered. A background task calls `purge(olderThan: 30)`.

### Library (list) — swipe to delete, Cmd+V paste as new note

```swift
struct LibraryView: View {
  @Environment(\.undoManager) private var undo
  @StateObject var vm: LibraryViewModel

  var body: some View {
    List {
      ForEach(vm.activeNotes) { note in
        LibraryRow(note: note)
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(note) } label: {
              Label("Delete", systemImage: "trash")
            }
          }
          .contextMenu { Button("Delete", role: .destructive) { delete(note) } }
      }
    }
    .toolbar { pasteToolbar() } // optional button; Cmd+V works regardless
  }

  private func delete(_ note: Note) {
    withAnimation { try? vm.trash(note.id) }
    undo?.registerUndo(withTarget: vm) { target in try? target.restore(note.id) }
  }

  @ToolbarContentBuilder
  private func pasteToolbar() -> some ToolbarContent {
    #if os(iOS)
    ToolbarItem(placement: .topBarTrailing) {
      Button { pasteAsNewNote() } label: { Image(systemName: "doc.on.clipboard") }
        .accessibilityLabel("Paste as new note")
    }
    #endif
  }

  private func pasteAsNewNote() {
    #if os(iOS)
    if let s = UIPasteboard.general.string { vm.createFromPaste(s) }
    #elseif os(macOS)
    if let s = NSPasteboard.general.string(forType: .string) { vm.createFromPaste(s) }
    #endif
  }
}
```

* **Keyboard**: Cmd+V in the **Library** creates a new note from the clipboard if the editor isn’t focused.
* **Trash View** (optional, later): a simple list from `trashedNotes()` with **Restore** and **Delete Permanently** actions.

### Editor — native paste, plus “Paste and enrich” hook

* Using SwiftUI \`\` or a wrapped `UITextView/NSTextView`, paste works out of the box.
* Add an optional **smart‑paste** affordance: when pasting, show a non‑modal strip “Paste detected → Enrich?” (turn Slack URLs into notes, extract tasks, etc.).

```swift
struct EditorView: View {
  @Binding var text: String
  @State private var justPasted = false
  var body: some View {
    TextEditor(text: $text)
      .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
        justPasted = true
      }
      .overlay(alignment: .top) {
        if justPasted { PasteEnrichStrip(onDismiss: { justPasted = false }) }
      }
  }
}
```

*(Gate the **`** notification with **`** and use **\`\`** signals on macOS if you want this behavior there.)*

### macOS commands (Delete / Paste)

```swift
.commands {
  CommandGroup(after: .pasteboard) {
    Button("Paste as New Note") { pasteIntoLibrary() }
      .keyboardShortcut("v", modifiers: [.command, .shift])
  }
  CommandGroup(after: .appInfo) {
    Button("Delete Note", role: .destructive) { currentVM.trashCurrent() }
      .keyboardShortcut(.delete, modifiers: .command)
  }
}
```

### QA checklist (basic ops)

* Swipe‑to‑delete deletes with animation, offers Undo, and moves item to Trash.
* Cmd+Backspace deletes the open note on Mac; Delete key works in library selection.
* Cmd+V in editor pastes inline; Cmd+V in library creates a new note.
* Pasted Markdown preserves line breaks; long text (>5k chars) remains responsive.
* Purge removes items >30 days old from Trash.

These cover the fundamentals without adding visual noise, and they plug straight into the packages and design language you already set.

---

## 21) Appearance settings (System • Light • Dark)

Give users an override while defaulting to System. Works on iOS and macOS.

### Model

```swift
enum AppearanceOption: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var label: String {
    switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" }
  }
  var colorScheme: ColorScheme? {
    switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
  }
}
```

### App entry (apply globally)

```swift
@main
struct NotesMagicApp: App {
  @AppStorage("appearance") private var appearanceRaw: String = AppearanceOption.system.rawValue
  private var appearance: AppearanceOption { AppearanceOption(rawValue: appearanceRaw) ?? .system }

  var body: some Scene {
    WindowGroup {
      RootView()
        .preferredColorScheme(appearance.colorScheme) // nil == System
    }
    #if os(macOS)
    Settings { SettingsView() } // native Settings window on macOS
    #endif
  }
}
```

### Settings UI (shared SwiftUI)

```swift
struct SettingsView: View {
  @AppStorage("appearance") private var appearanceRaw: String = AppearanceOption.system.rawValue

  var body: some View {
    Form {
      Picker("Appearance", selection: $appearanceRaw) {
        ForEach(AppearanceOption.allCases) { opt in
          Text(opt.label).tag(opt.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Toggle("Reduce Glass Effects", isOn: .constant(false)) // wire later if needed
        .help("Uses thinner material or solid fill for accessibility/performance.")
    }
    .padding()
  }
}
```

### iOS placement

* Put **SettingsView** behind a gear icon (Library toolbar) or in **in‑app Settings** via a sheet:

```swift
.sheet(isPresented: $showSettings) { SettingsView() }
```

### Assets & tokens

* In **Assets.xcassets**, create Color Sets with **Any, Dark** variants for background, textSecondary, pillFill.
* In code, expose tokens:

```swift
extension Color {
  static let bg = Color("Background")        // Any/Dark provided in assets
  static let textSecondary = Color("TextSecondary")
  static let pillFill = Color("PillFill")
}
```

* All components should use tokens (e.g., `.background(Color.bg)`) so the switch is automatic.

### Liquid glass notes

* `glassBackgroundEffect()` respects appearance automatically. For **Reduce Transparency** or **Increase Contrast**, fall back to `.thinMaterial` or solid fills.

### QA checklist (appearance)

* Toggling **System/Light/Dark** updates instantly without restart.
* App respects **System** when set to System and follows device theme schedule.
* Color assets flip correctly; no hard‑coded hex values in UI components.
* Contrast remains ≥ 4.5:1 in both modes; glass elements stay legible.

---

## Files to copy into your repo

### `docs/SPEC.md`

```markdown
# NotesMagic — Product & Engineering Spec (MVP)

A minimal, opinionated spec to drive Cursor and Xcode to the same outcome: a calm, native notes app for **iOS + macOS** where structure emerges after writing.

## 1) Goals & Non‑Goals
**Goals**
- Capture‑first editor with autosave.
- Subtle AI suggestions (title, tags, related notes) with provenance + undo.
- Views over databases: generate “Topic” views you can pin.
- macOS parity (menus, shortcuts, multiple windows) and iOS polish.
- Essential ops: create, paste (inline + as new note), delete (Trash + Undo), appearance (System/Light/Dark).
- One tasteful Liquid‑Glass element (floating **+** button) — everything else flat.

**Non‑Goals (MVP)**
- No custom blocks DB, no rich media beyond text/markdown basics.
- No cross‑platform web app.
- No heavy cloud features beyond optional CloudKit sync.

## 2) Architecture & Repo
```

NotesMagic/ App/ NotesMagicApp.xcodeproj NotesMagicApp/ App.swift Assets.xcassets Info.plist Packages/ Domain/ Data/ Features/Editor/ Features/Library/ Features/Onboarding/ UIComponents/ MLKit/ Tools/ docs/ SPEC.md

````
- **Swift Packages** own all code; the App targets (iOS/macOS) depend on them.
- Minimum: **iOS 17**, **macOS 14**. Use `glassBackgroundEffect()` when available (iOS 18/macOS 15), fallback to `.ultraThinMaterial`.

## 3) Platforms
- **iOS**: NavigationStack app, Library + Editor, floating Glass FAB.
- **macOS**: menus via `commands {}`, multiple `WindowGroup`s (Note/Topic), optional Menu Bar Extra for quick capture, drag‑and‑drop, Cmd+Backspace delete, Cmd+Shift+V paste as new note.

## 4) UX Principles (Design language)
1. Silence by default; suggestions appear after brief pause.
2. One focus at a time; secondary info in related panel.
3. Soft hierarchy (spacing + weight > borders).
4. Reversible: every AI write is a diff card with Undo.
5. Performance budgets: pill in <500ms (local); deep synthesis staged.

### Key Components
- **Editor**: `TextEditor` (or bridged `UITextView/NSTextView`) + Context Bar below caret (max 3 pills).
- **Diff Card**: shows change, provenance, Accept/Undo.
- **Related Panel**: right slide‑over with reason phrases.
- **Command Palette** (Cmd+K): Create/Organize/Understand/Navigate/Control.

## 5) Information Model
```swift
struct Note { id: UUID; createdAt: Date; updatedAt: Date; body: String; format: NoteFormat }
struct Annotation { id: UUID; noteId: UUID; range: Range<Int>; type: AnnotationType; payload: [String:Any]; provenance: Provenance; confidence: Double; isAccepted: Bool }
struct Relation { id: UUID; srcNoteId: UUID; dstNoteId: UUID; reason: String; score: Double }
struct TopicView { id: UUID; type: ViewType; queryDSL: [String:Any]; pinned: Bool }
````

## 6) Data & Storage

* Local‑first SQLite via **GRDB** with FTS5 search. Add column `deletedAt REAL` (soft delete).
* Optional sync: **CloudKit** (same container across iOS/macOS). Local DB remains the cache of truth.

### NotesStore protocol (must implement)

```swift
protocol NotesStore {
  func create(_ body: String) -> Note
  func update(_ note: Note)
  func trash(_ id: Note.ID) throws       // set deletedAt
  func restore(_ id: Note.ID) throws     // clear deletedAt
  func purge(olderThan days: Int) throws // hard delete trashed
  func activeNotes() -> [Note]
  func trashedNotes() -> [Note]
}
```

## 7) Search & Embeddings

* Hybrid search: FTS5 (keywords) + small embeddings index for related notes (local).
* Schedule embeddings on save if stale; prefetch related on open.

## 8) AI Pipeline

**On‑device (instant)**: title/tag/task heuristics + small model. Budget <50ms. **Cloud (optional, batched)**: relation discovery; TL;DR; view synthesis. **Controls**: provenance stored on every annotation; Accept/Undo required for low‑confidence writes.

## 9) Essential Operations

* **Create**: via Glass FAB or keyboard (Cmd+N).
* **Paste**:

  * Editor: native inline paste.
  * Library: Cmd+V (or toolbar button) → create new note from clipboard.
* **Delete**: swipe to delete (iOS), context menu delete (iOS/macOS), Cmd+Backspace (macOS). Moves to **Trash** with Undo; background purge >30 days.

## 10) Appearance (System • Light • Dark)

* `AppearanceOption` saved in `@AppStorage("appearance")`.
* Apply in `App` root with `.preferredColorScheme(...)`.
* Color tokens via Assets (Any/Dark): `Background`, `TextSecondary`, `PillFill`.

## 11) Liquid‑Glass (single element)

* Floating **+** button only.
* Implementation: `glassBackgroundEffect()` or `.ultraThinMaterial` fallback; 1px white overlay stroke @ 12% for edge clarity; soft shadow.

## 12) macOS Support Details

* `commands {}` for **New Note**, **Command Palette**, **Paste as New Note**.
* Multiple windows via additional `WindowGroup`s.
* Drag `.md` into app → import and show enrichment pills.

## 13) Acceptance Criteria (MVP)

* Build runs on iOS + macOS.
* Title/tag pills appear within 5s of typing pause; Accept/Undo works and stores provenance.
* Library supports delete (Trash + Undo) and paste‑as‑new.
* Editor supports inline paste and optional “Paste detected → Enrich?” strip (stub ok).
* Appearance toggle works instantly; tokens flip correctly.
* Glass FAB present; other surfaces flat.

## 14) Milestones (6 weeks)

1. Repo/packages, SQLite/GRDB, basic Editor + Library.
2. Context Bar (stub), Related panel (keyword‑based).
3. On‑device heuristics, embeddings scaffold.
4. Onboarding + Bear/Markdown import with staged enrichment animation.
5. Command palette, diff card, provenance, Undo.
6. Topic views, pinned views, macOS polish, CloudKit sync (basic).

## 15) QA Checklist

* Performance budgets met (pills <500ms, search <200ms @1k notes).
* Accessibility: contrast ≥4.5:1, targets ≥44pt touch/28pt pointer, VoiceOver reads provenance.
* macOS keyboard: Cmd+N/K/F, Cmd+Backspace, Cmd+Shift+V.

---

````

### `.cursorrules`
```text
# Project scope
- App: NotesMagic (SwiftUI), platforms: iOS + macOS (multi‑platform target preferred over Catalyst; Catalyst allowed for quick runs).
- Code lives in Swift Packages under /Packages; the App target(s) under /App depend on them.
- Do NOT add files directly to the .xcodeproj; create files in packages or App folder.

# Architecture
- Packages: Domain, Data, Features/Editor, Features/Library, Features/Onboarding, UIComponents, MLKit.
- Define protocols in Domain (NotesStore, SearchIndex, EmbeddingsIndex, SuggestionsEngine). Implement in Data.
- Use GRDB for SQLite with FTS5; provide an in‑memory fallback if GRDB unavailable during bootstrapping.

# Platforms
- Minimum: iOS 17, macOS 14. Prefer SwiftUI everywhere.
- Use `glassBackgroundEffect()` when available (iOS 18/macOS 15); otherwise `.ultraThinMaterial`.
- macOS: implement commands (New Note, Command Palette, Paste as New Note) and multiple WindowGroups.

# MVP features (must implement)
- Editor with autosave + Context Bar pills (stub acceptable), Related panel (keyword‑based initially).
- Soft delete (Trash) + Undo; background purge after 30 days.
- Paste inline in Editor; **Paste as New Note** in Library (Cmd+V) using UIPasteboard/NSPasteboard.
- Appearance settings: System/Light/Dark via @AppStorage + .preferredColorScheme.
- Liquid‑Glass: ONLY the floating + button; everything else flat.

# Implementation details
- Add `deletedAt REAL` to notes table. Provide migration.
- Provide `NotesStore` methods: create/update/trash/restore/purge/activeNotes/trashedNotes.
- Add color tokens via Assets (Any/Dark): Background, TextSecondary, PillFill. Use tokens, not hex.
- Provenance stored on every annotation; Accept/Undo flows for suggestions.

# Quality
- Compile after each step; fix build errors before moving on.
- Add minimal unit tests (NotesStore soft delete + restore; appearance persistence).
- Meet performance budgets: suggestion pill local <500ms; search <200ms @ 1k notes.

# Style
- Swift 5.10+, SwiftUI first. Avoid third‑party deps beyond GRDB unless explicitly approved.
- Follow Apple HIG for spacing/typography; use the design tokens described in docs/SPEC.md.
````

---

## 22) `DesignSystem.swift` — drop-in tokens + helpers

**Where to put it**: `Packages/UIComponents/Sources/UIComponents/DesignSystem.swift`

```swift
import SwiftUI

// MARK: - NotesMagic Design System
// Minimal, production-minded tokens and helpers used across iOS + macOS.
// All public so other packages (Features/*) can import UIComponents and use them.

public enum DS {
  // Spacing (8pt grid, with supporting micro/mega steps)
  public enum Spacing { public static let micro: CGFloat = 4; public static let xs: CGFloat = 8; public static let s: CGFloat = 12; public static let m: CGFloat = 16; public static let l: CGFloat = 24; public static let xl: CGFloat = 32; public static let xxl: CGFloat = 48 }

  // Radius tokens
  public enum Radius { public static let pill: CGFloat = 12; public static let card: CGFloat = 16; public static let fab: CGFloat = 18 }

  // Typography
  public enum Type {
    public static func h1() -> Font { .system(size: 28, weight: .semibold) }
    public static func h2() -> Font { .system(size: 22, weight: .semibold) }
    public static func body() -> Font { .system(size: 17, weight: .regular) }
    public static func secondary() -> Font { .system(size: 15, weight: .regular) }
    public static func meta() -> Font { .system(size: 13, weight: .regular) }
    public static func mono() -> Font { .system(.body, design: .monospaced) }
  }

  // Colors — expect Color assets named below with Any/Dark variants
  public enum ColorToken {
    public static var bg: Color { Color("Background", bundle: .module) }
    public static var textSecondary: Color { Color("TextSecondary", bundle: .module) }
    public static var pillFill: Color { Color("PillFill", bundle: .module) }
    public static var accent: Color { Color.accentColor }
  }

  // Motion
  public enum Motion {
    // Light, springy animations aligned to spec timings
    public static let appear: Animation = .interpolatingSpring(stiffness: 220, damping: 28)
    public static let contextBarIn: Animation = .easeOut(duration: 0.12)
    public static let contextBarOut: Animation = .easeOut(duration: 0.08)
    public static let diffSlide: Animation = .easeOut(duration: 0.14)
    public static let highlightPulse: Animation = .easeInOut(duration: 0.20)
  }

  // Shadows
  public enum Shadow {
    public static func raised(color: Color = .black.opacity(0.35)) -> (radius: CGFloat, x: CGFloat, y: CGFloat, color: Color) {
      (12, 0, 8, color)
    }
  }
}

// MARK: - View helpers

public extension View {
  // Apply a subtle card style with flat or glass background
  func cardBackground(glass: Bool = false) -> some View {
    modifier(CardBackground(glass: glass))
  }

  // Pill visual used for tags/suggestions; quiet by default
  func pillStyle() -> some View { modifier(PillStyle()) }

  // 1px hairline stroke for edge clarity on dark backgrounds
  func hairline(_ opacity: Double = 0.12) -> some View {
    overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(Color.white.opacity(opacity)))
  }
}

private struct CardBackground: ViewModifier {
  let glass: Bool
  func body(content: Content) -> some View {
    content
      .padding(DS.Spacing.m)
      .background(
        Group {
          if glass {
            if #available(iOS 18.0, macOS 15.0, *) {
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .glassBackgroundEffect()
            } else {
              RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
            }
          } else {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .fill(DS.ColorToken.bg)
          }
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
          .stroke(Color.white.opacity(0.12))
      )
  }
}

private struct PillStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .font(.footnote)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
          .fill(.ultraThinMaterial)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
          .stroke(Color.white.opacity(0.08))
      )
  }
}

// MARK: - Diff highlight utility
public struct DiffHighlight: View {
  public enum Kind { case added, removed }
  public let text: String
  public let kind: Kind
  public init(_ text: String, kind: Kind) { self.text = text; self.kind = kind }
  public var body: some View {
    Text(text)
      .font(DS.Type.secondary())
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(kind == .added ? DS.ColorToken.accent.opacity(0.12) : Color.red.opacity(0.10))
      )
  }
}

// MARK: - Glass FAB (shared) – one source of truth
public struct GlassFAB: View {
  public var action: () -> Void
  public init(action: @escaping () -> Void) { self.action = action }
  public var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .font(.system(size: 18, weight: .semibold))
        .padding(16)
    }
    .foregroundStyle(.primary)
    .background(
      Group {
        if #available(iOS 18.0, macOS 15.0, *) {
          RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous)
            .glassBackgroundEffect()
        } else {
          RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous)
            .fill(.ultraThinMaterial)
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous)
        .strokeBorder(.white.opacity(0.12))
    )
    .shadow(color: DS.Shadow.raised().color, radius: DS.Shadow.raised().radius, x: DS.Shadow.raised().x, y: DS.Shadow.raised().y)
    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous))
    .accessibilityLabel("New note")
  }
}

// MARK: - Preview (for local visual check; safe to remove)
#if DEBUG
struct DS_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: DS.Spacing.l) {
      Text("NotesMagic").font(DS.Type.h1())
      HStack { Text("Tag").pillStyle(); Text("Suggestion").pillStyle() }
      HStack { DiffHighlight("Added text", kind: .added); DiffHighlight("Removed text", kind: .removed) }
      GlassFAB { }
    }
    .padding(DS.Spacing.xl)
    .background(DS.ColorToken.bg)
    .preferredColorScheme(.dark)
  }
}
#endif
```

**Notes**

* Color assets required in `UIComponents/Resources/Assets.xcassets`: `Background`, `TextSecondary`, `PillFill` (Any/Dark variants). If you keep tokens in the App bundle, remove `bundle: .module` above.
* `GlassFAB` here replaces the duplicate in section 19; import `UIComponents` from features and reuse.
* Animations match the spec timings; adjust only in one place (DS.Motion).
* Everything is public to avoid access issues across packages.
