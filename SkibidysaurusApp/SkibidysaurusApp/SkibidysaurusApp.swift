import SwiftUI
import AppKit

@main
struct SkibidysaurusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Custom NSPanel subclass that can become key window (accepts keyboard input)
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var overlayPanel: KeyablePanel?
    var appState = AppState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Menu Bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Skibidysaurus")
            button.action = #selector(toggleOverlay)
            button.target = self
        }
        
        createOverlayPanel()
        setupHotkey()
        
        print("Skibidysaurus Swift Frontend Started!")
    }
    
    func createOverlayPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        // Important: Allow the panel to accept keyboard input
        panel.becomesKeyOnlyIfNeeded = false
        
        let hostingView = NSHostingView(rootView: OverlayView(appState: appState))
        panel.contentView = hostingView
        
        self.overlayPanel = panel
    }
    
    @objc func toggleOverlay() {
        guard let panel = overlayPanel else { return }
        
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main!
            
            var x = mouseLocation.x + 15
            var y = mouseLocation.y - panel.frame.height - 15
            
            if x + panel.frame.width > screen.visibleFrame.maxX {
                x = screen.visibleFrame.maxX - panel.frame.width - 10
            }
            if y < screen.visibleFrame.minY {
                y = screen.visibleFrame.minY + 10
            }
            
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func setupHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isCommand = event.modifierFlags.contains(.command)
            let isOption = event.modifierFlags.contains(.option)
            
            if isCommand && isOption && event.keyCode == 5 {
                DispatchQueue.main.async {
                    self?.copySelectedText()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if let clipboardText = NSPasteboard.general.string(forType: .string) {
                            self?.appState.contextText = clipboardText
                        }
                        self?.toggleOverlay()
                    }
                }
            }
        }
    }
    
    func copySelectedText() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}

class AppState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var responseText: String = ""
    @Published var contextText: String = ""
    @Published var selectedModel: String = "gemini"
    @Published var apiKey: String = ""
    @Published var showSettings: Bool = false
    
    init() {
        // Load saved API key from UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    }
    
    func saveApiKey() {
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
    }
}
