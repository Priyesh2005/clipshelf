import AppKit
import Carbon
import ServiceManagement

struct Clip: Codable { let text: String; let date: Date }
final class History {
    var items: [Clip] = []
    let url: URL
    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([Clip].self, from: data) { items = Array(saved.prefix(200)) }
    }
    func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 100_000 else { return }
        items.removeAll { $0.text == text }
        items.insert(Clip(text: text, date: Date()), at: 0)
        items = Array(items.prefix(200)); save()
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(items).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { NSLog("ClipShelf could not save history: %@", error.localizedDescription) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    var status: NSStatusItem!
    var panel: NSPanel!
    let search = NSSearchField()
    let table = NSTableView()
    let footer = NSTextField(labelWithString: "")
    let history = History(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipShelfPublic/history.json"))
    var filtered: [Clip] = []
    var timer: Timer?
    var lastChange = NSPasteboard.general.changeCount
    var hotKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var previousApp: NSRunningApplication?
    var paused = !UserDefaults.standard.bool(forKey: "recordingEnabled")
    var keyMonitor: Any?
    let shortcuts: [(String, UInt32, UInt32)] = [("⌘⇧V", UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey)), ("⌘S", UInt32(kVK_ANSI_S), UInt32(cmdKey)), ("⌃⌥V", UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey))]
    var shortcutIndex: Int = {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "shortcutIndex") == nil ? 2 : defaults.integer(forKey: "shortcutIndex")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(); mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(); appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit ClipShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit"); editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
        makePanel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipShelf")
        status.button?.toolTip = "ClipShelf — clipboard history"
        status.button?.target = self; status.button?.action = #selector(statusClicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { delegate.show() }; return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        updateStatus()
        if !registerShortcut(shortcutIndex) { alert("Shortcut unavailable", "Use the menu bar icon, then right-click it to choose another shortcut.") }
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.poll() }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            switch event.keyCode {
            case 53: self.dismiss(); return nil
            case 36, 76: self.copySelected(); return nil
            case 125: self.move(1); return nil
            case 126: self.move(-1); return nil
            default: return event
            }
        }
        if !UserDefaults.standard.bool(forKey: "onboardingShown") {
            let welcome = NSAlert()
            welcome.messageText = "Welcome to ClipShelf"
            welcome.informativeText = "Keep up to 200 copied text items on this Mac. Press Control–Option–V, then click an item to copy and close. History is stored locally without app-level encryption. Text marked confidential by its source is skipped, but other sensitive text may still be saved. Right-click the menu bar icon to pause, clear history or change your shortcut."
            welcome.addButton(withTitle: "Start Recording")
            welcome.addButton(withTitle: "Not Now")
            NSApp.activate(ignoringOtherApps: true)
            paused = welcome.runModal() != .alertFirstButtonReturn
            UserDefaults.standard.set(!paused, forKey: "recordingEnabled")
            UserDefaults.standard.set(true, forKey: "onboardingShown")
            updateStatus()
            show()
        } else if !CommandLine.arguments.contains("--background") { show() }
    }
    func registerShortcut(_ index: Int) -> Bool {
        guard shortcuts.indices.contains(index) else { return registerShortcut(0) }
        let choice = shortcuts[index]
        var candidate: EventHotKeyRef?
        let result = RegisterEventHotKey(choice.1, choice.2, EventHotKeyID(signature: 0x43534846, id: 1), GetApplicationEventTarget(), 0, &candidate)
        guard result == noErr else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate; shortcutIndex = index
        UserDefaults.standard.set(index, forKey: "shortcutIndex")
        return true
    }
    func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        guard !paused else { return }
        let blocked = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
        guard !(pb.types ?? []).contains(where: { blocked.contains($0.rawValue) }), let text = pb.string(forType: .string) else { return }
        history.add(text)
        if panel.isVisible { refresh() }
    }
    func makePanel() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 610, height: 490), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.hidesOnDeactivate = false
        panel.title = "ClipShelf"; panel.level = .floating; panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 440, height: 300); panel.delegate = self
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let root = panel.contentView!
        let heading = NSTextField(labelWithString: "Your clipboard, close at hand.")
        heading.font = .systemFont(ofSize: 21, weight: .semibold)
        search.placeholderString = "Search copied text…"; search.delegate = self
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .noBorder
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text")); col.width = 560
        table.addTableColumn(col); table.headerView = nil; table.rowHeight = 56
        table.delegate = self; table.dataSource = self; table.target = self; table.action = #selector(copyClicked)
        table.usesAlternatingRowBackgroundColors = true
        scroll.documentView = table
        footer.font = .systemFont(ofSize: 11); footer.textColor = .secondaryLabelColor
        for view in [heading, search, scroll, footer] { view.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(view) }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), heading.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            search.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), search.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20), search.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 15),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16), scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 14), scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20), footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16)
        ])
    }
    func refresh() {
        let query = search.stringValue
        filtered = history.items.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
        table.reloadData()
        if !filtered.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
        footer.stringValue = history.items.isEmpty ? "Copy some text to get started. History stays on this Mac." : "\(filtered.count) items · Click to copy & close · ⌘V to paste · Esc closes"
    }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let label = NSTextField(wrappingLabelWithString: String(filtered[row].text.prefix(400)).replacingOccurrences(of: "\n", with: "  ↵  "))
        label.font = .systemFont(ofSize: 13); label.maximumNumberOfLines = 2; label.lineBreakMode = .byTruncatingTail
        label.toolTip = String(filtered[row].text.prefix(2000))
        let cell = NSTableCellView(); label.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        return cell
    }
    func controlTextDidChange(_ obj: Notification) { refresh() }
    func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        let row = max(0, min(filtered.count - 1, table.selectedRow + delta))
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false); table.scrollRowToVisible(row)
    }
    @objc func copyClicked() { copyRow(table.clickedRow) }
    @objc func copySelected() { copyRow(table.selectedRow) }
    func copyRow(_ row: Int) {
        guard filtered.indices.contains(row) else { return }
        let text = filtered[row].text
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            alert("Could not copy", "Try selecting the item again."); return
        }
        lastChange = NSPasteboard.general.changeCount; history.add(text); dismiss()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func show() {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        search.stringValue = ""; refresh(); panel.center(); NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil); panel.orderFrontRegardless(); panel.makeFirstResponder(search)
    }
    func dismiss() { panel.orderOut(nil); previousApp?.activate(options: []); previousApp = nil }
    func toggle() { panel.isVisible ? dismiss() : show() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }
    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { menu() } else { toggle() }
    }
    func menu() {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
        }
        _ = item("Show Clipboard History", #selector(openHistory))
        let shortcutItem = NSMenuItem(title: "Keyboard Shortcut", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index, choice) in shortcuts.enumerated() {
            let item = NSMenuItem(title: choice.0 + (index == 1 ? " (replaces Save)" : ""), action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self; item.tag = index; item.state = index == shortcutIndex ? .on : .off; submenu.addItem(item)
        }
        shortcutItem.submenu = submenu; menu.addItem(shortcutItem)
        _ = item(paused ? "Resume Recording" : "Pause Recording", #selector(pauseRecording))
        let login = item("Launch at Login", #selector(toggleLogin)); login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator()); _ = item("Clear History…", #selector(clearHistory)); _ = item("Quit ClipShelf", #selector(quit))
        if let button = status.button { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button) }
    }
    @objc func openHistory() { show() }
    @objc func changeShortcut(_ sender: NSMenuItem) {
        guard sender.tag != shortcutIndex else { return }
        if !registerShortcut(sender.tag) { alert("Shortcut unavailable", "Another app or macOS is using that shortcut. Your previous shortcut is still active.") }
    }
    func updateStatus() {
        status.button?.toolTip = paused ? "ClipShelf — recording paused" : "ClipShelf — clipboard history"
        status.button?.image = NSImage(systemSymbolName: paused ? "pause.circle" : "clipboard", accessibilityDescription: "ClipShelf")
    }
    @objc func pauseRecording() {
        paused.toggle(); lastChange = NSPasteboard.general.changeCount
        UserDefaults.standard.set(!paused, forKey: "recordingEnabled"); updateStatus()
    }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { alert("Could not change login setting", error.localizedDescription) }
    }
    @objc func clearHistory() {
        let alert = NSAlert(); alert.messageText = "Clear all saved clipboard history?"; alert.informativeText = "This removes ClipShelf’s saved items. Your current clipboard is unchanged."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Clear History")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { history.items.removeAll(); history.save(); refresh() }
    }
    @objc func quit() { NSApp.terminate(nil) }
    func alert(_ title: String, _ text: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; NSApp.activate(ignoringOtherApps: true); alert.runModal() }
}

if CommandLine.arguments.contains("--self-test") {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let history = History(url: dir.appendingPathComponent("history.json"))
    history.add("hello"); history.add("world"); history.add("hello")
    precondition(history.items.map(\.text) == ["hello", "world"])
    history.add("   "); history.add(String(repeating: "a", count: 100001))
    precondition(history.items.count == 2)
    for i in 0..<205 { history.add("item \(i)") }
    precondition(history.items.count == 200)
    precondition(History(url: history.url).items.first?.text == "item 204")
    history.items.removeAll(); history.save(); precondition(History(url: history.url).items.isEmpty)
    try? FileManager.default.removeItem(at: dir)
    print("PASS: duplicate handling, size limits, history cap, persistence, clearing")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; withExtendedLifetime(delegate) { app.run() }
}
