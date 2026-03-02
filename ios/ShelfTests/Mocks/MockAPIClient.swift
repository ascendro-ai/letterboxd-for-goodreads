import Foundation
@testable import Shelf

/// Protocol-based mock that replaces APIClient for testing.
/// Each service method maps to a closure that tests can override.
final class MockAPIClient {
    var responses: [String: Any] = [:]
    var requestLog: [(method: String, path: String, body: Any?)] = []

    func register<T: Codable>(path: String, response: T) {
        responses[path] = response
    }

    func registerError(path: String, error: Error) {
        responses[path] = error
    }

    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        requestLog.append((method: method.rawValue, path: path, body: body))

        guard let response = responses[path] else {
            throw APIError.notFound
        }

        if let error = response as? Error {
            throw error
        }

        guard let typed = response as? T else {
            throw APIError.decodingError(
                NSError(domain: "MockAPIClient", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Type mismatch"])
            )
        }

        return typed
    }
}
