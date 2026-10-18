import AppKit

@MainActor final class ClipButton: NSButton {
    var clipID: UUID?
}

@MainActor final class HistoryRows: NSStackView {
    override var isFlipped: Bool { true }
}

@MainActor final class HistoryWindow: NSWindow {
    weak var controller: AppController?
    override func makeTouchBar() -> NSTouchBar? { controller?.makeHistoryTouchBar() }
}

@MainActor final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store: ClipboardStore
    var window: HistoryWindow!
    var statusItem: NSStatusItem!
    var timer: Timer?
    var previousApp: NSRunningApplication?
    var activationObserver: NSObjectProtocol?
    let rows = HistoryRows()
    let message = NSTextField(wrappingLabelWithString: "")
    let count = NSTextField(labelWithString: "")
    let pause = NSButton(title: "Pause recording", target: nil, action: nil)
    var page = 0
    let testing: Bool

    init(store: ClipboardStore = ClipboardStore(), testing: Bool = false) {
        self.store = store
        self.testing = testing
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        makeWindow()
        store.onChange = { [weak self] in self?.refresh() }
        if !testing {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "TouchClip clipboard history")
            statusItem.button?.toolTip = "TouchClip — open clipboard history"
            statusItem.button?.target = self
            statusItem.button?.action = #selector(showHistory)
            previousApp = NSWorkspace.shared.frontmostApplication
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                MainActor.assumeIsolated { self?.previousApp = app }
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.store.poll() }
            }
            timer?.tolerance = 0.15
        }
        refresh()
        showHistory()
    }

    func installMenu() {
        let menu = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Open History", action: #selector(showHistory), keyEquivalent: "o").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit TouchClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu
        menu.addItem(root)
        NSApp.mainMenu = menu
    }

    func makeWindow() {
        window = HistoryWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 570),
                               styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "TouchClip"
        window.isReleasedWhenClosed = false
        window.controller = self
        window.delegate = self
        window.center()
        let content = window.contentView!
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24)
        ])
        let heading = NSTextField(labelWithString: "Your recent text")
        heading.font = .systemFont(ofSize: 25, weight: .semibold)
        stack.addArrangedSubview(heading)
        let intro = NSTextField(wrappingLabelWithString: "Choose here or on the Touch Bar. Then paste with ⌘V.\nTouch Bar buttons appear while TouchClip is active.")
        intro.textColor = .secondaryLabelColor
        stack.addArrangedSubview(intro)
        count.font = .systemFont(ofSize: 11)
        count.textColor = .secondaryLabelColor
        stack.addArrangedSubview(count)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .bezelBorder
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6
        rows.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = rows
        stack.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
            rows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        message.font = .systemFont(ofSize: 12)
        message.textColor = .secondaryLabelColor
        stack.addArrangedSubview(message)
        message.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let privacy = NSTextField(wrappingLabelWithString: "20 entries · memory only · cleared when you quit\nPassword markers are respected; unmarked secrets can still be saved.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        stack.addArrangedSubview(privacy)
        let footer = NSStackView()
        footer.spacing = 12
        pause.target = self
        pause.action = #selector(togglePause)
        footer.addArrangedSubview(pause)
        footer.addArrangedSubview(NSButton(title: "Clear History", target: self, action: #selector(clearHistory)))
        footer.addArrangedSubview(NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:))))
        stack.addArrangedSubview(footer)
    }

    @objc func showHistory() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        store.poll()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window)
    }

    func refresh() {
        let entries = store.history.entries
        page = min(page, max(0, (entries.count - 1) / 3))
        count.stringValue = "\(entries.count) of \(History.limit) entries · newest first"
        message.stringValue = store.message
        pause.title = store.paused ? "Resume recording" : "Pause recording"
        for view in rows.arrangedSubviews { rows.removeArrangedSubview(view); view.removeFromSuperview() }
        if entries.isEmpty {
            rows.addArrangedSubview(NSTextField(labelWithString: "No saved text yet. Copy something to get started."))
        }
        for (index, clip) in entries.enumerated() {
            let button = clipButton(clip, title: "\(index + 1).  \(clip.preview)")
            button.bezelStyle = .rounded
            button.alignment = .left
            button.lineBreakMode = .byTruncatingTail
            rows.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: rows.widthAnchor, constant: -20).isActive = true
        }
        window.touchBar = window.makeTouchBar()
    }

    func clipButton(_ clip: Clip, title: String) -> ClipButton {
        let button = ClipButton(title: title, target: self, action: #selector(selectClip(_:)))
        button.clipID = clip.id
        button.toolTip = clip.preview
        button.setAccessibilityLabel("Copy \(clip.preview)")
        return button
    }

    func makeHistoryTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        var items: [NSTouchBarItem] = []
        func add(_ name: String, _ view: NSView) {
            let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("local.touchclip.\(name)"))
            item.view = view
            items.append(item)
        }
        let entries = store.history.entries
        if entries.isEmpty {
            add("empty", NSButton(title: "Copy text to begin", target: self, action: #selector(showHistory)))
        } else {
            let back = NSButton(title: "‹", target: self, action: #selector(previousPage))
            back.isEnabled = page > 0
            back.setAccessibilityLabel("Previous clipboard entries")
            add("back", back)
            for (slot, clip) in entries.dropFirst(page * 3).prefix(3).enumerated() {
                let short = String(clip.preview.prefix(18)) + (clip.preview.count > 18 ? "…" : "")
                add("clip\(slot)", clipButton(clip, title: short))
            }
            let next = NSButton(title: "›", target: self, action: #selector(nextPage))
            next.isEnabled = (page + 1) * 3 < entries.count
            next.setAccessibilityLabel("Next clipboard entries")
            add("next", next)
        }
        bar.templateItems = Set(items)
        bar.defaultItemIdentifiers = items.map(\.identifier)
        return bar
    }

    @objc func selectClip(_ sender: ClipButton) {
        guard let id = sender.clipID, store.restore(id) else { return }
        page = 0
        refresh()
        if !testing, let previousApp, !previousApp.isTerminated {
            if previousApp.activate(from: .current, options: []) { window.orderOut(nil) }
        }
    }
    @objc func previousPage() { page = max(0, page - 1); refresh() }
    @objc func nextPage() { page = min(max(0, (store.history.entries.count - 1) / 3), page + 1); refresh() }
    @objc func togglePause() { store.setPaused(!store.paused) }
    @objc func clearHistory() { page = 0; store.clear() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHistory()
        return true
    }
}
