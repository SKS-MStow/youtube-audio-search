import Foundation

struct AppConfiguration {
  static var youtubeAPIKey: String? {
    guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String else {
      return nil
    }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != "your_key_here", !trimmed.contains("$(") else {
      return nil
    }

    return trimmed
  }
}

struct YouTubeAPIClient {
  private let apiKey: String?
  private let session: URLSession

  init(apiKey: String? = AppConfiguration.youtubeAPIKey, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  var hasAPIKey: Bool {
    apiKey != nil
  }

  func fetchPopularVideos(regionCode: String = "AU") async throws -> [YouTubeVideo] {
    let apiKey = try resolvedAPIKey()
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet,statistics"),
      URLQueryItem(name: "chart", value: "mostPopular"),
      URLQueryItem(name: "maxResults", value: "20"),
      URLQueryItem(name: "regionCode", value: regionCode),
      URLQueryItem(name: "key", value: apiKey)
    ]

    let response: VideosResponse = try await fetch(components: components)
    return response.items.map(YouTubeVideo.init(videoItem:))
  }

  func searchVideos(query: String) async throws -> [YouTubeVideo] {
    let apiKey = try resolvedAPIKey()
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet"),
      URLQueryItem(name: "maxResults", value: "20"),
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "safeSearch", value: "moderate"),
      URLQueryItem(name: "type", value: "video"),
      URLQueryItem(name: "key", value: apiKey)
    ]

    let response: SearchResponse = try await fetch(components: components)
    return response.items.compactMap(YouTubeVideo.init(searchItem:))
  }

  private func resolvedAPIKey() throws -> String {
    guard let apiKey else {
      throw YouTubeAPIClientError.missingAPIKey
    }
    return apiKey
  }

  private func fetch<Response: Decodable>(components: URLComponents) async throws -> Response {
    guard let url = components.url else {
      throw YouTubeAPIClientError.invalidURL
    }

    let (data, response) = try await session.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw YouTubeAPIClientError.badResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
        throw YouTubeAPIClientError.service(apiError.error.message)
      }
      throw YouTubeAPIClientError.httpStatus(httpResponse.statusCode)
    }

    return try JSONDecoder().decode(Response.self, from: data)
  }
}

enum YouTubeAPIClientError: LocalizedError {
  case missingAPIKey
  case invalidURL
  case badResponse
  case httpStatus(Int)
  case service(String)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      "Add a YouTube Data API key to Config/Secrets.xcconfig."
    case .invalidURL:
      "The YouTube request URL could not be built."
    case .badResponse:
      "YouTube returned an unreadable response."
    case .httpStatus(let statusCode):
      "YouTube returned HTTP \(statusCode)."
    case .service(let message):
      message
    }
  }
}

private struct SearchResponse: Decodable {
  let items: [SearchItem]
}

private struct SearchItem: Decodable {
  let id: SearchIdentifier
  let snippet: YouTubeSnippet
}

private struct SearchIdentifier: Decodable {
  let videoId: String?
}

private struct VideosResponse: Decodable {
  let items: [VideoItem]
}

private struct VideoItem: Decodable {
  let id: String
  let snippet: YouTubeSnippet
  let statistics: VideoStatistics?
}

private struct VideoStatistics: Decodable {
  let viewCount: String?
}

private struct YouTubeSnippet: Decodable {
  let publishedAt: String?
  let title: String
  let channelTitle: String
  let thumbnails: Thumbnails
}

private struct Thumbnails: Decodable {
  let defaultThumbnail: Thumbnail?
  let medium: Thumbnail?
  let high: Thumbnail?

  enum CodingKeys: String, CodingKey {
    case defaultThumbnail = "default"
    case medium
    case high
  }

  var bestURL: URL? {
    URL(string: high?.url ?? medium?.url ?? defaultThumbnail?.url ?? "")
  }
}

private struct Thumbnail: Decodable {
  let url: String
}

private struct APIErrorResponse: Decodable {
  let error: APIError

  struct APIError: Decodable {
    let message: String
  }
}

private extension YouTubeVideo {
  init?(searchItem: SearchItem) {
    guard let videoId = searchItem.id.videoId else {
      return nil
    }

    self.init(
      id: videoId,
      title: searchItem.snippet.title.htmlDecoded,
      channelTitle: searchItem.snippet.channelTitle.htmlDecoded,
      thumbnailURL: searchItem.snippet.thumbnails.bestURL,
      publishedDescription: searchItem.snippet.publishedAt?.formattedYouTubeDate,
      viewCountDescription: nil
    )
  }

  init(videoItem: VideoItem) {
    self.init(
      id: videoItem.id,
      title: videoItem.snippet.title.htmlDecoded,
      channelTitle: videoItem.snippet.channelTitle.htmlDecoded,
      thumbnailURL: videoItem.snippet.thumbnails.bestURL,
      publishedDescription: videoItem.snippet.publishedAt?.formattedYouTubeDate,
      viewCountDescription: videoItem.statistics?.viewCount?.formattedViewCount
    )
  }
}

private extension String {
  var htmlDecoded: String {
    guard let data = data(using: .utf8),
          let attributed = try? NSAttributedString(
            data: data,
            options: [
              .documentType: NSAttributedString.DocumentType.html,
              .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
          ) else {
      return self
    }

    return attributed.string
  }

  var formattedYouTubeDate: String {
    let prefix = String(prefix(10))
    return prefix.isEmpty ? self : prefix
  }

  var formattedViewCount: String? {
    guard let count = Int(self) else {
      return nil
    }

    switch count {
    case 1_000_000...:
      return String(format: "%.1fM views", Double(count) / 1_000_000)
    case 1_000...:
      return String(format: "%.1fK views", Double(count) / 1_000)
    default:
      return "\(count) views"
    }
  }
}

