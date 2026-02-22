import Foundation
import AppKit
import CoreGraphics

class BackendBridge {
    
    /// Captures the entire screen as a JPEG and saves it to a temp file.
    /// Returns the file path.
    static func captureScreen() -> String? {
        // Use CGWindowListCreateImage to capture the full screen natively
        guard let cgImage = CGWindowListCreateImage(
            CGRect.null, // null = entire display
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
    
    /// Executes the Python backend, passing the screenshot, and returns the AI response.
    static func askSkibidysaurus(prompt: String, context: String = "", apiKey: String = "") async throws -> String {
        
        // Step 1: Capture screen natively in Swift
        let screenshotPath = captureScreen() ?? ""
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            // Resolve paths relative to the executable
            let executableURL = Bundle.main.executableURL!
            let buildDir = executableURL.deletingLastPathComponent()
            let skibidysaurusAppDir = buildDir.deletingLastPathComponent().deletingLastPathComponent()
            let projectRoot = skibidysaurusAppDir.deletingLastPathComponent()
            
            let pythonExecutable = projectRoot.appendingPathComponent("venv/bin/python").path
            let backendScript = projectRoot.appendingPathComponent("backend.py").path
            
            task.executableURL = URL(fileURLWithPath: pythonExecutable)
            
            var args = [
                backendScript,
                "--prompt", prompt,
                "--context", context
            ]
            
            // Pass the screenshot path if capture succeeded
            if !screenshotPath.isEmpty {
                args += ["--screenshot", screenshotPath]
            }
            
            task.arguments = args
            
            // Pass API key as environment variable
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
                    continuation.resume(throwing: NSError(
                        domain: "BackendBridge",
                        code: Int(task.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Python backend error: \(errorMsg)"]
                    ))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
