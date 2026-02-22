import SwiftUI

struct OverlayView: View {
    @ObservedObject var appState: AppState
    @State private var promptText: String = ""
    @State private var isProcessing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ── Header Row ──
            HStack {
                Text("🦖 Skibidysaurus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
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
            
            // ── Settings Panel (slides open) ──
            if appState.showSettings {
                SettingsPanelView(appState: appState)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // ── Model Picker ──
            HStack(spacing: 8) {
                Text("Model:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $appState.selectedModel) {
                    Text("Gemini").tag("gemini")
                    Text("Ollama").tag("ollama")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            
            // ── Input Row ──
            HStack(spacing: 8) {
                TextField("Ask Skibidysaurus...", text: $promptText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
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
                .disabled(isProcessing || promptText.isEmpty)
            }
            
            // ── Context Indicator ──
            if !appState.contextText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                    Text("Context: \(appState.contextText.prefix(60))...")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
            
            // ── Output Area (always visible) ──
            ScrollView {
                if appState.responseText.isEmpty {
                    Text("Response will appear here...")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    // Render Markdown natively
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
            .frame(maxHeight: 280)
        }
        .padding(16)
        .frame(width: 500)
        .frame(minHeight: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
    }
    
    // Parse Markdown string into AttributedString
    var markdownResponse: AttributedString {
        (try? AttributedString(markdown: appState.responseText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(appState.responseText)
    }
    
    func submitPrompt() {
        guard !promptText.isEmpty else { return }
        let currentPrompt = promptText
        let currentContext = appState.contextText
        isProcessing = true
        appState.responseText = ""
        
        Task {
            do {
                let result = try await BackendBridge.askSkibidysaurus(
                    prompt: currentPrompt,
                    context: currentContext,
                    apiKey: appState.apiKey
                )
                await MainActor.run {
                    appState.responseText = result
                    promptText = ""
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    appState.responseText = "Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
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
            
            // API Key Input
            HStack {
                Text("Gemini API Key:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                SecureField("Paste your API key...", text: $appState.apiKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            
            HStack {
                Spacer()
                Button("Save") {
                    appState.saveApiKey()
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
