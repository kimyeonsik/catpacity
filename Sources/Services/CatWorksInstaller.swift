import AppKit
import Combine
import CoreServices
import Foundation

/// Installs only on an explicit click. The bundled, reviewed installer never
/// replaces an existing app or changes the user's office data or macOS policy.
@MainActor
final class CatWorksInstaller: ObservableObject {
    @Published private(set) var isInstalling = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var installedApplicationURL: URL?

    static let releasesURL = URL(string: "https://github.com/kimyeonsik/catpacity/releases?q=catworks-")!

    func install() async {
        guard !isInstalling else { return }
        errorMessage = nil
        installedApplicationURL = nil
        guard let script = Bundle.main.url(forResource: "install-catworks", withExtension: "sh") else {
            errorMessage = "설치 도구를 찾지 못했어요. 다운로드 페이지에서 설치 파일을 받아 주세요."
            return
        }
        isInstalling = true
        statusMessage = "다운로드·검증·설치 중이에요. 잠시 기다려 주세요."
        defer { isInstalling = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try CatWorksInstallProcess.run(script: script)
            }.value
            guard result.exitCode == 0 else {
                statusMessage = nil
                errorMessage = result.userMessage
                return
            }
            let destination = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/CatWorks.app", isDirectory: true)
            guard let bundle = Bundle(url: destination),
                  bundle.bundleIdentifier == "io.pixeloffice.desktop" else {
                statusMessage = nil
                errorMessage = "설치 결과를 확인하지 못했어요. 다운로드 페이지에서 다시 확인해 주세요."
                return
            }
            installedApplicationURL = destination
            // Register the newly copied app without launching it. Opening stays
            // a separate user action and preserves any macOS first-launch prompt.
            LSRegisterURL(destination as CFURL, true)
            statusMessage = "설치했어요. ‘사무실 열기’를 누르면 CatWorks가 시작됩니다."
        } catch {
            statusMessage = nil
            errorMessage = "설치 도구를 실행하지 못했어요. 다운로드 페이지에서 설치 파일을 받아 주세요."
        }
    }
}

struct CatWorksInstallResult: Sendable {
    let exitCode: Int32
    let output: String

    var userMessage: String {
        if output.contains("GitHub CLI(gh)") {
            return "현재 비공개 배포는 GitHub CLI가 필요해요. GitHub CLI 설치와 로그인을 마친 뒤 다시 시도하거나 다운로드 페이지를 이용해 주세요."
        }
        if output.contains("gh auth login") {
            return "CatWorks 비공개 저장소에 접근할 수 있는 GitHub 로그인이 필요해요. 터미널에서 gh auth login을 실행한 뒤 다시 시도해 주세요."
        }
        if output.contains("기존 앱") || output.contains("같은 이름의 앱") {
            return "이미 설치된 앱이 있어 덮어쓰지 않았어요. ‘다시 확인’을 누른 뒤 사무실을 열어 주세요."
        }
        if output.contains("릴리스") || output.contains("DMG가 없습니다") {
            return "이 Mac에 설치할 배포 파일을 찾지 못했어요. 다운로드 페이지에서 접근 권한과 배포 상태를 확인해 주세요."
        }
        if output.contains("체크섬") || output.contains("서명") || output.contains("식별자") || output.contains("실행 코드") {
            return "다운로드한 앱의 무결성을 확인하지 못해 설치하지 않았어요. 잠시 후 다시 시도해 주세요."
        }
        return "설치를 마치지 못했어요. 네트워크와 GitHub 저장소 접근 권한을 확인하거나 다운로드 페이지를 이용해 주세요."
    }
}

enum CatWorksInstallProcess {
    static func run(script: URL) throws -> CatWorksInstallResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        // Do not allow ambient overrides to redirect the repository or target.
        for key in Array(environment.keys) where key.hasPrefix("CATWORKS_") { environment.removeValue(forKey: key) }
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["CATWORKS_REPO"] = "kimyeonsik/catpacity"
        environment["CATWORKS_CHANNEL"] = "preview"
        environment["CATWORKS_INSTALL_DIR"] = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_HTTP_TIMEOUT"] = "120"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        // Drain while running, retaining only a bounded diagnostic tail. No
        // subprocess output (which might include auth diagnostics) reaches UI.
        var tail = Data()
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            tail.append(data)
            if tail.count > 65_536 { tail.removeFirst(tail.count - 65_536) }
        }
        process.waitUntilExit()
        return CatWorksInstallResult(exitCode: process.terminationStatus, output: String(decoding: tail, as: UTF8.self))
    }
}
