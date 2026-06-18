import Foundation

enum ContentState: Equatable {
  case idle
  case loading
  case loaded
  case failed(String)

  var isLoading: Bool {
    if case .loading = self {
      return true
    }
    return false
  }

  var message: String? {
    if case .failed(let message) = self {
      return message
    }
    return nil
  }
}

