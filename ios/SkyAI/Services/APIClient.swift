import Foundation

enum SkyAIError: LocalizedError {
    case networkError(URLError)
    case decodingError(DecodingError)
    case invalidInput(String)       // 422 — user-facing validation message
    case notFound(String)           // 404
    case serverError(String)        // 5xx
    case serverOther(Int, String)   // any other non-2xx we don't special-case
    case invalidURL
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            // Friendlier message for common URLError cases.
            switch error.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network and try again."
            case .timedOut:
                return "The request timed out. Please try again."
            case .cannotConnectToHost, .cannotFindHost:
                return "Can't reach the server right now. Please try again shortly."
            default:
                return "Network problem — \(error.localizedDescription)"
            }
        case .decodingError:
            return "We got an unexpected response from the server. Please try again."
        case .invalidInput(let message):
            return message
        case .notFound(let message):
            return message
        case .serverError(let message):
            return message
        case .serverOther(_, let message):
            return message
        case .invalidURL:
            return "Something's wrong with the request. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Backend error-response parsing
//
// FastAPI returns validation errors as:
//   { "detail": [ { "type": "...", "loc": [...], "msg": "...", "input": ... } ] }
// Other HTTPExceptions use:
//   { "detail": "some string" }
// We need to handle both.

private struct FastAPIErrorDetail: Decodable {
    let type: String?
    let loc: [AnyCodable]?
    let msg: String?
}

private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self.value = v; return }
        if let v = try? c.decode(Int.self)    { self.value = v; return }
        if let v = try? c.decode(Double.self) { self.value = v; return }
        self.value = ""
    }
    var asString: String { "\(value)" }
}

private enum BackendError {
    /// Tries to decode a FastAPI error body. Returns the most useful
    /// human-readable summary, or nil if the body doesn't match either
    /// of the known shapes.
    static func friendlyMessage(from data: Data) -> String? {
        // Shape 1: { "detail": "some string" }
        if let wrapper = try? JSONDecoder().decode([String: String].self, from: data),
           let msg = wrapper["detail"], !msg.isEmpty {
            return msg
        }
        // Shape 2: { "detail": [ FastAPIErrorDetail, ... ] }
        if let wrapper = try? JSONDecoder().decode([String: [FastAPIErrorDetail]].self, from: data),
           let details = wrapper["detail"], !details.isEmpty {
            return summarize(details)
        }
        return nil
    }

    /// Turn a list of Pydantic errors into one short user-facing line.
    private static func summarize(_ details: [FastAPIErrorDetail]) -> String {
        // Most typos hit the origin/destination field as an unknown IATA
        // code or the enum-constrained cabin_class. Map those to specific
        // messages; otherwise fall back to the first msg.
        let fieldNames = details.compactMap { detail -> String? in
            guard let loc = detail.loc, loc.count >= 2 else { return nil }
            return loc.dropFirst().map(\.asString).joined(separator: ".")
        }
        if fieldNames.contains(where: { $0.contains("origin") }) {
            return "We don't recognize that origin airport. Try a 3-letter code like SFO or JFK."
        }
        if fieldNames.contains(where: { $0.contains("destination") }) {
            return "We don't recognize that destination airport. Try a 3-letter code like NRT or LHR."
        }
        if fieldNames.contains(where: { $0.contains("departure_date") }) {
            return "Please pick a valid departure date (today or later)."
        }
        if fieldNames.contains(where: { $0.contains("return_date") }) {
            return "Please pick a valid return date after your departure."
        }
        if fieldNames.contains(where: { $0.contains("cabin_class") }) {
            return "That cabin class isn't supported. Choose Economy, Premium Economy, Business, or First."
        }
        if fieldNames.contains(where: { $0.contains("adults") || $0.contains("children") || $0.contains("infants") }) {
            return "Please check the passenger counts and try again."
        }
        // Generic fallback — use the first error's message, prepended
        // with a gentle framing so it doesn't read like raw Pydantic.
        if let first = details.first?.msg {
            return "We couldn't understand part of your search: \(first)"
        }
        return "We couldn't understand your search. Please check your input and try again."
    }
}

// MARK: - Dev backend host
//
// On a physical iPhone, "localhost" resolves to the phone itself, so we
// have to reach the Mac by name or IP. We resolve via Bonjour/mDNS
// (<hostname>.local) so the URL keeps working when DHCP reshuffles the
// Mac's IP — no more editing this file every time the network blips.
//
// To find your Mac's mDNS name, run this in Terminal on the Mac:
//
//     scutil --get LocalHostName
//
// Then set MAC_HOSTNAME below to that exact value (without ".local" — we
// append it). For example, if `scutil` prints "Jerrys-MacBook-Pro", set
// `MAC_HOSTNAME = "Jerrys-MacBook-Pro"`.
//
// Caveats:
//   • mDNS only works on the LAN. Cellular / hotspot won't resolve .local.
//   • The Simulator already shares the Mac's networking, so we just hit
//     127.0.0.1 there — no Bonjour roundtrip needed.
//   • If .local resolution ever fails on-device, fall back to your Mac's
//     IP literal (`ipconfig getifaddr en0`) by editing `deviceBaseURL`.
//
// Info.plist requirements (already in place since plain-HTTP IP requests
// are working today): App Transport Security must allow HTTP to the local
// network — typically `NSAppTransportSecurity → NSAllowsLocalNetworking`
// or `NSAllowsArbitraryLoads`. The local-network privacy prompt is also
// already granted because the previous IP-based config triggered it.

private let MAC_HOSTNAME = "Jerrys-MacBook-Pro"   // ← TODO: paste output of `scutil --get LocalHostName`
private let DEV_BACKEND_PORT = 8000

private func defaultDevBaseURL() -> URL {
    #if targetEnvironment(simulator)
    return URL(string: "http://127.0.0.1:\(DEV_BACKEND_PORT)")!
    #else
    return URL(string: "http://\(MAC_HOSTNAME).local:\(DEV_BACKEND_PORT)")!
    #endif
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    private init(baseURL: URL = defaultDevBaseURL()) {
        self.baseURL = baseURL
        // Use .ephemeral so nothing is cached on disk, and force the server
        // to close the TCP connection after each response. Reason: with
        // `uvicorn --reload`, every code edit restarts the server and severs
        // any iOS-held keep-alive socket without iOS noticing. The next
        // request reuses the dead socket and times out at ~30s. Disabling
        // keep-alive (Connection: close) makes every search a fresh TCP
        // handshake — slightly more bytes on the wire, vastly more reliable
        // during dev. Drop this header in production once the backend is
        // stable behind a real reverse proxy.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpShouldUsePipelining = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpAdditionalHeaders = ["Connection": "close"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Private Helpers

    private func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // NOTE: We do NOT set keyDecodingStrategy = .convertFromSnakeCase.
        // Every response struct in Flight.swift declares explicit CodingKeys
        // with snake_case raw values (e.g. `departureAt = "departure_at"`).
        // Turning on .convertFromSnakeCase would rewrite incoming JSON keys
        // to camelCase *before* matching, which then fails to match the
        // snake_case raw values — producing keyNotFound.

        // Backend responses mix two date shapes:
        //   - full ISO8601 datetimes: "2026-06-01T22:30:00Z" (segment.*_at,
        //     search_response.returned_at, offer.last_ticketing_date)
        //   - ISO8601 LOCAL time, no tz: "2026-05-08T05:25:00"
        //     (Duffel segment.*_at — departure/arrival in airport local
        //     time, with no offset). ISO8601DateFormatter rejects these
        //     so we need a plain DateFormatter with "yyyy-MM-dd'T'HH:mm:ss".
        //     We treat naïve datetimes as UTC; the UI just renders "HH:mm"
        //     without tz conversion, which matches what travelers expect
        //     to see (the local airport clock).
        //   - date-only strings:     "2026-06-01"              (search_request
        //     echoed in responses: departure_date, return_date)
        // The chain tries each format in order, most specific first.
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.formatOptions = [.withInternetDateTime]

        let iso8601Frac = ISO8601DateFormatter()
        iso8601Frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let localDateTime = DateFormatter()
        localDateTime.calendar = Calendar(identifier: .iso8601)
        localDateTime.locale = Locale(identifier: "en_US_POSIX")
        localDateTime.timeZone = TimeZone(secondsFromGMT: 0)
        localDateTime.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let localDateTimeFrac = DateFormatter()
        localDateTimeFrac.calendar = Calendar(identifier: .iso8601)
        localDateTimeFrac.locale = Locale(identifier: "en_US_POSIX")
        localDateTimeFrac.timeZone = TimeZone(secondsFromGMT: 0)
        localDateTimeFrac.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .iso8601)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"

        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = iso8601Full.date(from: s)       { return date }
            if let date = iso8601Frac.date(from: s)       { return date }
            if let date = localDateTime.date(from: s)     { return date }
            if let date = localDateTimeFrac.date(from: s) { return date }
            if let date = dateOnly.date(from: s)          { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(s)"
            )
        }
        return decoder
    }

    private func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Backend Pydantic `date` fields want "YYYY-MM-DD", not full ISO8601
        // datetimes. All outbound Date values from the app (SearchRequest
        // departure/return, WatchCreateRequest dates) are date-only.
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.calendar = Calendar(identifier: .iso8601)
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        encoder.dateEncodingStrategy = .formatted(dateOnlyFormatter)
        return encoder
    }

    private func performRequest<T: Decodable>(
        method: String,
        endpoint: String,
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw SkyAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = body
        }

        do {
            // Single retry for transient TCP-level failures. Stale-socket
            // symptoms (.networkConnectionLost, .timedOut on a "warm"
            // connection) recover instantly on a fresh handshake; this
            // keeps that recovery invisible to the user instead of
            // bubbling up as a generic timeout.
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch let urlErr as URLError where
                urlErr.code == .networkConnectionLost ||
                urlErr.code == .timedOut ||
                urlErr.code == .cannotConnectToHost {
                print("⚠️ Network error \(urlErr.code.rawValue) on \(method) \(endpoint) — retrying once")
                (data, response) = try await session.data(for: request)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SkyAIError.unknown
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let status = httpResponse.statusCode
                let parsed = BackendError.friendlyMessage(from: data)

                switch status {
                case 400, 422:
                    // Validation error — almost always a typo / bad input.
                    let msg = parsed
                        ?? "We couldn't understand your search. Please check your input and try again."
                    throw SkyAIError.invalidInput(msg)
                case 404:
                    let msg = parsed ?? "We couldn't find what you were looking for."
                    throw SkyAIError.notFound(msg)
                case 500...599:
                    let msg = parsed ?? "The server hit a problem. Please try again in a moment."
                    throw SkyAIError.serverError(msg)
                default:
                    let msg = parsed ?? "Unexpected error (HTTP \(status)). Please try again."
                    throw SkyAIError.serverOther(status, msg)
                }
            }

            let decoder = makeJSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as URLError {
            throw SkyAIError.networkError(error)
        } catch let error as DecodingError {
            // Print the full DecodingError to Xcode's console. Swift's
            // default description names the exact codingPath + reason
            // (keyNotFound / typeMismatch / valueNotFound / dataCorrupted).
            print("⚠️ DecodingError on \(method) \(endpoint):\n\(error)")
            switch error {
            case .keyNotFound(let key, let ctx):
                print("  keyNotFound: \(key.stringValue) at path=\(ctx.codingPath.map(\.stringValue))")
            case .typeMismatch(let type, let ctx):
                print("  typeMismatch: expected \(type) at path=\(ctx.codingPath.map(\.stringValue)) — \(ctx.debugDescription)")
            case .valueNotFound(let type, let ctx):
                print("  valueNotFound: \(type) at path=\(ctx.codingPath.map(\.stringValue)) — \(ctx.debugDescription)")
            case .dataCorrupted(let ctx):
                print("  dataCorrupted at path=\(ctx.codingPath.map(\.stringValue)) — \(ctx.debugDescription)")
            @unknown default:
                break
            }
            throw SkyAIError.decodingError(error)
        } catch let error as SkyAIError {
            throw error
        } catch {
            throw SkyAIError.unknown
        }
    }

    // MARK: - Public Methods

    func parseIntent(query: String) async throws -> IntentResponse {
        let request = IntentRequest(query: query)
        let encoder = makeJSONEncoder()
        let body = try encoder.encode(request)

        return try await performRequest(
            method: "POST",
            endpoint: "/search/intent",
            body: body
        )
    }

    func searchFlights(_ searchRequest: SearchRequest) async throws -> SearchResponse {
        let encoder = makeJSONEncoder()
        let body = try encoder.encode(searchRequest)

        return try await performRequest(
            method: "POST",
            endpoint: "/search/flights",
            body: body
        )
    }
}
