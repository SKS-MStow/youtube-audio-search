import Foundation

struct AppConfiguration {
  static var youtubeAPIKey: String? {
    resolvedString(for: "YOUTUBE_API_KEY")
  }

  static var googleClientID: String? {
    resolvedString(for: "GIDClientID")
  }

  static var isGoogleSignInConfigured: Bool {
    googleClientID != nil && googleURLScheme != nil
  }

  private static var googleURLScheme: String? {
    guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
      return nil
    }

    return urlTypes
      .compactMap { $0["CFBundleURLSchemes"] as? [String] }
      .flatMap { $0 }
      .first(where: { resolvedValue($0) != nil })
  }

  private static func resolvedString(for key: String) -> String? {
    guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }

    return resolvedValue(rawValue)
  }

  private static func resolvedValue(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          trimmed != "your_key_here",
          trimmed != "your_ios_oauth_client_id_here",
          trimmed != "your_reversed_ios_oauth_client_id_here",
          !trimmed.contains("$(") else {
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

  func hasLiveCredentials(accessToken: String?) -> Bool {
    accessToken != nil || apiKey != nil
  }

  func fetchPopularVideos(regionCode: String = "AU", accessToken: String? = nil) async throws -> [YouTubeVideo] {
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet,statistics"),
      URLQueryItem(name: "chart", value: "mostPopular"),
      URLQueryItem(name: "maxResults", value: "20"),
      URLQueryItem(name: "regionCode", value: regionCode)
    ]

    let response: VideosResponse = try await fetch(components: components, accessToken: accessToken)
    return response.items.map(YouTubeVideo.init(videoItem:))
  }

  func searchVideos(query: String, accessToken: String? = nil) async throws -> [YouTubeVideo] {
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet"),
      URLQueryItem(name: "maxResults", value: "20"),
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "safeSearch", value: "moderate"),
      URLQueryItem(name: "type", value: "video")
    ]

    let response: SearchResponse = try await fetch(components: components, accessToken: accessToken)
    return response.items.compactMap(YouTubeVideo.init(searchItem:))
  }

  func fetchSubscriptionUploads(accessToken: String) async throws -> [YouTubeVideo] {
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/subscriptions")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet"),
      URLQueryItem(name: "mine", value: "true"),
      URLQueryItem(name: "maxResults", value: "20")
    ]

    let response: SubscriptionsResponse = try await fetch(components: components, accessToken: accessToken)
    let channelIDs = response.items.compactMap(\.snippet.resourceId.channelId)

    var videos: [YouTubeVideo] = []
    for channelID in channelIDs.prefix(12) {
      if let channelVideos = try? await fetchLatestUploads(channelID: channelID, accessToken: accessToken) {
        videos.append(contentsOf: channelVideos)
      }
    }

    return videos
  }

  private func fetchLatestUploads(channelID: String, accessToken: String) async throws -> [YouTubeVideo] {
    var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/activities")!
    components.queryItems = [
      URLQueryItem(name: "part", value: "snippet,contentDetails"),
      URLQueryItem(name: "channelId", value: channelID),
      URLQueryItem(name: "maxResults", value: "2")
    ]

    let response: ActivitiesResponse = try await fetch(components: components, accessToken: accessToken)
    return response.items.compactMap(YouTubeVideo.init(activityItem:))
  }

  private func fetch<Response: Decodable>(components: URLComponents, accessToken: String?) async throws -> Response {
    let request = try authenticatedRequest(components: components, accessToken: accessToken)

    let (data, response) = try await session.data(for: request)
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

  private func authenticatedRequest(components: URLComponents, accessToken: String?) throws -> URLRequest {
    var components = components
    var request: URLRequest

    if let accessToken {
      guard let url = components.url else {
        throw YouTubeAPIClientError.invalidURL
      }
      request = URLRequest(url: url)
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    } else if let apiKey {
      var queryItems = components.queryItems ?? []
      queryItems.append(URLQueryItem(name: "key", value: apiKey))
      components.queryItems = queryItems
      guard let url = components.url else {
        throw YouTubeAPIClientError.invalidURL
      }
      request = URLRequest(url: url)
    } else {
      throw YouTubeAPIClientError.missingCredentials
    }

    return request
  }
}

enum YouTubeAPIClientError: LocalizedError {
  case missingCredentials
  case invalidURL
  case badResponse
  case httpStatus(Int)
  case service(String)

  var errorDescription: String? {
    switch self {
    case .missingCredentials:
      "Sign in with Google or add a YouTube Data API key to Config/Secrets.xcconfig."
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

private struct SubscriptionsResponse: Decodable {
  let items: [SubscriptionItem]
}

private struct SubscriptionItem: Decodable {
  let snippet: SubscriptionSnippet
}

private struct SubscriptionSnippet: Decodable {
  let resourceId: SubscriptionResourceID
}

private struct SubscriptionResourceID: Decodable {
  let channelId: String?
}

private struct ActivitiesResponse: Decodable {
  let items: [ActivityItem]
}

private struct ActivityItem: Decodable {
  let snippet: YouTubeSnippet
  let contentDetails: ActivityContentDetails?
}

private struct ActivityContentDetails: Decodable {
  let upload: ActivityUpload?
}

private struct ActivityUpload: Decodable {
  let videoId: String
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

  init?(activityItem: ActivityItem) {
    guard let videoId = activityItem.contentDetails?.upload?.videoId else {
      return nil
    }

    self.init(
      id: videoId,
      title: activityItem.snippet.title.htmlDecoded,
      channelTitle: activityItem.snippet.channelTitle.htmlDecoded,
      thumbnailURL: activityItem.snippet.thumbnails.bestURL,
      publishedDescription: activityItem.snippet.publishedAt?.formattedYouTubeDate,
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
    guard let date = ISO8601DateFormatter().date(from: self) else {
      return self
    }

    return date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
  }

  var formattedViewCount: String {
    guard let value = Double(self) else {
      return self
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1

    switch value {
    case 1_000_000_000...:
      return "\(formatter.string(from: NSNumber(value: value / 1_000_000_000)) ?? "")B views"
    case 1_000_000...:
      return "\(formatter.string(from: NSNumber(value: value / 1_000_000)) ?? "")M views"
    case 1_000...:
      return "\(formatter.string(from: NSNumber(value: value / 1_000)) ?? "")K views"
    default:
      return "\(Int(value)) views"
    }
  }
}
