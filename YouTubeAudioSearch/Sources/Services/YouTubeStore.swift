import Foundation
import Observation

@MainActor
@Observable
final class YouTubeStore {
  private let client: YouTubeAPIClient
  let auth: GoogleAuthService
  private let persistence = SavedVideoPersistence()

  var homeVideos: [YouTubeVideo] = YouTubeVideo.samples
  var searchResults: [YouTubeVideo] = []
  var savedVideos: [YouTubeVideo] = [] {
    didSet {
      persistence.save(savedVideos)
    }
  }

  var homeState: ContentState = .idle
  var searchState: ContentState = .idle
  var nowPlaying: YouTubeVideo?
  var presentedVideo: YouTubeVideo?
  var accountMessage: String?

  init(client: YouTubeAPIClient = YouTubeAPIClient(), auth: GoogleAuthService = GoogleAuthService()) {
    self.client = client
    self.auth = auth
    self.savedVideos = persistence.load()
  }

  var apiStatus: APIStatus {
    if auth.isSignedIn {
      .signedIn
    } else if client.hasAPIKey {
      .live
    } else {
      .demo
    }
  }

  func restoreSignIn() async {
    await auth.restorePreviousSignIn()
    if auth.isSignedIn {
      await loadHome()
    }
  }

  func signIn() async {
    accountMessage = nil
    do {
      try await auth.signIn()
      await loadHome()
    } catch {
      accountMessage = error.localizedDescription
    }
  }

  func signOut() {
    accountMessage = nil
    auth.signOut()
    homeVideos = YouTubeVideo.samples
    homeState = .loaded
  }

  func loadHome() async {
    if let accessToken = await auth.accessToken() {
      homeState = .loading
      do {
        let videos = try await client.fetchSubscriptionUploads(accessToken: accessToken)
        if videos.isEmpty {
          homeVideos = try await client.fetchPopularVideos(accessToken: accessToken)
        } else {
          homeVideos = videos
        }
        homeState = .loaded
      } catch is CancellationError {
        return
      } catch {
        homeState = .failed(error.localizedDescription)
      }
      return
    }

    if !client.hasLiveCredentials(accessToken: nil) {
      homeVideos = YouTubeVideo.samples
      homeState = .loaded
      return
    }

    homeState = .loading
    do {
      homeVideos = try await client.fetchPopularVideos()
      homeState = .loaded
    } catch is CancellationError {
      return
    } catch {
      homeVideos = YouTubeVideo.samples
      homeState = .failed(error.localizedDescription)
    }
  }

  func loadTopic(_ topic: String) async {
    let accessToken = await auth.accessToken()
    if !client.hasLiveCredentials(accessToken: accessToken) {
      homeVideos = demoResults(matching: topic)
      homeState = .loaded
      return
    }

    homeState = .loading
    do {
      homeVideos = try await client.searchVideos(query: topic, accessToken: accessToken)
      homeState = .loaded
    } catch is CancellationError {
      return
    } catch {
      homeState = .failed(error.localizedDescription)
    }
  }

  func search(_ query: String) async {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      searchResults = []
      searchState = .idle
      return
    }

    searchState = .loading
    do {
      let accessToken = await auth.accessToken()
      if client.hasLiveCredentials(accessToken: accessToken) {
        searchResults = try await client.searchVideos(query: trimmedQuery, accessToken: accessToken)
      } else {
        searchResults = demoResults(matching: trimmedQuery)
      }
      searchState = .loaded
    } catch is CancellationError {
      return
    } catch {
      searchState = .failed(error.localizedDescription)
    }
  }

  func play(_ video: YouTubeVideo) {
    nowPlaying = video
    presentedVideo = video
  }

  func toggleSaved(_ video: YouTubeVideo) {
    if let index = savedVideos.firstIndex(where: { $0.id == video.id }) {
      savedVideos.remove(at: index)
    } else {
      savedVideos.insert(video, at: 0)
    }
  }

  func isSaved(_ video: YouTubeVideo) -> Bool {
    savedVideos.contains(where: { $0.id == video.id })
  }

  private func demoResults(matching query: String) -> [YouTubeVideo] {
    YouTubeVideo.samples(matching: query)
  }
}

enum APIStatus {
  case signedIn
  case live
  case demo

  var title: String {
    switch self {
    case .signedIn:
      "Google Account"
    case .live:
      "Live API"
    case .demo:
      "Demo Mode"
    }
  }

  var systemImage: String {
    switch self {
    case .signedIn:
      "person.crop.circle.badge.checkmark"
    case .live:
      "checkmark.seal"
    case .demo:
      "play.rectangle"
    }
  }
}

private struct SavedVideoPersistence {
  private let key = "saved-videos"
  private let defaults = UserDefaults.standard

  func load() -> [YouTubeVideo] {
    guard let data = defaults.data(forKey: key),
          let videos = try? JSONDecoder().decode([YouTubeVideo].self, from: data) else {
      return []
    }
    return videos
  }

  func save(_ videos: [YouTubeVideo]) {
    guard let data = try? JSONEncoder().encode(videos) else {
      return
    }
    defaults.set(data, forKey: key)
  }
}
