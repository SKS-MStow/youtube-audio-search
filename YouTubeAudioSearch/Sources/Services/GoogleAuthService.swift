import Foundation
@preconcurrency import GoogleSignIn
import Observation
import UIKit

@MainActor
@Observable
final class GoogleAuthService {
  static let youtubeReadonlyScope = "https://www.googleapis.com/auth/youtube.readonly"

  private(set) var state: GoogleAuthState = .signedOut
  private(set) var account: GoogleAccount?
  private var user: GIDGoogleUser?

  init() {
    configure()
  }

  var isConfigured: Bool {
    AppConfiguration.isGoogleSignInConfigured
  }

  var isSignedIn: Bool {
    account != nil
  }

  static func handle(_ url: URL) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }

  func restorePreviousSignIn() async {
    guard isConfigured else {
      state = .notConfigured
      return
    }

    do {
      try await restoreUser()
    } catch {
      state = .signedOut
    }
  }

  func signIn() async throws {
    guard isConfigured else {
      state = .notConfigured
      throw GoogleAuthServiceError.notConfigured
    }

    guard let presenter = UIApplication.shared.activeRootViewController else {
      throw GoogleAuthServiceError.missingPresenter
    }

    state = .signingIn
    do {
      try await signInUser(presenter: presenter)
    } catch {
      state = account == nil ? .signedOut : .signedIn
      throw error
    }
  }

  func signOut() {
    GIDSignIn.sharedInstance.signOut()
    user = nil
    account = nil
    state = isConfigured ? .signedOut : .notConfigured
  }

  func accessToken() async -> String? {
    guard let user else {
      return nil
    }

    do {
      return try await refresh(user)
    } catch {
      return user.accessToken.tokenString
    }
  }

  private func configure() {
    guard let clientID = AppConfiguration.googleClientID else {
      state = .notConfigured
      return
    }

    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
  }

  private func restoreUser() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let user {
          Task { @MainActor in
            self.updateAccount(with: user)
            continuation.resume()
          }
        } else {
          continuation.resume(throwing: GoogleAuthServiceError.missingUser)
        }
      }
    }
  }

  private func signInUser(presenter: UIViewController) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      GIDSignIn.sharedInstance.signIn(
        withPresenting: presenter,
        hint: nil,
        additionalScopes: [Self.youtubeReadonlyScope]
      ) { result, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let result {
          Task { @MainActor in
            self.updateAccount(with: result.user)
            continuation.resume()
          }
        } else {
          continuation.resume(throwing: GoogleAuthServiceError.missingUser)
        }
      }
    }
  }

  private func refresh(_ user: GIDGoogleUser) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      user.refreshTokensIfNeeded { refreshedUser, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let refreshedUser {
          Task { @MainActor in
            self.updateAccount(with: refreshedUser)
            continuation.resume(returning: refreshedUser.accessToken.tokenString)
          }
        } else {
          continuation.resume(throwing: GoogleAuthServiceError.missingUser)
        }
      }
    }
  }

  private func updateAccount(with user: GIDGoogleUser) {
    self.user = user
    account = GoogleAccount(
      name: user.profile?.name ?? "Google Account",
      email: user.profile?.email ?? "Signed in",
      grantedScopes: user.grantedScopes ?? []
    )
    state = .signedIn
  }
}

enum GoogleAuthState: Equatable {
  case notConfigured
  case signedOut
  case signingIn
  case signedIn

  var title: String {
    switch self {
    case .notConfigured:
      "OAuth Not Configured"
    case .signedOut:
      "Signed Out"
    case .signingIn:
      "Signing In"
    case .signedIn:
      "Signed In"
    }
  }

  var systemImage: String {
    switch self {
    case .notConfigured:
      "exclamationmark.triangle"
    case .signedOut:
      "person.crop.circle.badge.plus"
    case .signingIn:
      "clock"
    case .signedIn:
      "person.crop.circle.badge.checkmark"
    }
  }
}

struct GoogleAccount: Equatable {
  let name: String
  let email: String
  let grantedScopes: [String]
}

enum GoogleAuthServiceError: LocalizedError {
  case notConfigured
  case missingPresenter
  case missingUser

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      "Add GOOGLE_IOS_CLIENT_ID and GOOGLE_IOS_URL_SCHEME to Config/Secrets.xcconfig."
    case .missingPresenter:
      "The sign-in window is not ready yet."
    case .missingUser:
      "Google did not return an account."
    }
  }
}

private extension UIApplication {
  var activeRootViewController: UIViewController? {
    connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController?
      .topMostViewController
  }
}

private extension UIViewController {
  var topMostViewController: UIViewController {
    if let presentedViewController {
      return presentedViewController.topMostViewController
    }

    if let navigationController = self as? UINavigationController,
       let visibleViewController = navigationController.visibleViewController {
      return visibleViewController.topMostViewController
    }

    if let tabBarController = self as? UITabBarController,
       let selectedViewController = tabBarController.selectedViewController {
      return selectedViewController.topMostViewController
    }

    return self
  }
}
