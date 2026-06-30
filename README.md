# KeywordOS iOS SDK

Swift Package for sending Apple Search Ads attribution identity to the KeywordOS backend.

The package is intentionally small:

- persists an anonymous user ID
- persists an `appAccountToken`
- optionally persists your app's own user ID string with `setAppUserIDToken(_:)`
- fetches an AdServices attribution token on iOS when available
- optionally captures Custom Product Page link context with `handleDeepLink(_:)`
- posts attribution data to `POST /sdk/attribution`
- exposes `appAccountToken` for direct StoreKit 2 purchases and Apple Server Notifications V2 matching

When installed with Swift Package Manager, KeywordOS links Apple's `AdServices.framework`
for iOS automatically. You only need to add the `KeywordOS` package/product in Xcode;
do not add `AdServices.framework` manually unless you are using a custom non-SPM
integration.

## Usage

Add the package in Xcode:

```text
https://github.com/KeywordOS/KeywordOS-iOS.git
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/KeywordOS/KeywordOS-iOS.git", from: "0.3.6")
```

SwiftUI app setup:

```swift
import KeywordOS
import SwiftUI

@main
struct MyApp: App {
    init() {
        KeywordOS.configure(
            appId: "app_demo_keywordos",
            apiKey: "kos_pub_demo",
            environment: .sandbox // Change to .production before App Store release.
        )

        KeywordOS.shared.setAppUserIDToken("<your_app_user_id>")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    KeywordOS.shared.handleDeepLink(url)
                }
                .task {
                    await startKeywordOS()
                }
        }
    }

    private func startKeywordOS() async {
        do {
            try await KeywordOS.shared.start()
        } catch {
            print("KeywordOS start failed: \(error)")
        }
    }
}
```

UIKit AppDelegate setup:

```swift
import KeywordOS
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        KeywordOS.configure(
            appId: "app_demo_keywordos",
            apiKey: "kos_pub_demo",
            environment: .sandbox // Change to .production before App Store release.
        )

        KeywordOS.shared.setAppUserIDToken("<your_app_user_id>")

        Task {
            do {
                try await KeywordOS.shared.start()
            } catch {
                print("KeywordOS start failed: \(error)")
            }
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        KeywordOS.shared.handleDeepLink(url)
        return true
    }
}
```

For RevenueCat or Adapty webhooks, call `KeywordOS.shared.setAppUserIDToken(userId)` before `start()`. Use the same stable string that your app already uses as the RevenueCat App User ID or Adapty customer user ID. This can be a UUID string, database ID, Firebase UID, or any other stable non-empty user ID.

`KeywordOS.shared.appAccountToken` is different: it is a UUID generated and persisted by the SDK for Apple's StoreKit `appAccountToken`. Use it only when you send purchases through direct StoreKit or Apple Server Notifications V2.

Custom Product Page link matching:

- Add a custom URL scheme or universal link to the app.
- Forward opened URLs to `KeywordOS.shared.handleDeepLink(url)` from SwiftUI `.onOpenURL` or UIKit `application(_:open:options:)`.
- Use links like `keywordos-yourapp://cpp/cartoon-photo?keywordos_cpp_name=Cartoon%20Photo`.
- KeywordOS stores the product page ID and optional display name on the app user. This is user-level link context; App Store Connect still owns aggregate Custom Product Page reporting.

Revenue event source identity:

- RevenueCat webhook: keep your existing RevenueCat App User ID and send `keywordos_app_user_id_token` as a subscriber attribute with the same string.
- Adapty webhook: keep your existing Adapty customer user ID and send `keywordos_app_user_id_token` as a custom user attribute with the same string. Enable Send User Attributes in the Adapty webhook settings.
- Apple Server Notifications V2: use the same UUID for KeywordOS and the purchase SDK's Apple app account token. For direct StoreKit purchases, pass it in the StoreKit purchase call. For RevenueCat purchases, the RevenueCat App User ID must be a UUID so Apple can carry it as the transaction `appAccountToken`.

Direct StoreKit 2 purchase example. Use this only if your app handles purchases directly with StoreKit. Put it where your paywall already starts the StoreKit purchase, not in AppDelegate:

```swift
import KeywordOS
import StoreKit

func purchase(_ product: Product) async throws -> Product.PurchaseResult {
    let appAccountToken = KeywordOS.shared.appAccountToken

    try await product.purchase(options: [
        .appAccountToken(appAccountToken)
    ])
}
```

## Local Development

From this directory:

```bash
swift test
```

## Releases

Swift Package Manager consumes Git tags. Use semantic version tags such as `0.3.6`.
