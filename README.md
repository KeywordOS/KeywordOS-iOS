# KeywordOS iOS SDK

Swift Package for sending Apple Search Ads attribution identity to the KeywordOS backend.

The package is intentionally small:

- persists an anonymous user ID
- persists an `appAccountToken`
- fetches an AdServices attribution token on iOS when available
- posts attribution data to `POST /sdk/attribution`
- exposes `appAccountToken` for direct StoreKit 2 purchases and provider identity mapping

## Usage

Add the package in Xcode:

```text
https://github.com/KeywordOS/KeywordOS-iOS.git
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/KeywordOS/KeywordOS-iOS.git", from: "0.2.0")
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

`KeywordOS.shared.appAccountToken` is generated and persisted by the SDK the first time it is read. `start()` sends the same token to KeywordOS with the attribution data.

Revenue provider identity:

- RevenueCat: configure RevenueCat with `KeywordOS.shared.anonymousUserId` as the App User ID, and optionally send `keywordos_app_account_token` as a subscriber attribute.
- Adapty: identify the Adapty user with `KeywordOS.shared.appAccountToken`.
- Direct Apple Server Notifications V2: pass `KeywordOS.shared.appAccountToken` in the StoreKit purchase call.

Direct StoreKit 2 purchase example. Use this only if your app handles purchases directly with StoreKit. Put it where your paywall already starts the StoreKit purchase, not in AppDelegate:

```swift
import KeywordOS
import StoreKit

func purchase(_ product: Product) async throws -> Product.PurchaseResult {
    try await product.purchase(options: [
        .appAccountToken(KeywordOS.shared.appAccountToken)
    ])
}
```

## Local Development

From this directory:

```bash
swift test
```

## Releases

Swift Package Manager consumes Git tags. Use semantic version tags such as `0.2.0`.
