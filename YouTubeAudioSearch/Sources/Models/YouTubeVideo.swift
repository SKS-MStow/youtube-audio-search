import Foundation

struct YouTubeVideo: Identifiable, Hashable, Codable {
  let id: String
  let title: String
  let channelTitle: String
  let thumbnailURL: URL?
  let publishedDescription: String?
  let viewCountDescription: String?

  var youtubeURL: URL {
    URL(string: "https://www.youtube.com/watch?v=\(id)")!
  }
}

extension YouTubeVideo {
  static func samples(matching query: String) -> [YouTubeVideo] {
    let normalizedQuery = query.lowercased()
    let matches = samples.filter {
      $0.title.lowercased().contains(normalizedQuery)
        || $0.channelTitle.lowercased().contains(normalizedQuery)
    }

    return matches.isEmpty ? samples : matches
  }

  static let samples: [YouTubeVideo] = [
    YouTubeVideo(
      id: "M7lc1UVf-VE",
      title: "YouTube API Player Demo",
      channelTitle: "YouTube Developers",
      thumbnailURL: URL(string: "https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg"),
      publishedDescription: "Developer sample",
      viewCountDescription: nil
    ),
    YouTubeVideo(
      id: "jNQXAC9IVRw",
      title: "Me at the zoo",
      channelTitle: "jawed",
      thumbnailURL: URL(string: "https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg"),
      publishedDescription: "Classic YouTube",
      viewCountDescription: nil
    ),
    YouTubeVideo(
      id: "aqz-KE-bpKQ",
      title: "Big Buck Bunny",
      channelTitle: "Blender",
      thumbnailURL: URL(string: "https://i.ytimg.com/vi/aqz-KE-bpKQ/hqdefault.jpg"),
      publishedDescription: "Sample video",
      viewCountDescription: nil
    )
  ]
}
