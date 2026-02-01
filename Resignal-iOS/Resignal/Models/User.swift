//
//  User.swift
//  Resignal
//
//  User model for registration with Resignal backend.
//

import Foundation

/// User subscription plan
enum Plan: String, Codable, Sendable {
    case free = "free"
    case pro = "pro"
}

/// User model for registration
struct User: Codable, Sendable {
    let userId: String
    let email: String
    let plan: Plan
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case plan
    }
    
    init(userId: String, email: String, plan: Plan) {
        self.userId = userId
        self.email = email
        self.plan = plan
    }
}
