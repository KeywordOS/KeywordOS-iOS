#if canImport(AdServices) && os(iOS)
import AdServices

@available(iOS 14.3, *)
enum AdServicesTokenProvider {
    static func fetchToken() async throws -> String {
        try AAAttribution.attributionToken()
    }
}
#endif
