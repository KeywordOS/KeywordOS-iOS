# KeywordOS iOS SDK

Swift Package for sending Apple Search Ads attribution identity to the KeywordOS backend.

The package is intentionally small:

- persists an anonymous user ID
- persists an `appAccountToken`
- optionally persists your app's own user ID string from `KeywordOS.configure(... userID: ...)`
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
.package(url: "https://github.com/KeywordOS/KeywordOS-iOS.git", from: "0.3.7")
```

SwiftUI app setup:

```swift
import KeywordOS
import SwiftUI

@main
struct MyApp: App {
    init() {
        let userID = "<your_app_user_id>" // Use the same stable user id your app sends to RevenueCat or Adapty.

        KeywordOS.configure(
            appId: "app_demo_keywordos",
            apiKey: "kos_pub_demo",
            userID: userID,
            environment: .sandbox // Change to .production before App Store release.
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
        let userID = "<your_app_user_id>" // Use the same stable user id your app sends to RevenueCat or Adapty.

        KeywordOS.configure(
            appId: "app_demo_keywordos",
            apiKey: "kos_pub_demo",
            userID: userID,
            environment: .sandbox // Change to .production before App Store release.
        )

        Task {
            do {
                try await KeywordOS.shared.start()
            } catch {
                print("KeywordOS start failed: \(error)")
            }
        }

        return true
    }
}
```

For RevenueCat or Adapty webhooks, pass the same stable string that your app already uses as the RevenueCat App User ID or Adapty customer user ID to `KeywordOS.configure(... userID: userId, ...)`. This can be a UUID string, database ID, Firebase UID, or any other stable non-empty user ID. If the app only knows the user ID after launch or login, `KeywordOS.shared.setAppUserIDToken(userId)` remains available and should be called as soon as the ID is known.

`KeywordOS.shared.appAccountToken` is different: it is a UUID generated and persisted by the SDK for Apple's StoreKit `appAccountToken`. Use it only when you send purchases through direct StoreKit or Apple Server Notifications V2.

Custom Product Page link matching:

- In Xcode, open the app target, select Info, expand URL Types, press +, set Identifier to `com.yourcompany.keywordos`, and set URL Schemes to a scheme such as `keywordos-yourapp`.
- Forward opened URLs to `KeywordOS.shared.handleDeepLink(url)` from SwiftUI `.onOpenURL` or UIKit `application(_:open:options:)`.
- Use links like `keywordos-yourapp://cpp/cartoon-photo?keywordos_cpp_name=Cartoon%20Photo`.
- KeywordOS stores the product page ID and optional display name on the app user. This is user-level link context; App Store Connect still owns aggregate Custom Product Page reporting.

SwiftUI deep link handler:

```swift
WindowGroup {
    ContentView()
        .onOpenURL { url in
            KeywordOS.shared.handleDeepLink(url)
        }
}
```

UIKit deep link handler:

```swift
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    KeywordOS.shared.handleDeepLink(url)
    return true
}
```

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

Swift Package Manager consumes Git tags. Use semantic version tags such as `0.3.7`.
