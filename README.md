# HDStickies

https://github.com/HDClick/HDStickies/blob/main/screenshot.jpg

> Floating markdown sticky notes that live natively in your Obsidian vault — no plugin, no sync, Obsidian doesn't even need to be running.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-Personal-green)
![Part of HDPro](https://img.shields.io/badge/HDPro-Family-purple)

---

## What is HDStickies?

HDStickies is a macOS utility that lives in your menu bar and lets you create beautiful floating sticky notes that stay on top of all your windows — just like real Post-it notes on your desk.

Every note is saved as a plain `.md` file directly into any folder you choose — including your **Obsidian vault**. No plugin required. No sync service. No proprietary format. Just markdown files, exactly where you want them.

---

## Why HDStickies?

Most sticky note apps either:
- Store notes in iCloud or a proprietary database you can't access
- Require a plugin or Obsidian to be running to integrate with your vault
- Look like they were designed in 2003

HDStickies does none of that. Your notes are plain `.md` files in your vault the moment you close them. Open Obsidian an hour later and they're already there, tagged and dated.

---

## Features

### Floating Notes
- Always on top — notes float above all other windows like real sticky notes
- Drag anywhere on the note to reposition
- Collapse to a slim title strip with one click, expand again when needed
- Multiple notes open simultaneously — no cap
- Notes reopen exactly where you left them on relaunch

### Markdown Formatting
Full formatting toolbar on every note:

| Feature | How |
|---|---|
| **Bold** | Toolbar or `**text**` |
| *Italic* | Toolbar or `*text*` |
| ~~Strikethrough~~ | Toolbar or `~~text~~` |
| ==Highlight== | Toolbar or `==text==` |
| Headings H1–H3 | Toolbar |
| Bullet & numbered lists | Toolbar |
| Checklists | Toolbar or `- [ ] text` |
| Code block | Toolbar or ` ``` ` |
| Inline code | Toolbar or `` `code` `` |
| Link | Toolbar → dialog (Name + URL) |
| Image | Toolbar → file picker |
| Callout | Toolbar → dialog (Obsidian-style) |

### Obsidian Callouts
Insert any Obsidian callout type directly from a dialog:
- 27 callout types: Note, Warning, Tip, Info, Todo, Danger, Bug, Quote and more
- Optional title, collapse state (Default / Open / Closed)
- Inserts proper `> [!type]` markdown syntax

### Note Colours
8 pastel colour themes per note — Yellow, Orange, Green, Blue, Pink, Purple, White, Dark.
Set a default colour in Settings, or choose **Random** for a different colour every time.

### Saves as Markdown
Every note saves as a `.md` file with full YAML frontmatter:

```markdown
---
Date: 2026-06-17
Color: blue
Tags: HDStickies
---

# Your Note Title

Your content here...
```

- **Date** — creation date, readable by Obsidian
- **Color** — restored when you reopen HDStickies
- **Tags: HDStickies** — find all your stickies in Obsidian with `tag: HDStickies`

### All Notes Editor
A full-featured editor window showing all your notes in one place:

- Sidebar lists every `.md` file in your save folder
- Colour stripe per note — click to change colour
- Full inline editor — no separate window opens
- Auto-saves when switching between notes
- Pin notes to the top of the sidebar
- Search within the editor
- Right-click → Delete or Show in Finder

### Menu Bar Search
Search across all your notes instantly:

- Press **⇧⌥⌘S** from anywhere on your Mac
- Live results as you type — searches title and content
- Click any result to open it directly in the All Notes editor
- Colour dot shows the note's colour at a glance

### Export
Three export options under **Menu Bar → Export Notes**:

| Option | What it does |
|---|---|
| Export as ZIP | Bundles all `.md` files into `HDStickies-Export.zip` |
| Export to Folder | Copies all `.md` files to any folder you choose |
| Create Index File | Generates `HDStickies-INDEX.md` with Obsidian `[[wiki links]]` to every note |

### Settings
- **Launch at Login** — starts silently in the menu bar on boot
- **Default Note Colour** — including Random
- **Default Save Folder** — point it at your Obsidian vault
- **Default Font & Size**
- **Global Hotkey Recorder** — change any hotkey to whatever you like

### Menu Bar Icon
- 8 built-in SF Symbol options
- **Use Image File…** — use any PNG/JPEG/ICNS as your menu bar icon
- Reset to default anytime

---

## Global Hotkeys

| Action | Default Hotkey |
|---|---|
| New Note | ⇧⌥⌘N |
| All Notes Editor | ⇧⌥⌘A |
| Search Notes | ⇧⌥⌘S |

All three hotkeys are fully customisable in Settings — change any of them to whatever works for your setup.

---

## Installation

HDStickies is built with Xcode and runs on your own Mac — no App Store, no notarisation required for personal use.

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15 or later

### Build from Source

1. Clone or download this repository
2. Open `HDStickies.xcodeproj` in Xcode
3. Press **▶ Run** (or ⌘R)
4. HDStickies appears in your menu bar ⭐

### First Run
1. Click the menu bar icon → **Choose Save Folder…**
2. Select your Obsidian vault folder (or any folder)
3. Press **⇧⌥⌘N** to create your first note
4. Grant **Accessibility permission** when prompted (required for global hotkeys)

---

## Obsidian Integration

HDStickies is designed to work alongside Obsidian without requiring it:

- Notes save as standard `.md` files — Obsidian opens them like any other note
- YAML frontmatter is fully compatible with Obsidian's metadata system
- `Tags: HDStickies` lets you filter all stickies in Obsidian's search
- The **Create Index** export generates a dashboard with `[[wiki links]]` to every note
- Obsidian doesn't need to be running — notes appear in your vault automatically

---

## Part of HDPro

HDStickies is part of the **HDPro** family of personal Mac utilities:

| App | Description |
|---|---|
| **HDClick** | Popup launcher — apps, folders and tools come to your cursor |
| **HDStickies** | Floating markdown sticky notes with Obsidian integration |

Both apps work great together — use HDClick hotkeys to trigger HDStickies global shortcuts.

---

## Privacy

- No internet connection required
- No telemetry, no analytics, no tracking
- All notes stored locally as plain text files
- No account, no subscription, no cloud

---

## Built With

- **Swift 5** + **SwiftUI** — native macOS UI
- **AppKit** — floating windows, menu bar, global hotkeys via `CGEventTap`
- **ServiceManagement** — Launch at Login
- Plain `.md` files — no database, no CoreData

---

## License

Built for personal use. Free to use, modify and share.

---

*HDStickies — Built for Obsidian users, by an Obsidian user.*
