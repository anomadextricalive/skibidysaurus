import SwiftUI
import AppKit
import Carbon.HIToolbox

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
    private var globalHotkeyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Menu Bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Skibidysaurus")
            button.action = #selector(toggleOverlay)
            button.target = self
        }
        setupMenu()
        
        createOverlayPanel()
        setupHotkey()
        
        print("Skibidysaurus Swift Frontend Started!")
    }

    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Skibidysaurus", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
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
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                appDelegate.handleGlobalHotkey()
                return noErr
            },
            1,
            &eventType,
            userData,
            &hotKeyHandlerRef
        )

        let signature = fourCharCode("SKBD")
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let modifiers = UInt32(cmdKey | optionKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        // fallback monitor kept for environments where hotkey registration is blocked.
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command),
               event.modifierFlags.contains(.option),
               event.keyCode == UInt16(kVK_ANSI_G) {
                self?.handleGlobalHotkey()
            }
        }
    }

    func handleGlobalHotkey() {
        DispatchQueue.main.async { [weak self] in
            let previousClipboard = NSPasteboard.general.string(forType: .string)
            self?.copySelectedText()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard let self else { return }
                if let clipboardText = NSPasteboard.general.string(forType: .string),
                   clipboardText != previousClipboard,
                   !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.appState.contextText = clipboardText
                }
                self.toggleOverlay()
            }
        }
    }

    private func fourCharCode(_ value: String) -> FourCharCode {
        value.utf16.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
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
    struct HistoryItem: Identifiable, Codable {
        let id: UUID
        let prompt: String
        let response: String
        let createdAt: Date
    }

    @Published var isVisible: Bool = false
    @Published var responseText: String = ""
    @Published var contextText: String = ""
    @Published var selectedModel: String = "gemini"
    @Published var ollamaModel: String = "llava"
    @Published var apiKey: String = ""
    @Published var showSettings: Bool = false
    @Published var history: [HistoryItem] = []
    @Published var showOnboarding: Bool = false
    @Published var attachScreenContext: Bool = true
    @Published var shareEntireScreen: Bool = true
    
    init() {
        // Load saved API key from UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gemini"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollama_model") ?? "llava"
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "did_complete_onboarding")
        self.attachScreenContext = UserDefaults.standard.object(forKey: "attach_screen_context") as? Bool ?? true
        self.shareEntireScreen = UserDefaults.standard.object(forKey: "share_entire_screen") as? Bool ?? true
        loadHistory()
    }
    
    func saveApiKey() {
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
    }

    func saveSelectedModel() {
        UserDefaults.standard.set(selectedModel, forKey: "selected_model")
    }

    func saveOllamaModel() {
        UserDefaults.standard.set(ollamaModel, forKey: "ollama_model")
    }

    func saveScreenSharingMode() {
        UserDefaults.standard.set(shareEntireScreen, forKey: "share_entire_screen")
    }

    func saveAttachScreenContext() {
        UserDefaults.standard.set(attachScreenContext, forKey: "attach_screen_context")
    }

    func addHistory(prompt: String, response: String) {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !trimmedResponse.isEmpty else { return }

        history.insert(
            HistoryItem(id: UUID(), prompt: trimmedPrompt, response: trimmedResponse, createdAt: Date()),
            at: 0
        )

        if history.count > 25 {
            history = Array(history.prefix(25))
        }

        saveHistory()
    }

    func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: "prompt_history")
    }

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "did_complete_onboarding")
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: "prompt_history")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "prompt_history") else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([HistoryItem].self, from: data) {
            history = decoded
        }
    }
}
