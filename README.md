# KeywordOS iOS SDK

Swift Package for sending Apple Search Ads attribution identity to the KeywordOS backend.

The package is intentionally small:

- persists an anonymous user ID
- persists an `appAccountToken`
- fetches an AdServices attribution token on iOS when available
- posts attribution data to `POST /sdk/attribution`
- exposes `appAccountToken` for StoreKit 2 purchases

## Usage

Add the package in Xcode:

```text
https://github.com/KeywordOS/KeywordOS-iOS.git
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/KeywordOS/KeywordOS-iOS.git", from: "0.1.0")
```

```swift
import KeywordOSSDK

KeywordOS.configure(
    appId: "app_demo_keywordos",
    apiKey: "kos_pub_demo",
    environment: .sandbox
)

Task {
    try await KeywordOS.shared.start()
}

let token = KeywordOS.shared.appAccountToken
```

StoreKit 2 purchase example:

```swift
let result = try await product.purchase(options: [
    .appAccountToken(KeywordOS.shared.appAccountToken)
])
```

## Local Development

From this directory:

```bash
swift test
```

## Releases

Swift Package Manager consumes Git tags. Use semantic version tags such as `0.1.0`.
