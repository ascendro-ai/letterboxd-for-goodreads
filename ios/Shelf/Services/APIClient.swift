/// HTTP client wrapping URLSession for all backend API calls.
///
/// Automatically attaches the Supabase JWT from AuthService, handles token
/// refresh on 401 responses, and provides typed JSON decoding. All methods
/// throw ``APIError`` on failure. Supports opportunistic caching for offline use.

import Foundation
import os.log

private let logger = Logger(subsystem: "com.shelf.app", category: "API")

// MARK: - API Configuration

enum APIEnvironment {
    case development
    case production

    var baseURL: String {
        switch self {
        case .development: "http://127.0.0.1:8000/api/v1"
        case .production: "https://shelf-api.up.railway.app/api/v1"
        }
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case validationError(String)
    case rateLimited
    case serverError
    case networkError(Error)
    case decodingError(Error)
    case apiError(code: String, message: String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .unauthorized: "Please sign in again."
        case .forbidden: "You don't have permission to do that."
        case .notFound: "Not found."
        case .conflict(let msg): msg
        case .validationError(let msg): msg
        case .rateLimited: "Too many requests. Please wait a moment."
        case .serverError: "Something went wrong. Please try again."
        case .networkError: "No internet connection."
        case .decodingError: "Unexpected response from server."
        case .apiError(_, let message): message
        case .offline: "You're offline. Changes will sync when you reconnect."
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Client

@Observable
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var environment: APIEnvironment

    /// In-memory response cache for offline fallback on GET requests.
    private var responseCache: [String: Data] = [:]

    var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Try ISO8601 with fractional seconds and timezone
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            // Try without fractional seconds
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }
            // Backend returns naive datetimes (no timezone) — assume UTC
            let naive = DateFormatter()
            naive.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            naive.timeZone = TimeZone(identifier: "UTC")
            if let date = naive.date(from: string) { return date }
            naive.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = naive.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        #if DEBUG
        self.environment = .development
        #else
        self.environment = .production
        #endif
    }

    func setEnvironment(_ env: APIEnvironment) {
        self.environment = env
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: (some Encodable)? = nil as Empty?,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let cacheKey = "\(method.rawValue):\(url.absoluteString)"
        logger.debug("\(method.rawValue) \(path)")

        do {
            let (data, response) = try await perform(request)
            try validateResponse(response, data: data)

            // Cache successful GET responses for offline fallback
            if method == .get {
                responseCache[cacheKey] = data
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            logger.error("Decode error on \(method.rawValue) \(path): \(String(describing: error))")
            throw error
        } catch let error as APIError {
            logger.error("API error on \(method.rawValue) \(path): \(error.localizedDescription)")
            // On network error for GET requests, try cache fallback
            if case .networkError = error, method == .get,
               let cachedData = responseCache[cacheKey] {
                return try decoder.decode(T.self, from: cachedData)
            }
            throw error
        }
    }

    // MARK: - Request without response body

    func request(
        _ method: HTTPMethod,
        path: String,
        body: (some Encodable)? = nil as Empty?,
        queryItems: [URLQueryItem]? = nil
    ) async throws {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await perform(request)
        try validateResponse(response, data: data)
    }

    // MARK: - Multipart Upload (for CSV import)

    func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String = "text/csv"
    ) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await perform(request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private Helpers

    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var components = URLComponents(string: environment.baseURL + path) else {
            throw APIError.invalidURL
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409:
            let detail = parseErrorMessage(data)
            throw APIError.conflict(detail)
        case 422:
            let detail = parseErrorMessage(data)
            throw APIError.validationError(detail)
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError
        default:
            let detail = parseErrorMessage(data)
            throw APIError.apiError(code: "HTTP_\(httpResponse.statusCode)", message: detail)
        }
    }

    private func parseErrorMessage(_ data: Data) -> String {
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return errorResponse.error.message
        }
        return "An unexpected error occurred."
    }
}

// MARK: - Empty body placeholder

struct Empty: Encodable {}
