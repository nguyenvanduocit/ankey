import Foundation

/// Where statistics and feedback go. A client token is public by design: Datadog's browser and mobile
/// SDKs ship it inside the app, and it can only write logs. An API key never goes in this file.
enum DatadogConfig {
    /// Datadog → Organization Settings → Client Tokens. Empty keeps every upload off.
    static let clientToken = "pub1e25ec4805ecef3ead0d89315d68c0f7"
    /// The intake host of the Datadog site: `browser-intake-datadoghq.com` (US1),
    /// `browser-intake-datadoghq.eu` (EU1), `browser-intake-us3-datadoghq.com` (US3), and so on.
    static let intakeHost = "browser-intake-datadoghq.com"

    static var isConfigured: Bool { !clientToken.isEmpty }
}
