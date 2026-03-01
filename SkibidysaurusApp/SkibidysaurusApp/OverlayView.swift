import SwiftUI

struct OverlayView: View {
    enum OverlayTab: String {
        case chat = "Chat"
        case history = "History"
    }

    @ObservedObject var appState: AppState
    @State private var promptText: String = ""
    @State private var isProcessing: Bool = false
    @State private var showCopied: Bool = false
    @State private var selectedTab: OverlayTab = .chat
    @FocusState private var promptFieldFocused: Bool

    private let quickActions = [
        "rewrite this to sound clear + confident",
        "summarize this in 3 bullets",
        "turn this into a polite reply",
        "find risks or mistakes in this"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🦖 Skibidysaurus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("menu bar ai copilot")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    appState.contextText = ""
                }) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear context")

                Button(action: {
                    appState.showSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
            }

            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("summon shortcut: cmd + option + g")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }

            HStack(spacing: 8) {
                Toggle(isOn: $appState.attachScreenContext) {
                    Text("attach screen context")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .toggleStyle(.switch)
                .onChange(of: appState.attachScreenContext) { _ in
                    appState.saveAttachScreenContext()
                }
                Spacer()
                Text(appState.attachScreenContext ? "on submit" : "off (fastest)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Toggle(isOn: $appState.shareEntireScreen) {
                    Text("share entire screen (includes browsers)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .toggleStyle(.switch)
                .onChange(of: appState.shareEntireScreen) { _ in
                    appState.saveScreenSharingMode()
                }
                .disabled(!appState.attachScreenContext)
                Spacer()
                Text("captured only when you submit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if appState.showOnboarding {
                OnboardingCard {
                    appState.completeOnboarding()
                }
            }

            if appState.showSettings {
                SettingsPanelView(appState: appState)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                Text("Model:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Picker("", selection: $appState.selectedModel) {
                    Text("Gemini").tag("gemini")
                    Text("Ollama").tag("ollama")
                    Text("OpenAI").tag("openai")
                    Text("Claude").tag("claude")
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
                .onChange(of: appState.selectedModel) { _ in
                    appState.saveSelectedModel()
                }

                Spacer()

                Picker("", selection: $selectedTab) {
                    Text(OverlayTab.chat.rawValue).tag(OverlayTab.chat)
                    Text(OverlayTab.history.rawValue).tag(OverlayTab.history)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 170)
            }

            if selectedTab == .chat {
                chatView
            } else {
                historyView
            }
        }
        .padding(16)
        .frame(width: 520)
        .frame(minHeight: 420)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(16)
        .onChange(of: appState.promptFocusRequestID) { _ in
            guard appState.voiceFocusMode else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                promptFieldFocused = true
            }
        }
    }

    private var chatView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickActions, id: \.self) { action in
                        Button(action) {
                            promptText = action
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Ask Skibidysaurus...", text: $promptText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .focused($promptFieldFocused)
                    .disabled(isProcessing)
                    .onSubmit {
                        submitPrompt()
                    }

                Button(action: {
                    submitPrompt()
                }) {
                    Text(isProcessing ? "Thinking..." : "Submit")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isProcessing ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing || promptText.isEmpty || needsApiKey)
            }

            if !appState.contextText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                    Text("Context: \(appState.contextText.prefix(80))...")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }

            if needsApiKey {
                Text(missingApiKeyMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
            }

            ScrollView {
                if appState.responseText.isEmpty {
                    Text("response will appear here...")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    Text(markdownResponse)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)
            .frame(maxHeight: 260)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            if !appState.responseText.isEmpty {
                HStack {
                    Button(showCopied ? "Copied" : "Copy response") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.responseText, forType: .string)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            showCopied = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Text("\(appState.responseText.count) chars")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent prompts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Clear") {
                    appState.clearHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.history.isEmpty)
            }

            ScrollView {
                if appState.history.isEmpty {
                    Text("no history yet. submit a prompt and it’ll show up here.")
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.history) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.prompt)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    Spacer()
                                    Button("Reuse") {
                                        selectedTab = .chat
                                        promptText = item.prompt
                                        appState.responseText = item.response
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }

                                Text(item.response)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)

                                Text(relativeDate(item.createdAt))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }

    var markdownResponse: AttributedString {
        (try? AttributedString(markdown: appState.responseText)) ?? AttributedString(appState.responseText)
    }

    var needsApiKey: Bool {
        switch appState.selectedModel {
        case "gemini":
            return appState.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "openai":
            return appState.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "claude":
            return appState.anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    var missingApiKeyMessage: String {
        switch appState.selectedModel {
        case "gemini":
            return "add your gemini api key in settings to submit prompts."
        case "openai":
            return "add your openai api key in settings to submit prompts."
        case "claude":
            return "add your anthropic api key in settings to submit prompts."
        default:
            return "missing provider key in settings."
        }
    }

    var captureMode: BackendBridge.ScreenCaptureMode {
        guard appState.attachScreenContext else { return .none }
        return appState.shareEntireScreen ? .entireDesktop : .focusedWindows
    }

    func submitPrompt(forcePrompt: String? = nil) {
        let effectivePrompt = (forcePrompt ?? promptText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !effectivePrompt.isEmpty else { return }
        if needsApiKey {
            appState.responseText = missingApiKeyMessage
            return
        }
        let currentPrompt = effectivePrompt
        let currentContext = appState.contextText
        isProcessing = true
        if forcePrompt == nil {
            appState.responseText = ""
        }

        Task {
            do {
                let result = try await BackendBridge.askSkibidysaurus(
                    prompt: currentPrompt,
                    context: currentContext,
                    geminiApiKey: appState.geminiApiKey,
                    openAIApiKey: appState.openAIApiKey,
                    anthropicApiKey: appState.anthropicApiKey,
                    captureMode: captureMode,
                    engine: appState.selectedModel,
                    ollamaModel: appState.ollamaModel,
                    openAIModel: appState.openAIModel,
                    claudeModel: appState.claudeModel
                )
                await MainActor.run {
                    appState.responseText = result
                    appState.addHistory(prompt: currentPrompt, response: result)
                    if forcePrompt == nil {
                        promptText = ""
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    appState.responseText = friendlyErrorMessage(error.localizedDescription)
                    isProcessing = false
                }
            }
        }
    }

    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func friendlyErrorMessage(_ rawMessage: String) -> String {
        let msg = rawMessage.lowercased()
        if msg.contains("venv/bin/python") || msg.contains("no such file or directory") {
            return "Backend is not set up yet. Run setup.sh once, then relaunch the app."
        }
        if msg.contains("module not found") || msg.contains("modulenotfounderror") {
            return "Some Python packages are missing. Run setup.sh again to reinstall dependencies."
        }
        if msg.contains("api key") || msg.contains("gemini_api_key") {
            return "A provider key is missing or invalid. Update it in Settings and retry."
        }
        if msg.contains("ollama error") {
            return rawMessage
        }
        if msg.contains("openai error") || msg.contains("claude error") {
            return rawMessage
        }
        return "Couldn’t run the AI request. Check setup + permissions, then try again."
    }
}

struct OnboardingCard: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("quick setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Text("1) enable screen recording\n2) add provider key in settings\n3) hit cmd + option + g anytime")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("got it") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.32))
        .cornerRadius(10)
    }
}

// ── Settings Inline Panel ──
struct SettingsPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            HStack {
                Text("Gemini API Key:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                SecureField("Paste your Gemini key...", text: $appState.geminiApiKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }

            HStack {
                Text("OpenAI API Key:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                SecureField("Paste your OpenAI key...", text: $appState.openAIApiKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }

            HStack {
                Text("Claude API Key:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                SecureField("Paste your Anthropic key...", text: $appState.anthropicApiKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }

            HStack {
                Text("Ollama Model:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                TextField("llava:latest", text: $appState.ollamaModel)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            Text("for screen-aware answers, use a vision model (example: llava:latest).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Text("OpenAI Model:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                TextField("gpt-4.1-mini", text: $appState.openAIModel)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }

            HStack {
                Text("Claude Model:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                TextField("claude-3-5-haiku-latest", text: $appState.claudeModel)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }

            Toggle(isOn: $appState.voiceFocusMode) {
                Text("Voice Focus Mode (auto-focus prompt on open)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.switch)

            HStack {
                Spacer()
                Button("Save") {
                    appState.saveApiKeys()
                    appState.saveOllamaModel()
                    appState.saveOpenAIModel()
                    appState.saveClaudeModel()
                    appState.saveVoiceFocusMode()
                    appState.showSettings = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()
        }
        .padding(.vertical, 4)
    }
}

// ── Native macOS Blur Background ──
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
