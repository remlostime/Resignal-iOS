//
//  BillingClient.swift
//  Resignal
//
//  Client for Apple subscription receipt verification via POST /api/billing/verify.
//

import Foundation

// MARK: - Response Model

struct BillingVerificationResponse: Codable, Sendable {
    let isPro: Bool
    let expiresAt: String?
}

// MARK: - Protocol

protocol BillingClientProtocol: Sendable {
    func verifyReceipt(receiptData: String) async throws -> BillingVerificationResponse
}

// MARK: - Implementation

actor BillingClientImpl: BillingClientProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    nonisolated func verifyReceipt(receiptData: String) async throws -> BillingVerificationResponse {
        let body = ReceiptVerificationRequest(receiptData: receiptData)
        return try await apiClient.request(
            "/api/billing/verify",
            method: .post,
            body: body
        )
    }
}

// MARK: - Request Model

private struct ReceiptVerificationRequest: Encodable {
    let receiptData: String
}

// MARK: - Mock

actor MockBillingClient: BillingClientProtocol {
    var mockResponse = BillingVerificationResponse(isPro: true, expiresAt: nil)
    var shouldFail = false

    nonisolated func verifyReceipt(receiptData: String) async throws -> BillingVerificationResponse {
        if await shouldFail {
            throw APIError.invalidInput("Mock billing failure")
        }
        return await mockResponse
    }
}
