import Foundation
import Observation

@MainActor
@Observable
final class YouTubeStore {
  private let client: YouTubeAPIClient
  private let persistence = SavedVideoPersistence()

  let apiStatus: APIStatus
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

  init(client: YouTubeAPIClient = YouTubeAPIClient()) {
    self.client = client
    self.apiStatus = client.hasAPIKey ? .live : .demo
    self.savedVideos = persistence.load()
  }

  func loadHome() async {
    if !client.hasAPIKey {
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
    if !client.hasAPIKey {
      homeVideos = demoResults(matching: topic)
      homeState = .loaded
      return
    }

    homeState = .loading
    do {
      homeVideos = try await client.searchVideos(query: topic)
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
      if client.hasAPIKey {
        searchResults = try await client.searchVideos(query: trimmedQuery)
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
    let normalizedQuery = query.lowercased()
    let matches = YouTubeVideo.samples.filter {
      $0.title.lowercased().contains(normalizedQuery)
        || $0.channelTitle.lowercased().contains(normalizedQuery)
    }

    return matches.isEmpty ? YouTubeVideo.samples : matches
  }
}

enum APIStatus {
  case live
  case demo

  var title: String {
    switch self {
    case .live:
      "Live API"
    case .demo:
      "Demo Mode"
    }
  }

  var systemImage: String {
    switch self {
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

