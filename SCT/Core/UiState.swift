//
//  UiState.swift
//  Port of shared/Viewmodels.kt — sealed class UiState<out T>.
//

import Foundation

enum UiState<T> {
    case idle
    case loading
    case success(T)
    case error(String)

    var data: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Port of RoleIds in shared/SignUpScreen.kt.
enum RoleIds {
    static let SENIOR    = "c8bac46a-8a46-5c17-a84b-59e3bc85fd62"
    static let FAMILY    = "58243a78-29ac-509b-92c8-98ee04ab8e99"
    static let CAREGIVER = "a48ad94d-0e41-59d1-9166-f70ae343f432"
}

/// The "General Tasks" label the Android code hard-codes as the to-do bucket.
let todoLabelId = "50053af1-c946-5087-b59f-2a6ff835e14b"
