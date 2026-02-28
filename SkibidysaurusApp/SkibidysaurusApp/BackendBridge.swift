import Foundation
import AppKit
import CoreGraphics

class BackendBridge {
    enum ScreenCaptureMode {
        case none
        case focusedWindows
        case entireDesktop
    }
    
    /// Captures the entire screen as a JPEG and saves it to a temp file.
    static func captureScreen(mode: ScreenCaptureMode) -> String? {
        let image: CGImage?
        switch mode {
        case .none:
            return nil
        case .focusedWindows:
            image = CGWindowListCreateImage(
                CGRect.null,
                .optionOnScreenOnly,
                kCGNullWindowID,
                .bestResolution
            )
        case .entireDesktop:
            image = CGWindowListCreateImage(
                CGRect.infinite,
                .optionAll,
                kCGNullWindowID,
                [.bestResolution, .boundsIgnoreFraming]
            )
        }

        guard let cgImage = image else {
            return nil
        }

        let normalizedImage = downsampleIfNeeded(cgImage, maxDimension: 1280) ?? cgImage
        
        let bitmapRep = NSBitmapImageRep(cgImage: normalizedImage)
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.45]
        ) else {
            return nil
        }
        
        let tempPath = NSTemporaryDirectory() + "skibidysaurus_screenshot.jpg"
        do {
            try jpegData.write(to: URL(fileURLWithPath: tempPath))
            return tempPath
        } catch {
            return nil
        }
    }

    private static func downsampleIfNeeded(_ cgImage: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return nil }

        let scale = maxDimension / longest
        let targetSize = NSSize(width: width * scale, height: height * scale)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        NSGraphicsContext.restoreGraphicsState()

        return rep.cgImage
    }
    
    /// Resolves the project root directory (hover_gpt/) from the executable location.
    static func resolveProjectRoot() -> String {
        // 1) Explicit install location from launcher script env.
        if let installedHome = ProcessInfo.processInfo.environment["SKIBIDYSAURUS_HOME"],
           FileManager.default.fileExists(atPath: installedHome + "/backend.py") {
            return installedHome
        }

        // 2) Standard installed location in Application Support.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let appSupportPath = appSupport?.appendingPathComponent("Skibidysaurus").path,
           FileManager.default.fileExists(atPath: appSupportPath + "/backend.py") {
            return appSupportPath
        }

        // For Swift PM, the executable is at:
        //   SkibidysaurusApp/.build/debug/Skibidysaurus
        // We need to get to hover_gpt/ which is the parent of SkibidysaurusApp/
        
        // Strategy: Use the executable path to walk up the directory tree
        if let execURL = Bundle.main.executableURL {
            // .build/debug/Skibidysaurus -> .build/debug/ -> .build/ -> SkibidysaurusApp/ -> hover_gpt/
            let projectRoot = execURL
                .deletingLastPathComponent()  // .build/debug/
                .deletingLastPathComponent()  // .build/
                .deletingLastPathComponent()  // SkibidysaurusApp/
                .deletingLastPathComponent()  // hover_gpt/
            
            let testPath = projectRoot.appendingPathComponent("backend.py").path
            if FileManager.default.fileExists(atPath: testPath) {
                return projectRoot.path
            }
        }
        
        // Fallback: Check current working directory
        let cwd = FileManager.default.currentDirectoryPath
        // If cwd is SkibidysaurusApp, go up one level
        if cwd.hasSuffix("SkibidysaurusApp") {
            let parent = URL(fileURLWithPath: cwd).deletingLastPathComponent().path
            if FileManager.default.fileExists(atPath: parent + "/backend.py") {
                return parent
            }
        }
        
        // If cwd itself has backend.py
        if FileManager.default.fileExists(atPath: cwd + "/backend.py") {
            return cwd
        }
        
        // Last resort fallback
        return cwd
    }
    
    /// Executes the Python backend and returns the AI response.
    static func askSkibidysaurus(
        prompt: String,
        context: String = "",
        apiKey: String = "",
        captureMode: ScreenCaptureMode = .entireDesktop,
        engine: String = "gemini",
        ollamaModel: String = "llava"
    ) async throws -> String {
        
        // Step 1: Capture screen natively
        let screenshotPath = captureScreen(mode: captureMode) ?? ""
        
        // Step 2: Resolve paths
        let projectRoot = resolveProjectRoot()
        let pythonExecutable = projectRoot + "/venv/bin/python"
        let backendScript = projectRoot + "/backend.py"

        guard FileManager.default.fileExists(atPath: pythonExecutable) else {
            throw NSError(
                domain: "BackendBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Python environment not found at \(pythonExecutable)"]
            )
        }
        guard FileManager.default.fileExists(atPath: backendScript) else {
            throw NSError(
                domain: "BackendBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Backend script not found at \(backendScript)"]
            )
        }
        
        // Debug: Print paths so we can verify
        print("[BackendBridge] Project root: \(projectRoot)")
        print("[BackendBridge] Python: \(pythonExecutable)")
        print("[BackendBridge] Backend: \(backendScript)")
        print("[BackendBridge] Python exists: \(FileManager.default.fileExists(atPath: pythonExecutable))")
        print("[BackendBridge] Backend exists: \(FileManager.default.fileExists(atPath: backendScript))")
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: pythonExecutable)
            
            var args = [backendScript, "--prompt", prompt, "--context", context, "--engine", engine]
            if engine == "ollama" {
                args += ["--ollama-model", ollamaModel]
            }
            if !screenshotPath.isEmpty {
                args += ["--screenshot", screenshotPath]
            }
            task.arguments = args
            
            // Set the working directory to the project root
            // This is critical so Python can find llm/ and core/ modules
            task.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
            
            // Pass API key
            var env = ProcessInfo.processInfo.environment
            if !apiKey.isEmpty {
                env["GEMINI_API_KEY"] = apiKey
            }
            env["PYTHONWARNINGS"] = "ignore"
            task.environment = env
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                DispatchQueue.global(qos: .userInitiated).async {
                    task.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if !screenshotPath.isEmpty {
                        try? FileManager.default.removeItem(atPath: screenshotPath)
                    }

                    if task.terminationStatus == 0, let output = String(data: outputData, encoding: .utf8) {
                        continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        let outputMsg = String(data: outputData, encoding: .utf8) ?? ""
                        let fullError = (errorMsg + "\n" + outputMsg).trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: NSError(
                            domain: "BackendBridge",
                            code: Int(task.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: fullError]
                        ))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
