import Foundation
import AppKit
import CoreGraphics

class BackendBridge {
    
    /// Captures the entire screen as a JPEG and saves it to a temp file.
    static func captureScreen() -> String? {
        guard let cgImage = CGWindowListCreateImage(
            CGRect.null,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.7]
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
    
    /// Resolves the project root directory (hover_gpt/) from the executable location.
    static func resolveProjectRoot() -> String {
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
    static func askSkibidysaurus(prompt: String, context: String = "", apiKey: String = "") async throws -> String {
        
        // Step 1: Capture screen natively
        let screenshotPath = captureScreen() ?? ""
        
        // Step 2: Resolve paths
        let projectRoot = resolveProjectRoot()
        let pythonExecutable = projectRoot + "/venv/bin/python"
        let backendScript = projectRoot + "/backend.py"
        
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
            
            var args = [backendScript, "--prompt", prompt, "--context", context]
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
            task.environment = env
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if task.terminationStatus == 0, let output = String(data: outputData, encoding: .utf8) {
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    let outputMsg = String(data: outputData, encoding: .utf8) ?? ""
                    let fullError = errorMsg + "\n" + outputMsg
                    continuation.resume(throwing: NSError(
                        domain: "BackendBridge",
                        code: Int(task.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: fullError.trimmingCharacters(in: .whitespacesAndNewlines)]
                    ))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
