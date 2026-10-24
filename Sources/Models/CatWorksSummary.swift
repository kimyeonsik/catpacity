import Foundation

public enum CatWorksUsageStatus: String, Decodable, Sendable {
    case complete, partial, unavailable
}

public enum CatWorksConnectionError: Error, LocalizedError, Sendable {
    case incompatible, invalidResponse, tooLarge, unavailable

    public var errorDescription: String? {
        switch self {
        case .incompatible: return "CatWorks 연동을 지원하는 사무실 서버인지 확인해주세요."
        case .invalidResponse: return "사무실의 사용량 응답 형식을 확인하지 못했습니다."
        case .tooLarge: return "사무실 응답이 허용된 크기를 초과했습니다."
        case .unavailable: return "로컬 사무실에 연결하지 못했습니다. 사무실을 실행한 뒤 다시 확인해주세요."
        }
    }
}

public struct CatWorksTokenAmount: Decodable, Sendable {
    public let status: CatWorksUsageStatus
    public let missingCount: Int
    public let inputTokens: Int?
    public let newInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let cacheWriteInputTokens: Int?
    public let outputTokens: Int?

    func validate() throws {
        let values = [inputTokens, newInputTokens, cacheReadInputTokens, cacheWriteInputTokens, outputTokens]
        guard missingCount >= 0,
              values.compactMap({ $0 }).allSatisfy({ $0 >= 0 && $0 <= 9_007_199_254_740_991 }) else {
            throw CatWorksConnectionError.invalidResponse
        }
        if status == .complete && [inputTokens, newInputTokens, cacheReadInputTokens, outputTokens].contains(where: { $0 == nil }) {
            throw CatWorksConnectionError.invalidResponse
        }
        if let input = inputTokens, let cached = cacheReadInputTokens {
            guard cached <= input else { throw CatWorksConnectionError.invalidResponse }
            if let fresh = newInputTokens, fresh != input - cached { throw CatWorksConnectionError.invalidResponse }
        }
        if let written = cacheWriteInputTokens, let fresh = newInputTokens, written > fresh {
            throw CatWorksConnectionError.invalidResponse
        }
    }
}

public struct CatWorksProviderSummary: Decodable, Sendable {
    public let providerId: String
    public let today: CatWorksTokenAmount
    public let lastUsageAt: Date?
    public let observedSince: Date?
}

public struct CatWorksSummary: Decodable, Sendable {
    public let schemaVersion: Int
    public let scope: String
    public let responseAt: Date
    public let date: String
    public let timeZone: String
    public let today: CatWorksTokenAmount
    public let providers: [CatWorksProviderSummary]
    public let accountLimits: AccountLimits

    public struct AccountLimits: Decodable, Sendable {
        public let status: String
    }

    public static func decode(_ data: Data) throws -> CatWorksSummary {
        do {
            let value = try CatWorksContract.decoder().decode(CatWorksSummary.self, from: data)
            guard value.schemaVersion == 1, value.scope == "local-observed",
                  value.timeZone == "Asia/Seoul", value.accountLimits.status == "notIncluded" else {
                throw CatWorksConnectionError.incompatible
            }
            let calendar = DateFormatter()
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: value.timeZone)
            calendar.dateFormat = "yyyy-MM-dd"
            calendar.isLenient = false
            guard value.date.count == 10, let day = calendar.date(from: value.date),
                  calendar.string(from: day) == value.date,
                  calendar.string(from: value.responseAt) == value.date,
                  value.providers.count <= 64,
                  Set(value.providers.map(\.providerId)).count == value.providers.count else {
                throw CatWorksConnectionError.invalidResponse
            }
            try value.today.validate()
            for provider in value.providers {
                guard !provider.providerId.isEmpty, provider.providerId.utf8.count <= 128,
                      !provider.providerId.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                    throw CatWorksConnectionError.invalidResponse
                }
                try provider.today.validate()
            }
            return value
        } catch let error as CatWorksConnectionError {
            throw error
        } catch {
            throw CatWorksConnectionError.invalidResponse
        }
    }
}

enum CatWorksContract {
    static let baseURL = URL(string: "http://127.0.0.1:4318")!
    static let summaryPath = "/api/office/companion/v1/summary"
    static let bundleID = "io.pixeloffice.desktop"
    static let maximumBytes = 1_048_576
    static let previewPath = "/observe/preview"
    static let previewWidth = 1360
    static let previewHeight = 760

    /// Both the advertised capability and the destination remain fixed, even on an older server.
    static func isPreviewNavigationAllowed(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return parts.scheme == "http" && parts.host == "127.0.0.1" && parts.port == 4318
            && parts.user == nil && parts.password == nil && parts.percentEncodedPath == previewPath
            && parts.query == nil && parts.fragment == nil
    }

    static func officeURL(statistics: Bool, native: Bool) -> URL {
        URL(string: native
            ? (statistics ? "catworks://statistics" : "catworks://office")
            : "\(baseURL.absoluteString)/observe\(statistics ? "#statistics" : "")")!
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { input in
            let container = try input.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw CatWorksConnectionError.invalidResponse
        }
        return decoder
    }

    static func validateHealth(_ data: Data) throws {
        _ = try connection(from: data)
    }

    static func connection(from data: Data) throws -> CatWorksConnection {
        struct Health: Decodable {
            struct Companion: Decodable {
                struct DeepLinks: Decodable { let office: String; let statistics: String }
                struct OfficePreview: Decodable {
                    let version: Int
                    let path: String
                    let width: Int
                    let height: Int
                    let readOnly: Bool
                }
                let schemaVersion: Int
                let summaryPath: String
                let deepLinks: DeepLinks
                let officePreview: OfficePreview?
            }
            let application: String
            let protocolVersion: Int
            let pid: Int
            let companion: Companion
        }
        guard let health = try? JSONDecoder().decode(Health.self, from: data),
              health.application == "pixel-office-observer", health.protocolVersion == 1, health.pid > 0,
              health.companion.schemaVersion == 1, health.companion.summaryPath == summaryPath,
              health.companion.deepLinks.office == "catworks://office",
              health.companion.deepLinks.statistics == "catworks://statistics" else {
            throw CatWorksConnectionError.incompatible
        }
        let preview = health.companion.officePreview
        let supported = preview?.version == 1 && preview?.path == previewPath
            && preview?.width == previewWidth && preview?.height == previewHeight && preview?.readOnly == true
        return CatWorksConnection(serverPID: health.pid, previewSupported: supported)
    }
}

struct CatWorksConnection: Sendable {
    let serverPID: Int
    let previewSupported: Bool
}

struct CatWorksSnapshot: Sendable {
    let summary: CatWorksSummary
    let connection: CatWorksConnection?
}
