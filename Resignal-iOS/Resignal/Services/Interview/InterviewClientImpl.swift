//
//  InterviewClientImpl.swift
//  Resignal
//
//  Default implementation of InterviewClient that fetches interviews from the backend API.
//

import Foundation

/// Fetches paginated interview lists from GET /api/interviews
actor InterviewClientImpl: InterviewClient {

    // MARK: - Properties

    private let baseURL: String
    private let clientContextService: ClientContextServiceProtocol

    // MARK: - Initialization

    init(
        baseURL: String = "https://resignal-backend.vercel.app",
        clientContextService: ClientContextServiceProtocol = ClientContextService.shared
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.clientContextService = clientContextService
    }

    // MARK: - InterviewClient

    nonisolated func fetchInterviews(page: Int, pageSize: Int) async throws -> InterviewListResponse {
        try await performFetch(page: page, pageSize: pageSize)
    }

    // MARK: - Private

    private func performFetch(page: Int, pageSize: Int) async throws -> InterviewListResponse {
        let userId = clientContextService.anonymousUserId

        var components = URLComponents(string: "\(baseURL)/api/interviews")
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]

        guard let url = components?.url else {
            throw InterviewClientError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientContextService.clientId, forHTTPHeaderField: "x-client-id")
        request.setValue(clientContextService.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(clientContextService.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(clientContextService.deviceModel, forHTTPHeaderField: "x-device-model")
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw InterviewClientError.networkError("Request failed: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InterviewClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            do {
                return try decoder.decode(InterviewListResponse.self, from: data)
            } catch {
                throw InterviewClientError.invalidResponse
            }

        case 401:
            throw InterviewClientError.unauthorized

        case 429:
            throw InterviewClientError.rateLimited

        case 400...499:
            let message = String(data: data, encoding: .utf8) ?? "Client error"
            throw InterviewClientError.apiError("HTTP \(httpResponse.statusCode): \(message)")

        case 500...599:
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw InterviewClientError.apiError("HTTP \(httpResponse.statusCode): \(message)")

        default:
            throw InterviewClientError.apiError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
}
