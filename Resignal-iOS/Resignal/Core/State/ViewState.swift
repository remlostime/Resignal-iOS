//
//  ViewState.swift
//  Resignal
//
//  Unified state management type for ViewModels.
//

import Foundation

/// Represents the possible states of an async operation in a ViewModel
enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case success(T)
    case error(String)
    
    // MARK: - Convenience Properties
    
    /// Returns true if currently loading
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    /// Returns the error message if in error state
    var error: String? {
        if case .error(let message) = self { return message }
        return nil
    }
    
    /// Returns true if in error state
    var hasError: Bool {
        error != nil
    }
    
    /// Returns the success value if available
    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    /// Returns true if in success state
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    /// Returns true if in idle state
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

// MARK: - Void State Extension

/// Type alias for operations that don't return a value
typealias VoidState = ViewState<EmptyValue>

/// Empty value type for void operations
struct EmptyValue: Equatable {
    static let empty = EmptyValue()
}

