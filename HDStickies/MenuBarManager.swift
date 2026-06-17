// ============================================================
// MenuBarManager.swift
// ============================================================
// Updated in v3:
// - Search notes from menu bar (popover search panel)
// - Custom image support for menu bar icon (like HDClick)
// ============================================================

import AppKit
import SwiftUI
import Carbon

class MenuBarManager: NSObject {

    // Shared instance — accessible from anywhere without going through AppDelegate
    static weak var shared: MenuBarManager?

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    private var allNotesWindow: NSWindow?
    private var searchPanel: NSPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Persistent ViewModel so All Notes keeps state between open/close
    // Internal access so search can set pendingSelectPath directly
    let allNotesViewModel = AllNotesViewModel()

    private var currentIconName: String {
        get { UserDefaults.standard.string(forKey: "MenuBarIcon") ?? "star.fill" }
        set { UserDefaults.standard.set(newValue, forKey: "MenuBarIcon") }
    }

    private var customIconPath: String? {
        get { UserDefaults.standard.string(forKey: "MenuBarIconCustomPath") }
        set { UserDefaults.standard.set(newValue, forKey: "MenuBarIconCustomPath") }
    }

    func setup() {
        MenuBarManager.shared = self
        setupStatusItem()
        setupGlobalHotkeys()
    }

    // --------------------------------------------------------
    // setupStatusItem
    // --------------------------------------------------------
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        applyCurrentIcon()
        buildMenu()
    }

    // --------------------------------------------------------
    // applyCurrentIcon — SF Symbol or custom image
    // --------------------------------------------------------
    private func applyCurrentIcon() {
        guard let button = statusItem?.button else { return }

        // Try custom image first
        if let path = customIconPath,
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            button.image = img
            return
        }

        // Fall back to SF Symbol
        if let image = NSImage(systemSymbolName: currentIconName,
                               accessibilityDescription: "HDStickies") {
            image.isTemplate = true
            button.image = image
        }
    }

    // --------------------------------------------------------
    // buildMenu
    // --------------------------------------------------------
    func buildMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "HDStickies", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.attributedTitle = NSAttributedString(
            string: "HDStickies",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // New Note ⇧⌥⌘N
        let newNoteItem = NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "n")
        newNoteItem.keyEquivalentModifierMask = [.command, .shift, .option]
        newNoteItem.target = self
        menu.addItem(newNoteItem)

        // All Notes ⇧⌥⌘A
        let allNotesItem = NSMenuItem(title: "All Notes", action: #selector(openAllNotes), keyEquivalent: "a")
        allNotesItem.keyEquivalentModifierMask = [.command, .shift, .option]
        allNotesItem.target = self
        menu.addItem(allNotesItem)

        // Search Notes ⇧⌥⌘F
        let searchItem = NSMenuItem(title: "Search Notes…", action: #selector(openSearch), keyEquivalent: "s")
        searchItem.keyEquivalentModifierMask = [.command, .shift, .option]
        searchItem.target = self
        menu.addItem(searchItem)

        menu.addItem(NSMenuItem.separator())

        // Show All Floating Notes
        let showAllItem = NSMenuItem(title: "Show All Floating Notes", action: #selector(showAllNotes), keyEquivalent: "")
        showAllItem.target = self
        menu.addItem(showAllItem)

        menu.addItem(NSMenuItem.separator())

        // Choose Save Folder
        let folderItem = NSMenuItem(title: "Choose Save Folder…", action: #selector(chooseSaveFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        if let folder = NoteWindowManager.shared.saveFolder {
            let pathItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            pathItem.isEnabled = false
            pathItem.attributedTitle = NSAttributedString(
                string: "  📁 \(folder.lastPathComponent)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            menu.addItem(pathItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Export submenu
        let exportMenuItem = NSMenuItem(title: "Export Notes", action: nil, keyEquivalent: "")
        exportMenuItem.submenu = buildExportSubmenu()
        menu.addItem(exportMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings ⌘,
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Menu Bar Icon submenu
        let iconMenuItem = NSMenuItem(title: "Menu Bar Icon", action: nil, keyEquivalent: "")
        iconMenuItem.submenu = buildIconSubmenu()
        menu.addItem(iconMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit HDStickies",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q")
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu
    }

    // --------------------------------------------------------
    // buildExportSubmenu
    // --------------------------------------------------------
    private func buildExportSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let zipItem = NSMenuItem(title: "Export as ZIP…", action: #selector(exportZip), keyEquivalent: "")
        zipItem.target = self
        submenu.addItem(zipItem)

        let folderItem = NSMenuItem(title: "Export to Folder…", action: #selector(exportFolder), keyEquivalent: "")
        folderItem.target = self
        submenu.addItem(folderItem)

        submenu.addItem(NSMenuItem.separator())

        let indexItem = NSMenuItem(title: "Create Index File", action: #selector(exportIndex), keyEquivalent: "")
        indexItem.target = self
        submenu.addItem(indexItem)

        return submenu
    }

    @objc private func exportZip()    { ExportManager.shared.exportAsZip() }
    @objc private func exportFolder() { ExportManager.shared.exportToFolder() }
    @objc private func exportIndex()  { ExportManager.shared.exportIndex() }

    // --------------------------------------------------------
    // buildIconSubmenu — SF Symbols + Use Image option
    // --------------------------------------------------------
    private func buildIconSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let iconOptions: [(name: String, symbol: String)] = [
            ("Star (Default)",  "star.fill"),
            ("Note & Pencil",   "note.text"),
            ("Pencil",          "pencil"),
            ("Document",        "doc.fill"),
            ("Sticky Note",     "square.fill"),
            ("Pin",             "pin.fill"),
            ("Bookmark",        "bookmark.fill"),
            ("Lightbulb",       "lightbulb.fill"),
        ]

        for option in iconOptions {
            let item = NSMenuItem(title: option.name,
                                   action: #selector(changeIcon(_:)),
                                   keyEquivalent: "")
            item.target = self
            item.representedObject = option.symbol
            if let img = NSImage(systemSymbolName: option.symbol,
                                  accessibilityDescription: nil) {
                img.isTemplate = true
                item.image = img
            }
            // Tick if this is the active symbol and no custom image set
            item.state = (option.symbol == currentIconName && customIconPath == nil) ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())

        // Use custom image — like HDClick
        let useImageItem = NSMenuItem(title: "Use Image File…",
                                       action: #selector(chooseCustomIcon),
                                       keyEquivalent: "")
        useImageItem.target = self
        if let img = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) {
            img.isTemplate = true
            useImageItem.image = img
        }
        // Tick if custom image is active
        useImageItem.state = (customIconPath != nil) ? .on : .off
        submenu.addItem(useImageItem)

        // Reset to default
        let resetItem = NSMenuItem(title: "Reset to Default",
                                    action: #selector(resetIcon),
                                    keyEquivalent: "")
        resetItem.target = self
        submenu.addItem(resetItem)

        return submenu
    }

    // ============================================================
    // SEARCH PANEL
    // ============================================================
    @objc func openSearch() {
        if searchPanel == nil {
            let view = MenuBarSearchView(onDismiss: { [weak self] in
                self?.searchPanel?.close()
            })
            let hosting = NSHostingController(rootView: view)
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.title = ""
            p.titlebarAppearsTransparent = true
            p.titleVisibility = .hidden
            p.isMovableByWindowBackground = true
            p.contentViewController = hosting
            p.isReleasedWhenClosed = false
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
            p.isFloatingPanel = true
            searchPanel = p
        }
        searchPanel?.center()
        searchPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // ============================================================
    // ALL NOTES WINDOW
    // ============================================================
    // Called after search selection to ensure window is visible and key
    func bringAllNotesToFront() {
        allNotesWindow?.makeKeyAndOrderFront(nil)
        allNotesWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openAllNotes() {
        if allNotesWindow == nil {
            // Pass the persistent ViewModel so state survives open/close cycles
            let view = AllNotesView(externalViewModel: allNotesViewModel)
            let hosting = NSHostingController(rootView: view)

            // Use contentRect init so we can set styleMask at creation time
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.title = "HDStickies — All Notes"
            window.minSize = NSSize(width: 600, height: 400)
            window.center()
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            allNotesWindow = window
        }
        allNotesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Always reload notes when window is shown
        // If pendingSelectPath was set by search, loadNotes() will select it
        allNotesViewModel.loadNotes()
    }

    // ============================================================
    // SETTINGS WINDOW
    // ============================================================
    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "HDStickies Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.setContentSize(NSSize(width: 400, height: 560))
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // ============================================================
    // GLOBAL HOTKEYS — ⇧⌥⌘N, ⇧⌥⌘A, ⇧⌥⌘F
    // ============================================================
    private func setupGlobalHotkeys() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !trusted { print("⚠️ Accessibility permission not granted"); return }

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<MenuBarManager>.fromOpaque(refcon).takeUnretainedValue()

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags   = event.flags
                let target: CGEventFlags = [.maskShift, .maskAlternate, .maskCommand]
                let active  = flags.intersection([.maskShift, .maskAlternate, .maskCommand, .maskControl])

                if active == target {
                    let newNoteHK  = HotkeyDefinition.load(key: "Hotkey_NewNote",  default: .newNote)
                    let allNotesHK = HotkeyDefinition.load(key: "Hotkey_AllNotes", default: .allNotes)

                    if keyCode == newNoteHK.keyCode {
                        DispatchQueue.main.async { manager.newNote() }
                        return nil
                    }
                    if keyCode == allNotesHK.keyCode {
                        DispatchQueue.main.async { manager.openAllNotes() }
                        return nil
                    }
                    // Search Notes — read from UserDefaults so Settings changes take effect
                    let searchHK = HotkeyDefinition.load(key: "Hotkey_SearchNotes", default: .searchNotes)
                    if keyCode == searchHK.keyCode {
                        DispatchQueue.main.async { manager.openSearch() }
                        return nil
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // ============================================================
    // ACTIONS
    // ============================================================

    @objc private func newNote() {
        let saved = UserDefaults.standard.string(forKey: "DefaultNoteColor") ?? "yellow"
        let color: NoteColor = saved == "random"
            ? (NoteColor.allCases.randomElement() ?? .yellow)
            : (NoteColor(rawValue: saved) ?? .yellow)
        NoteWindowManager.shared.createNewNote(withColor: color)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAllNotes() {
        NoteWindowManager.shared.showAllNotes()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func chooseSaveFolder() {
        NoteWindowManager.shared.chooseSaveFolder { _ in
            DispatchQueue.main.async { self.buildMenu() }
        }
    }

    @objc private func changeIcon(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        customIconPath = nil   // clear any custom image
        currentIconName = symbol
        applyCurrentIcon()
        buildMenu()
    }

    @objc private func chooseCustomIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .icns, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Icon"
        panel.message = "Choose an image to use as the menu bar icon"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.customIconPath = url.path
            DispatchQueue.main.async {
                self?.applyCurrentIcon()
                self?.buildMenu()
            }
        }
    }

    @objc private func resetIcon() {
        customIconPath = nil
        currentIconName = "star.fill"
        applyCurrentIcon()
        buildMenu()
    }

    @objc private func reloadHotkeys() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil; runLoopSource = nil
        setupGlobalHotkeys()
    }

    deinit {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
    }
}
