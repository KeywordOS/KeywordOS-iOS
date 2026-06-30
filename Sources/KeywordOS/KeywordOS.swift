import Foundation
#if canImport(UIKit) && os(iOS)
import UIKit
#endif

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
    public let userID: String?
    public let environment: KeywordOSEnvironment
    public let apiBaseURL: URL
    public let bundleId: String?
    public let country: String?

    public init(
        appId: String,
        apiKey: String,
        userID: String? = nil,
        environment: KeywordOSEnvironment,
        apiBaseURL: URL = URL(string: "https://api.keywordos.io")!,
        bundleId: String? = Bundle.main.bundleIdentifier,
        country: String? = KeywordOSLocale.currentRegionIdentifier
    ) {
        self.appId = appId
        self.apiKey = apiKey
        self.userID = userID
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
    public let appUserIDToken: String?
    public let customProductPageId: String?
    public let attributed: Bool
}

public final class KeywordOS: @unchecked Sendable {
    public static let shared = KeywordOS()

    private static let anonymousUserIdKey = "com.keywordos.sdk.anonymousUserId"
    private static let appAccountTokenKey = "com.keywordos.sdk.appAccountToken"
    private static let appUserIDTokenKey = "com.keywordos.sdk.appUserIDToken"
    private static let customProductPageIdKey = "com.keywordos.sdk.customProductPageId"
    private static let customProductPageNameKey = "com.keywordos.sdk.customProductPageName"
    private static let customProductPageURLKey = "com.keywordos.sdk.customProductPageURL"

    private let storage: UserDefaults
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private var configuration: KeywordOSConfiguration?
    private var cachedAnonymousUserId: String?
    private var cachedAppAccountToken: UUID?
    private var cachedAppUserIDToken: String?
    private var cachedCustomProductPageId: String?
    private var cachedCustomProductPageName: String?
    private var cachedCustomProductPageURL: String?

    public var anonymousUserId: String {
        getOrCreateAnonymousUserId()
    }

    public var appAccountToken: UUID {
        getOrCreateAppAccountToken()
    }

    public var appUserIDToken: String? {
        getAppUserIDToken()
    }

    public var customProductPageId: String? {
        getCustomProductPageId()
    }

    public var customProductPageName: String? {
        getCustomProductPageName()
    }

    public var customProductPageURL: String? {
        getCustomProductPageURL()
    }

    public func setAppAccountToken(_ token: UUID) {
        storage.set(token.uuidString, forKey: Self.appAccountTokenKey)
        cachedAppAccountToken = token
    }

    public func setAppUserIDToken(_ token: String) {
        storage.set(token, forKey: Self.appUserIDTokenKey)
        cachedAppUserIDToken = token
    }

    public func setCustomProductPage(id: String, name: String? = nil, url: URL? = nil) {
        storage.set(id, forKey: Self.customProductPageIdKey)
        cachedCustomProductPageId = id

        if let name {
            storage.set(name, forKey: Self.customProductPageNameKey)
            cachedCustomProductPageName = name
        }

        if let url {
            storage.set(url.absoluteString, forKey: Self.customProductPageURLKey)
            cachedCustomProductPageURL = url.absoluteString
        }
    }

    @discardableResult
    public func handleDeepLink(_ url: URL) -> Bool {
        guard let id = Self.customProductPageId(from: url) else {
            return false
        }

        setCustomProductPage(id: id, name: Self.customProductPageName(from: url), url: url)
        return true
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
        userID: String? = nil,
        environment: KeywordOSEnvironment,
        apiBaseURL: URL = URL(string: "https://api.keywordos.io")!,
        bundleId: String? = Bundle.main.bundleIdentifier,
        country: String? = KeywordOSLocale.currentRegionIdentifier
    ) {
        shared.configure(
            KeywordOSConfiguration(
                appId: appId,
                apiKey: apiKey,
                userID: userID,
                environment: environment,
                apiBaseURL: apiBaseURL,
                bundleId: bundleId,
                country: country
            )
        )
    }

    public func configure(_ configuration: KeywordOSConfiguration) {
        self.configuration = configuration
        if let userID = configuration.userID {
            setAppUserIDToken(userID)
        }
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

    private func getAppUserIDToken() -> String? {
        if let cachedAppUserIDToken {
            return cachedAppUserIDToken
        }

        let existing = storage.string(forKey: Self.appUserIDTokenKey)
        cachedAppUserIDToken = existing
        return existing
    }

    private func getCustomProductPageId() -> String? {
        if let cachedCustomProductPageId {
            return cachedCustomProductPageId
        }

        let existing = storage.string(forKey: Self.customProductPageIdKey)
        cachedCustomProductPageId = existing
        return existing
    }

    private func getCustomProductPageName() -> String? {
        if let cachedCustomProductPageName {
            return cachedCustomProductPageName
        }

        let existing = storage.string(forKey: Self.customProductPageNameKey)
        cachedCustomProductPageName = existing
        return existing
    }

    private func getCustomProductPageURL() -> String? {
        if let cachedCustomProductPageURL {
            return cachedCustomProductPageURL
        }

        let existing = storage.string(forKey: Self.customProductPageURLKey)
        cachedCustomProductPageURL = existing
        return existing
    }

    private func sendAttribution(
        configuration: KeywordOSConfiguration,
        adServicesToken: String
    ) async throws -> KeywordOSAttributionResult {
        let vendorId = await KeywordOSDevice.currentVendorIdentifier
        var request = URLRequest(url: configuration.apiBaseURL.appendingPathComponent("sdk/attribution"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-KeywordOS-SDK-Key")
        request.httpBody = try jsonEncoder.encode(
            AttributionRequest(
                appId: configuration.appId,
                anonymousUserId: anonymousUserId,
                appAccountToken: appAccountToken,
                appUserIDToken: appUserIDToken,
                vendorId: vendorId,
                customProductPageId: customProductPageId,
                customProductPageName: customProductPageName,
                customProductPageURL: customProductPageURL,
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

    private static func customProductPageId(from url: URL) -> String? {
        if
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryValue = components.queryItems?.first(where: { item in
                ["keywordos_cpp", "cpp", "custom_product_page_id", "product_page_id"].contains(item.name)
            })?.value,
            !queryValue.isEmpty
        {
            return queryValue
        }

        let pathComponents = url.pathComponents.filter { component in
            component != "/"
        }

        if let cppIndex = pathComponents.firstIndex(where: { $0.lowercased() == "cpp" }),
           pathComponents.indices.contains(cppIndex + 1) {
            return pathComponents[cppIndex + 1]
        }

        if url.host?.lowercased() == "cpp",
           let firstPathComponent = pathComponents.first,
           !firstPathComponent.isEmpty {
            return firstPathComponent
        }

        return nil
    }

    private static func customProductPageName(from url: URL) -> String? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryValue = components.queryItems?.first(where: { item in
                ["keywordos_cpp_name", "cpp_name", "custom_product_page_name", "product_page_name"].contains(item.name)
            })?.value,
            !queryValue.isEmpty
        else {
            return nil
        }

        return queryValue
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

enum KeywordOSDevice {
    @MainActor
    static var currentVendorIdentifier: String? {
        #if canImport(UIKit) && os(iOS)
        UIDevice.current.identifierForVendor?.uuidString
        #else
        nil
        #endif
    }
}

private struct AttributionRequest: Encodable {
    let appId: String
    let anonymousUserId: String
    let appAccountToken: UUID
    let appUserIDToken: String?
    let vendorId: String?
    let customProductPageId: String?
    let customProductPageName: String?
    let customProductPageURL: String?
    let adServicesToken: String
    let bundleId: String?
    let country: String?
    let environment: KeywordOSEnvironment
}
