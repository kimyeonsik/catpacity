import Foundation

/// Read the real local companion API without launching Catpacity or its account services.
@main
private struct CheckCatWorks {
    static func main() async throws {
        let summary = try await CatWorksHTTPReader().fetchSummary()
        print("CatWorks companion v\(summary.schemaVersion): \(summary.date) · \(summary.timeZone) · \(summary.today.status.rawValue)")
        print("Provider summaries: \(summary.providers.count); account limits: \(summary.accountLimits.status)")
    }
}
