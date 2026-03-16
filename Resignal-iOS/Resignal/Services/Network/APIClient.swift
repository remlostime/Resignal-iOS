//
//  APIClient.swift
//  Resignal
//
//  Centralized HTTP client that attaches JWT Bearer tokens to all requests
//  and handles 401 token refresh with a single retry.
//

import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - Protocol

protocol APIClientProtocol: Sendable {
    /// Perform an authenticated request and decode the response.
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> T

    /// Perform an authenticated request and return raw data + response.
    func requestRaw(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> (Data, HTTPURLResponse)
}

extension APIClientProtocol {
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        timeoutInterval: TimeInterval = 30
    ) async throws -> T {
        try await request(
            endpoint, method: method, body: body,
            queryItems: queryItems, timeoutInterval: timeoutInterval
        )
    }

    func requestRaw(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        timeoutInterval: TimeInterval = 30
    ) async throws -> (Data, HTTPURLResponse) {
        try await requestRaw(
            endpoint, method: method, body: body,
            queryItems: queryItems, timeoutInterval: timeoutInterval
        )
    }
}

// MARK: - Implementation

actor APIClientImpl: APIClientProtocol {

    // MARK: - Dependencies

    private let baseURL: String
    private let identityManager: IdentityManagerProtocol
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(
        baseURL: String,
        identityManager: IdentityManagerProtocol,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.identityManager = identityManager
        self.urlSession = urlSession

        self.encoder = JSONEncoder()

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - APIClientProtocol

    nonisolated func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> T {
        let (data, _) = try await performWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            timeoutInterval: timeoutInterval
        )

        do {
            return try await self.decodeResponse(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    nonisolated func requestRaw(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> (Data, HTTPURLResponse) {
        try await performWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            timeoutInterval: timeoutInterval
        )
    }

    // MARK: - Private

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    private nonisolated func performWithRetry(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await performRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                queryItems: queryItems,
                timeoutInterval: timeoutInterval
            )
        } catch let error as APIError where error.isUnauthorized {
            identityManager.clearToken()
            try await identityManager.register(baseURL: await self.getBaseURL())

            return try await performRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                queryItems: queryItems,
                timeoutInterval: timeoutInterval
            )
        }
    }

    private func getBaseURL() -> String {
        baseURL
    }

    private nonisolated func performRequest(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try await buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            timeoutInterval: timeoutInterval
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return (data, httpResponse)
        default:
            throw parseError(data: data, statusCode: httpResponse.statusCode)
        }
    }

    private nonisolated func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> URLRequest {
        let base = await self.getBaseURL()

        var components = URLComponents(string: "\(base)\(endpoint)")
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.networkError("Invalid URL: \(base)\(endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval

        if let token = identityManager.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue(identityManager.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(identityManager.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(identityManager.deviceModel, forHTTPHeaderField: "x-device-model")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        return request
    }

    private nonisolated func parseError(data: Data, statusCode: Int) -> APIError {
        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return APIError.from(code: errorResponse.error.code, message: errorResponse.error.message)
        }

        switch statusCode {
        case 401: return .unauthorized
        case 403: return .proRequired
        case 404: return .notFound
        case 429: return .rateLimited
        case 500...599: return .internalError("HTTP \(statusCode)")
        default: return .networkError("HTTP \(statusCode)")
        }
    }
}

// MARK: - Mock

actor MockAPIClient: APIClientProtocol {
    var mockData: Data = Data()
    var mockStatusCode: Int = 200
    var shouldFail = false

    nonisolated func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> T {
        if await shouldFail { throw APIError.networkError("Mock failure") }
        let data = await mockData
        return try JSONDecoder().decode(T.self, from: data)
    }

    nonisolated func requestRaw(
        _ endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        timeoutInterval: TimeInterval
    ) async throws -> (Data, HTTPURLResponse) {
        if await shouldFail { throw APIError.networkError("Mock failure") }
        let data = await mockData
        let response = HTTPURLResponse(
            url: URL(string: "https://mock.api")!,
            statusCode: await mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

// MARK: - Helpers

private extension APIError {
    var isUnauthorized: Bool {
        switch self {
        case .unauthorized, .userNotFound: return true
        default: return false
        }
    }
}

/// Type-erasing wrapper for encoding arbitrary Encodable values.
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        self.encodeFunc = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
