//
//  TranscriptResponse.swift
//  Resignal
//
//  Response model for the interview transcript endpoint.
//

import Foundation

struct TranscriptResponse: Codable, Equatable, Sendable {
    let id: String
    let transcript: String
}
