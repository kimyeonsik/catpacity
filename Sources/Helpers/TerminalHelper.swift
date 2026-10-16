import Foundation
import AppKit

public enum TerminalHelper {
    /// 터미널 창을 열고 주어진 쉘 스크립트를 사용자 대화형 세션으로 실행합니다.
    /// - Parameters:
    ///   - title: 터미널 상단에 표시될 작업 제목
    ///   - script: 실행할 zsh 명령어 본문
    ///   - scriptName: 임시 파일 접두사
    ///   - completion: 실행 요청 완료 시 콜백
    public static func runInTerminal(
        title: String,
        script: String,
        scriptName: String = "catpacity_task",
        completion: (() -> Void)? = nil
    ) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "catpacity_\(scriptName)_\(UUID().uuidString.prefix(6)).command"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let bannerText = """
        echo ""
        echo "🐱 ========================================================"
        echo "   🐾 Catpacity: \(title)"
        echo "========================================================"
        echo ""
        """
        
        let fullScript = """
        #!/bin/zsh
        
        # 1. 일반적인 Node.js, Bun, Homebrew, Cargo 경로를 PATH에 선행 등록
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$HOME/Library/pnpm:$HOME/.cargo/bin:$PATH"
        
        # 2. 사용자 로그인 쉘 프로필이 있으면 로드 (nvm, fnm, mise, asdf 등 상속)
        [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile" 2>/dev/null
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null
        
        \(bannerText)
        
        \(script)
        
        echo ""
        echo "--------------------------------------------------------"
        echo "✨ 작업이 완료되었습니다! [Enter] 키를 누르면 창이 닫힙니다."
        read -k 1 -s
        exit 0
        """
        
        do {
            try fullScript.write(to: fileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
            
            // Terminal.app으로 .command 실행
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", fileURL.path]
            try process.run()
            
            DispatchQueue.main.async {
                completion?()
            }
        } catch {
            // Fallback: AppleScript 직접 실행
            fallbackAppleScript(title: title, command: script, completion: completion)
        }
    }
    
    private static func fallbackAppleScript(
        title: String,
        command: String,
        completion: (() -> Void)? = nil
    ) {
        let oneLiner = "echo '🐱 Catpacity: \(title)' && \(command)"
        let escaped = oneLiner.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: appleScript) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}
