import SwiftUI

struct VideoRow: View {
  let video: YouTubeVideo
  let isSaved: Bool
  let onPlay: () -> Void
  let onSave: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onPlay) {
        HStack(spacing: 12) {
          ThumbnailView(url: video.thumbnailURL)

          VStack(alignment: .leading, spacing: 5) {
            Text(video.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(2)

            Text(video.channelTitle)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)

            if let metadata = metadata {
              Text(metadata)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
          }

          Spacer(minLength: 0)
        }
      }
      .buttonStyle(.plain)

      Button(action: onSave) {
        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
          .font(.body.weight(.semibold))
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(isSaved ? "Remove saved video" : "Save video")
    }
    .padding(.vertical, 4)
  }

  private var metadata: String? {
    [video.viewCountDescription, video.publishedDescription]
      .compactMap { $0 }
      .joined(separator: " - ")
      .nilIfEmpty
  }
}

struct ThumbnailView: View {
  let url: URL?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(.secondary.opacity(0.12))

      AsyncImage(url: url) { phase in
        switch phase {
        case .empty:
          ProgressView()
            .controlSize(.small)
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        case .failure:
          Image(systemName: "play.rectangle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        @unknown default:
          EmptyView()
        }
      }

      Image(systemName: "play.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(.black.opacity(0.55), in: Circle())
    }
    .frame(width: 108, height: 61)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

