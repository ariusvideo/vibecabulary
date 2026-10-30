import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Menu bar only: no Dock icon or app menu (LSUIElement also sets this in the bundle).
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
