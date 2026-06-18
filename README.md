# KeywordOS iOS SDK

Swift Package for sending Apple Search Ads attribution identity to the KeywordOS backend.

The package is intentionally small:

- persists an anonymous user ID
- persists an `appAccountToken`
- fetches an AdServices attribution token on iOS when available
- posts attribution data to `POST /sdk/attribution`
- exposes `appAccountToken` for direct StoreKit 2 purchases and provider identity mapping

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
.package(url: "https://github.com/KeywordOS/KeywordOS-iOS.git", from: "0.3.2")
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
        KeywordOS.configure(
            appId: "app_demo_keywordos",
            apiKey: "kos_pub_demo",
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

`KeywordOS.shared.appAccountToken` is generated and persisted by the SDK the first time it is read. `start()` sends the same token to KeywordOS with the attribution data. If your app already has a stable UUID user ID and you want Apple Server Notifications V2 to use that same identity, call `KeywordOS.shared.setAppAccountToken(existingUserId)` before `start()` and before starting the purchase SDK.

Revenue event source identity:

- RevenueCat webhook: keep your existing RevenueCat App User ID and send `keywordos_app_account_token` as a subscriber attribute.
- Adapty webhook: keep your existing Adapty customer user ID and send `keywordos_app_account_token` as a custom user attribute. Enable Send User Attributes in the Adapty webhook settings.
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

Swift Package Manager consumes Git tags. Use semantic version tags such as `0.3.2`.
