import SwiftUI

struct PlayerView: View {
  @Environment(YouTubeStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let video: YouTubeVideo

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          YouTubePlayerWebView(videoID: video.id)
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

          VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
              .font(.title3.weight(.semibold))
              .fixedSize(horizontal: false, vertical: true)

            Text(video.channelTitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)

            if let detail = [video.viewCountDescription, video.publishedDescription].compactMap({ $0 }).joined(separator: " - ").nilIfEmpty {
              Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }

          HStack(spacing: 12) {
            Button {
              store.toggleSaved(video)
            } label: {
              Label(store.isSaved(video) ? "Saved" : "Save", systemImage: store.isSaved(video) ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.bordered)

            Link(destination: video.youtubeURL) {
              Label("Open", systemImage: "play.rectangle")
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding()
      }
      .navigationTitle("Now Playing")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

