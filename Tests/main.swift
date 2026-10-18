import AppKit

@MainActor func runTests() {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else { fputs("FAIL: \(label)\n", stderr); exit(1) }
        checks += 1
        print("PASS: \(label)")
    }
    var history = History()
    check(!history.remember(" \n\t"), "ignore blank text")
    let exact = "  café 👩🏽‍💻\nsecond line\t "
    history.remember(exact)
    check(history.entries.first?.text == exact, "preserve exact Unicode and whitespace")
    check(!history.remember(exact), "ignore consecutive duplicate")
    let originalID = history.entries[0].id
    history.remember("Other")
    history.remember(exact)
    check(history.entries.count == 2 && history.entries.first?.id == originalID, "promote duplicate without duplication")
    for index in 0..<25 { history.remember("Entry \(index)") }
    check(history.entries.count == 20 && history.entries.last?.text == "Entry 5", "evict oldest at 20 entries")
    check(!history.remember(String(repeating: "é", count: 32_769)), "reject text exceeding 64 KiB in UTF-8")
    check(history.remember(String(repeating: "a", count: 65_536)), "accept exactly 64 KiB")

    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    func copy(_ text: String) {
        board.clearContents()
        check(board.setString(text, forType: .string), "write isolated clipboard fixture")
    }
    copy("Existing text before launch")
    let store = ClipboardStore(pasteboard: board)
    store.poll()
    check(store.history.entries.isEmpty, "skip prelaunch clipboard")
    copy(exact)
    store.poll()
    check(store.history.entries.first?.text == exact, "capture new clipboard text")
    let restoreID = store.history.entries[0].id
    for marker in ClipboardStore.excludedTypes {
        let item = NSPasteboardItem()
        item.setString("Marked private text", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
        board.clearContents()
        board.writeObjects([item])
        store.poll()
        check(store.history.entries.count == 1, "ignore \(marker)")
    }
    board.clearContents()
    board.setData(Data([1, 2, 3]), forType: .png)
    store.poll()
    check(store.history.entries.count == 1, "ignore non-text clipboard")
    copy(String(repeating: "a", count: 65_537))
    store.poll()
    check(store.history.entries.count == 1 && store.message.contains("64 KiB"), "skip oversized capture with useful status")
    store.setPaused(true)
    copy("Should not be captured")
    store.poll()
    store.setPaused(false)
    store.poll()
    check(store.history.entries.count == 1, "pause and resume do not import paused copies")
    copy("Newest")
    store.poll()
    check(store.restore(restoreID), "restore saved entry")
    check(board.string(forType: .string) == exact, "restore exact text to pasteboard")
    store.poll()
    check(store.history.entries.count == 2, "own write does not create duplicate")
    check(!store.restore(UUID()), "stale selection does not alter clipboard")
    let textView = NSTextView()
    check(textView.readSelection(from: board), "AppKit text view accepts restored clipboard")
    check(Array(textView.string.utf8) == Array(exact.utf8), "pasted text matches byte-for-byte")
    store.clear()
    store.poll()
    check(store.history.entries.isEmpty && board.string(forType: .string) == exact, "clear preserves clipboard and does not recapture it")

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let controller = AppController(store: store, testing: true)
    app.delegate = controller
    controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    check(controller.window.touchBar != nil, "window provides public NSTouchBar")
    for value in ["A short note", "A second clipboard entry", "The oldest item on page two", "An email draft", "A useful sentence"] {
        copy(value)
        store.poll()
    }
    let bar = controller.window.touchBar!
    let touchButtons = bar.templateItems.compactMap { ($0 as? NSCustomTouchBarItem)?.view as? ClipButton }
    check(touchButtons.count == 3, "Touch Bar shows three history buttons")
    controller.nextPage()
    let secondPage = controller.window.touchBar!.templateItems.compactMap { ($0 as? NSCustomTouchBarItem)?.view as? ClipButton }
    check(secondPage.count == 2, "Touch Bar pages to remaining entries")
    let button = secondPage.first!
    let expected = store.history.entries.first(where: { $0.id == button.clipID })!.text
    button.performClick(nil)
    check(board.string(forType: .string) == expected, "Touch Bar button action restores selected text")
    let screenButton = controller.rows.arrangedSubviews.compactMap { $0 as? ClipButton }.last!
    let screenExpected = store.history.entries.first(where: { $0.id == screenButton.clipID })!.text
    screenButton.performClick(nil)
    check(board.string(forType: .string) == screenExpected, "onscreen button restores selected text")
    controller.togglePause()
    check(store.paused && controller.pause.title == "Resume recording", "pause control updates state and label")
    controller.togglePause()
    controller.nextPage()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    controller.window.contentView!.layoutSubtreeIfNeeded()
    let view = controller.window.contentView!
    check(controller.rows.frame.width <= view.bounds.width, "history fits window width")
    if CommandLine.arguments.contains("--capture") {
        // Optional developer QA; screen capture is never part of the app itself.
        // Native window capture includes AppKit's compositor-rendered button labels.
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(controller.window.windowNumber), "docs/test-window.png"]
        try! capture.run()
        capture.waitUntilExit()
        check(capture.terminationStatus == 0, "capture native test window")
    }
    controller.clearHistory()
    check(store.history.entries.isEmpty && controller.page == 0, "clear control resets pagination")
    controller.window.close()
    print("PASS: \(checks) checks. Only an isolated named pasteboard was used; no user clipboard was read or changed.")
}

runTests()
