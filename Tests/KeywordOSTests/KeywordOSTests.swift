import Foundation
import Testing
@testable import KeywordOS

@Suite("KeywordOS")
struct KeywordOSTests {
    @Test("Persists generated identifiers")
    func persistsGeneratedIdentifiers() {
        let suiteName = "KeywordOSTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let sdk = KeywordOS(storage: storage, urlSession: .shared)

        #expect(sdk.anonymousUserId == sdk.anonymousUserId)
        #expect(sdk.appAccountToken == sdk.appAccountToken)
    }

    @Test("Allows app account token override")
    func allowsAppAccountTokenOverride() {
        let suiteName = "KeywordOSTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let sdk = KeywordOS(storage: storage, urlSession: .shared)
        let token = UUID()

        sdk.setAppAccountToken(token)

        #expect(sdk.appAccountToken == token)
    }

    @Test("Allows string app user ID token")
    func allowsStringAppUserIDToken() {
        let suiteName = "KeywordOSTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let sdk = KeywordOS(storage: storage, urlSession: .shared)

        sdk.setAppUserIDToken("user_12345")

        #expect(sdk.appUserIDToken == "user_12345")
    }

    @Test("Sends app user ID token in attribution request")
    func sendsAppUserIDTokenInAttributionRequest() async throws {
        let suiteName = "KeywordOSTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        defer { storage.removePersistentDomain(forName: suiteName) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [KeywordOSMockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let sdk = KeywordOS(storage: storage, urlSession: urlSession)
        let appAccountToken = UUID()
        let expectedAppUserIDToken = "developer_user_123"
        let bodyCapture = LockedValue<[String: Any]?>(nil)

        sdk.configure(
            KeywordOSConfiguration(
                appId: "app_test",
                apiKey: "kos_pub_test",
                environment: .production,
                apiBaseURL: URL(string: "https://api.keywordos.test")!,
                bundleId: "io.keywordos.test",
                country: "US"
            )
        )
        sdk.setAppAccountToken(appAccountToken)
        sdk.setAppUserIDToken(expectedAppUserIDToken)

        KeywordOSMockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://api.keywordos.test/sdk/attribution")
            #expect(request.value(forHTTPHeaderField: "X-KeywordOS-SDK-Key") == "kos_pub_test")

            let body = try #require(requestBodyData(from: request))
            let json = try #require(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            bodyCapture.set(json)

            let responseBody: [String: Any] = [
                "ok": true,
                "userId": "app_user_row",
                "appAccountToken": appAccountToken.uuidString,
                "appUserIDToken": expectedAppUserIDToken,
                "attributed": true
            ]
            let responseData = try JSONSerialization.data(withJSONObject: responseBody)
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, responseData)
        }
        defer { KeywordOSMockURLProtocol.requestHandler = nil }

        let result = try await sdk.start()
        let sentBody = try #require(bodyCapture.value)

        #expect(sentBody["appId"] as? String == "app_test")
        #expect(sentBody["appAccountToken"] as? String == appAccountToken.uuidString)
        #expect(sentBody["appUserIDToken"] as? String == expectedAppUserIDToken)
        #expect(sentBody["bundleId"] as? String == "io.keywordos.test")
        #expect(sentBody["country"] as? String == "US")
        #expect(sentBody["environment"] as? String == "production")
        #expect(result.appUserIDToken == expectedAppUserIDToken)
        #expect(result.appAccountToken == appAccountToken)
    }

    @Test("Requires configuration before start")
    func requiresConfigurationBeforeStart() async {
        let suiteName = "KeywordOSTests.\(UUID().uuidString)"
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

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    var value: Value {
        lock.withLock { storage }
    }

    func set(_ value: Value) {
        lock.withLock {
            storage = value
        }
    }
}

private final class KeywordOSMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: KeywordOSMockError.missingHandler)
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum KeywordOSMockError: Error {
    case missingHandler
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)

        if read < 0 {
            return nil
        }

        if read == 0 {
            break
        }

        data.append(buffer, count: read)
    }

    return data
}
