import SwiftUI

struct NowPlayingBar: View {
  let video: YouTubeVideo
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        ThumbnailView(url: video.thumbnailURL)
          .frame(width: 70, height: 40)

        VStack(alignment: .leading, spacing: 2) {
          Text(video.title)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
          Text(video.channelTitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.up")
          .font(.footnote.weight(.bold))
          .foregroundStyle(.secondary)
          .frame(width: 30, height: 30)
      }
      .padding(8)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open now playing")
  }
}

