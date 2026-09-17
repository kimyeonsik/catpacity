import Foundation
import AppKit

public class SelfUpdateService {
    public static let shared = SelfUpdateService()
    
    private let repo = "kimyeonsik/catpacity"
    
    public func performUpdate(
        tag: String,
        onProgress: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        onProgress("최신 릴리즈 패키지 확인 중...")
        
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let downloadUrlString: String
        if !cleanTag.isEmpty {
            downloadUrlString = "https://github.com/\(repo)/releases/download/\(cleanTag)/Catpacity-macOS.zip"
        } else {
            downloadUrlString = "https://github.com/\(repo)/releases/latest/download/Catpacity-macOS.zip"
        }
        
        guard let downloadUrl = URL(string: downloadUrlString) else {
            onError("다운로드 URL이 유효하지 않습니다.")
            return
        }
        
        onProgress("최신 버전 다운로드 중...")
        
        var request = URLRequest(url: downloadUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 45.0
        request.setValue("Catpacity-macOS-Updater", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession(configuration: .default)
        let task = session.downloadTask(with: request) { [weak self] tempLocalUrl, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    onError("다운로드 실패: \(error.localizedDescription)")
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    onError("다운로드 실패 (HTTP \(httpResponse.statusCode))")
                }
                return
            }
            
            guard let tempLocalUrl = tempLocalUrl else {
                DispatchQueue.main.async {
                    onError("다운로드된 파일 경로를 찾을 수 없습니다.")
                }
                return
            }
            
            DispatchQueue.main.async {
                onProgress("압축 해제 및 설치 준비 중...")
            }
            
            self.installDownloadedZip(zipUrl: tempLocalUrl, onProgress: onProgress, onError: onError)
        }
        task.resume()
    }
    
    private func installDownloadedZip(
        zipUrl: URL,
        onProgress: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("catpacity_self_update_\(UUID().uuidString)")
            
            do {
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let destinationZip = tempDir.appendingPathComponent("Catpacity.zip")
                
                if fileManager.fileExists(atPath: destinationZip.path) {
                    try fileManager.removeItem(at: destinationZip)
                }
                try fileManager.copyItem(at: zipUrl, to: destinationZip)
                
                // Unzip downloaded archive
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-q", "-o", destinationZip.path, "-d", tempDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                
                if unzipProcess.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        onError("압축 해제 실패 (코드 \(unzipProcess.terminationStatus))")
                    }
                    return
                }
                
                let extractedApp = tempDir.appendingPathComponent("Catpacity.app")
                guard fileManager.fileExists(atPath: extractedApp.path) else {
                    DispatchQueue.main.async {
                        onError("압축 파일 내에서 Catpacity.app을 찾을 수 없습니다.")
                    }
                    return
                }
                
                // Clear quarantine attributes
                let xattrProcess = Process()
                xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProcess.arguments = ["-cr", extractedApp.path]
                try? xattrProcess.run()
                xattrProcess.waitUntilExit()
                
                // Determine target app path
                let currentBundlePath = Bundle.main.bundleURL.path
                let targetAppPath: String
                if currentBundlePath.hasPrefix("/Applications") || currentBundlePath.contains("Catpacity.app") {
                    targetAppPath = currentBundlePath
                } else if fileManager.fileExists(atPath: "/Applications/Catpacity.app") {
                    targetAppPath = "/Applications/Catpacity.app"
                } else {
                    targetAppPath = currentBundlePath
                }
                
                DispatchQueue.main.async {
                    onProgress("앱 교체 및 재시작 중...")
                }
                
                // Write standalone detachment script to handle process termination, file replacement, and restart
                let scriptPath = tempDir.appendingPathComponent("restart_updater.sh").path
                let scriptContent = """
                #!/bin/bash
                OLD_PID=$1
                TARGET_APP="$2"
                NEW_APP="$3"
                TEMP_DIR="$4"

                # 1. Wait for old process to exit
                for i in {1..50}; do
                    if ! kill -0 "$OLD_PID" 2>/dev/null; then
                        break
                    fi
                    sleep 0.2
                done

                # 2. Force kill if still hanging
                kill -9 "$OLD_PID" 2>/dev/null || true
                sleep 0.5

                # 3. Overwrite target application
                rm -rf "$TARGET_APP"
                cp -R "$NEW_APP" "$TARGET_APP"
                xattr -cr "$TARGET_APP" 2>/dev/null || true

                # 4. Relaunch newly updated app
                open "$TARGET_APP"

                # 5. Clean up temporary staging
                sleep 1
                rm -rf "$TEMP_DIR"
                """
                
                try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
                
                // Make script executable
                let chmodProc = Process()
                chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodProc.arguments = ["+x", scriptPath]
                try chmodProc.run()
                chmodProc.waitUntilExit()
                
                // Execute updater script detached
                let updateProcess = Process()
                updateProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                updateProcess.arguments = [
                    scriptPath,
                    String(ProcessInfo.processInfo.processIdentifier),
                    targetAppPath,
                    extractedApp.path,
                    tempDir.path
                ]
                try updateProcess.run()
                
                // Terminate current app cleanly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    onError("업데이트 설치 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}
