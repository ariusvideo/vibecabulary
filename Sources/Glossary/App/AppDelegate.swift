import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: GlossaryStore!
    private var model: GlossaryViewModel!
    private var statusItem: StatusItemController!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = GlossaryStore()
        model = GlossaryViewModel(store: store)
        statusItem = StatusItemController(model: model)
        hotKey = HotKey(keyCode: HotKey.defaultKeyCode, modifiers: HotKey.defaultModifiers) { [weak self] in
            self?.statusItem.toggle()
        }
    }
}
