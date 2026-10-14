import Foundation

/// One value on a log event. Only text and whole numbers, so every field is easy to read in the shown data.
enum LogAttribute: Equatable {
    case string(String)
    case int(Int)

    fileprivate var json: Any {
        switch self {
        case .string(let text): return text
        case .int(let number): return number
        }
    }
}

/// One line for Datadog Logs. Whoever builds the event decides what it carries; `LogIntake` adds
/// `ddsource`, `service` and `status`, and those three always win over a same-named attribute.
struct LogEvent: Equatable {
    var message: String
    var attributes: [String: LogAttribute] = [:]
}

/// Sends events to Datadog. The one sender serves every feature (statistics, feedback), so a caller
/// builds events and never touches the network.
protocol LogSender: Sendable {
    func send(_ events: [LogEvent]) async throws
}

/// The Datadog logs intake, as pure functions: events in, the exact request out.
enum LogIntake {
    static let service = "ankey"

    /// The JSON array that goes in the request body. Keys are sorted, so the same events give the same bytes.
    static func body(_ events: [LogEvent], pretty: Bool = false) -> Data {
        let objects = events.map { event -> [String: Any] in
            var object = event.attributes.mapValues(\.json)
            object["message"] = event.message
            object["ddsource"] = service
            object["service"] = service
            object["status"] = "info"
            return object
        }
        let options: JSONSerialization.WritingOptions = pretty
            ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        return (try? JSONSerialization.data(withJSONObject: objects, options: options)) ?? Data("[]".utf8)
    }

    /// The POST to `https://<host>/api/v2/logs`. The client token goes in `DD-API-KEY`, the header
    /// Datadog's own mobile SDK uses for it. Datadog also sees the sender's IP address and this user agent.
    static func request(
        _ events: [LogEvent],
        host: String,
        clientToken: String,
        userAgent: String,
        requestID: UUID = UUID(),
        timeout: TimeInterval = 10
    ) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/api/v2/logs"
        components.queryItems = [URLQueryItem(name: "ddsource", value: service)]
        var request = URLRequest(url: components.url!, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(clientToken, forHTTPHeaderField: "DD-API-KEY")
        request.setValue(service, forHTTPHeaderField: "DD-EVP-ORIGIN")
        request.setValue(requestID.uuidString, forHTTPHeaderField: "DD-REQUEST-ID")
        request.httpBody = body(events)
        return request
    }
}
