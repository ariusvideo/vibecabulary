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
        model.pinPopover = { [weak self] pinned in self?.popover.behavior = pinned ? .applicationDefined : .transient }
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
