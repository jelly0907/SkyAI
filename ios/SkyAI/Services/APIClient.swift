import Foundation

enum SkyAIError: LocalizedError {
    case networkError(URLError)
    case decodingError(DecodingError)
    case serverError(String)
    case invalidURL
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidURL:
            return "Invalid URL"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    private init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Private Helpers

    private func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
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
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SkyAIError.unknown
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if let errorMessage = try? JSONDecoder().decode(
                    [String: String].self,
                    from: data
                )["detail"] {
                    throw SkyAIError.serverError(errorMessage)
                }
                throw SkyAIError.serverError("HTTP \(httpResponse.statusCode)")
            }

            let decoder = makeJSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as URLError {
            throw SkyAIError.networkError(error)
        } catch let error as DecodingError {
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
