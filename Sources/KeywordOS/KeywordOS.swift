import Foundation

public enum KeywordOSEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

public enum KeywordOSError: Error, Equatable {
    case notConfigured
    case invalidResponse
    case serverError(statusCode: Int)
}

public struct KeywordOSConfiguration: Sendable {
    public let appId: String
    public let apiKey: String
    public let environment: KeywordOSEnvironment
    public let apiBaseURL: URL
    public let bundleId: String?
    public let country: String?

    public init(
        appId: String,
        apiKey: String,
        environment: KeywordOSEnvironment,
        apiBaseURL: URL = URL(string: "https://api.keywordos.io")!,
        bundleId: String? = Bundle.main.bundleIdentifier,
        country: String? = KeywordOSLocale.currentRegionIdentifier
    ) {
        self.appId = appId
        self.apiKey = apiKey
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.bundleId = bundleId
        self.country = country
    }
}

public struct KeywordOSAttributionResult: Decodable, Equatable, Sendable {
    public let ok: Bool
    public let userId: String
    public let appAccountToken: UUID
    public let attributed: Bool
}

public final class KeywordOS: @unchecked Sendable {
    public static let shared = KeywordOS()

    private static let anonymousUserIdKey = "com.keywordos.sdk.anonymousUserId"
    private static let appAccountTokenKey = "com.keywordos.sdk.appAccountToken"

    private let storage: UserDefaults
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private var configuration: KeywordOSConfiguration?
    private var cachedAnonymousUserId: String?
    private var cachedAppAccountToken: UUID?

    public var anonymousUserId: String {
        getOrCreateAnonymousUserId()
    }

    public var appAccountToken: UUID {
        getOrCreateAppAccountToken()
    }

    public func setAppAccountToken(_ token: UUID) {
        storage.set(token.uuidString, forKey: Self.appAccountTokenKey)
        cachedAppAccountToken = token
    }

    public convenience init() {
        self.init(storage: .standard, urlSession: .shared)
    }

    init(storage: UserDefaults, urlSession: URLSession) {
        self.storage = storage
        self.urlSession = urlSession
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    public static func configure(
        appId: String,
        apiKey: String,
        environment: KeywordOSEnvironment,
        apiBaseURL: URL = URL(string: "https://api.keywordos.io")!,
        bundleId: String? = Bundle.main.bundleIdentifier,
        country: String? = KeywordOSLocale.currentRegionIdentifier
    ) {
        shared.configure(
            KeywordOSConfiguration(
                appId: appId,
                apiKey: apiKey,
                environment: environment,
                apiBaseURL: apiBaseURL,
                bundleId: bundleId,
                country: country
            )
        )
    }

    public func configure(_ configuration: KeywordOSConfiguration) {
        self.configuration = configuration
    }

    @discardableResult
    public func start() async throws -> KeywordOSAttributionResult {
        guard let configuration else {
            throw KeywordOSError.notConfigured
        }

        let adServicesToken = try await fetchAdServicesToken()
        return try await sendAttribution(configuration: configuration, adServicesToken: adServicesToken)
    }

    private func getOrCreateAnonymousUserId() -> String {
        if let cachedAnonymousUserId {
            return cachedAnonymousUserId
        }

        if let existing = storage.string(forKey: Self.anonymousUserIdKey) {
            cachedAnonymousUserId = existing
            return existing
        }

        let created = UUID().uuidString
        storage.set(created, forKey: Self.anonymousUserIdKey)
        cachedAnonymousUserId = created
        return created
    }

    private func getOrCreateAppAccountToken() -> UUID {
        if let cachedAppAccountToken {
            return cachedAppAccountToken
        }

        if
            let existing = storage.string(forKey: Self.appAccountTokenKey),
            let uuid = UUID(uuidString: existing)
        {
            cachedAppAccountToken = uuid
            return uuid
        }

        let created = UUID()
        storage.set(created.uuidString, forKey: Self.appAccountTokenKey)
        cachedAppAccountToken = created
        return created
    }

    private func sendAttribution(
        configuration: KeywordOSConfiguration,
        adServicesToken: String
    ) async throws -> KeywordOSAttributionResult {
        var request = URLRequest(url: configuration.apiBaseURL.appendingPathComponent("sdk/attribution"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-KeywordOS-SDK-Key")
        request.httpBody = try jsonEncoder.encode(
            AttributionRequest(
                appId: configuration.appId,
                anonymousUserId: anonymousUserId,
                appAccountToken: appAccountToken,
                adServicesToken: adServicesToken,
                bundleId: configuration.bundleId,
                country: configuration.country,
                environment: configuration.environment
            )
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KeywordOSError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw KeywordOSError.serverError(statusCode: httpResponse.statusCode)
        }

        return try jsonDecoder.decode(KeywordOSAttributionResult.self, from: data)
    }

    private func fetchAdServicesToken() async throws -> String {
        #if canImport(AdServices) && os(iOS)
        if #available(iOS 14.3, *) {
            return try await AdServicesTokenProvider.fetchToken()
        }
        #endif

        return "adservices-unavailable"
    }
}

public enum KeywordOSLocale {
    public static var currentRegionIdentifier: String? {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            return Locale.current.region?.identifier
        }

        return Locale.current.regionCode
        #else
        return Locale.current.region?.identifier
        #endif
    }
}

private struct AttributionRequest: Encodable {
    let appId: String
    let anonymousUserId: String
    let appAccountToken: UUID
    let adServicesToken: String
    let bundleId: String?
    let country: String?
    let environment: KeywordOSEnvironment
}
