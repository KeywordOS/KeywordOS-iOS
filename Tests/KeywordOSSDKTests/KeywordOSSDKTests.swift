import Foundation
import Testing
@testable import KeywordOSSDK

@Suite("KeywordOSSDK")
struct KeywordOSSDKTests {
    @Test("Persists generated identifiers")
    func persistsGeneratedIdentifiers() {
        let suiteName = "KeywordOSSDKTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let sdk = KeywordOS(storage: storage, urlSession: .shared)

        #expect(sdk.anonymousUserId == sdk.anonymousUserId)
        #expect(sdk.appAccountToken == sdk.appAccountToken)
    }

    @Test("Requires configuration before start")
    func requiresConfigurationBeforeStart() async {
        let suiteName = "KeywordOSSDKTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let sdk = KeywordOS(storage: storage, urlSession: .shared)
        var didThrowNotConfigured = false

        do {
            _ = try await sdk.start()
            Issue.record("Expected start() to throw before configure")
        } catch KeywordOSError.notConfigured {
            didThrowNotConfigured = true
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(didThrowNotConfigured)
    }
}
