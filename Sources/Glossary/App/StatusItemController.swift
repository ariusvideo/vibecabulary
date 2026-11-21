import AppKit
import SwiftUI

/// Owns the menu bar icon and the popover, and routes keyboard input to the view model.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let popoverSize = NSSize(width: 600, height: 500)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let model: GlossaryViewModel
    private var keyMonitor: Any?

    init(model: GlossaryViewModel) {
        self.model = model
        super.init()

        if let button = statusItem.button {
            button.image = NSImage.braceMarkTemplate()
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "Vibecabulary (\(HotKey.defaultDisplay))"
        }

        popover.contentSize = Self.popoverSize
        popover.behavior = .transient
        popover.animates = false
        applyThemeAppearance()
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        popover.delegate = self
        let host = NSHostingController(rootView: ContentView(model: model))
        host.sizingOptions = []
        popover.contentViewController = host

        model.closePopover = { [weak self] in self?.close() }
        model.runPanel = { [weak self] panel in self?.runPanel(panel) ?? panel.runModal() }
    }

    @objc private func togglePopover(_ sender: Any?) { toggle() }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in self?.applyThemeAppearance() }
    }

    /// Native controls follow the theme: light for Reading room light, dark for the rest.
    private func applyThemeAppearance() {
        let name: NSAppearance.Name = ThemeID.stored.theme.isLight ? .aqua : .darkAqua
        if popover.appearance?.name != name { popover.appearance = NSAppearance(named: name) }
    }

    func toggle() {
        popover.isShown ? close() : show()
    }

    func show() {
        guard let button = statusItem.button else { return }
        model.willShow()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startKeyMonitor()
    }

    /// The popover's window sits at a high window level, and the open/save panel is drawn by a
    /// separate system process, so setting the panel's level doesn't help: it still opens behind
    /// the popover, and being modal it leaves the popover unclickable. Instead, drop the popover
    /// to a normal level while the panel is up, then put it back.
    private func runPanel(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        popover.behavior = .applicationDefined
        let popoverWindow = popover.contentViewController?.view.window
        let savedLevel = popoverWindow?.level
        popoverWindow?.level = .normal
        defer {
            if let savedLevel { popoverWindow?.level = savedLevel }
            popover.behavior = .transient
            popoverWindow?.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { panel.orderFrontRegardless(); panel.makeKey() }
        return panel.runModal()
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopKeyMonitor()
    }

    // NSTextField consumes ↑/↓/Esc, so they are intercepted before the field sees them.
    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown,
                  event.window === self.popover.contentViewController?.view.window else { return event }
            return self.model.handleKey(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
