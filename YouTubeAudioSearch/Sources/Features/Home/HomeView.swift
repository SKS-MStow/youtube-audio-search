import SwiftUI

struct HomeView: View {
  @Environment(YouTubeStore.self) private var store
  @Environment(\.openURL) private var openURL
  @State private var selectedTopic = "Trending"

  private let topics = [
    "Trending",
    "AI news",
    "iOS development",
    "DJ sets",
    "Long interviews",
    "Ambient focus"
  ]

  var body: some View {
    List {
      Section {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(topics, id: \.self) { topic in
              Button {
                selectedTopic = topic
                Task {
                  await load(topic: topic)
                }
              } label: {
                Text(topic)
                  .font(.subheadline.weight(.medium))
              }
              .buttonStyle(.bordered)
              .buttonBorderShape(.capsule)
              .tint(selectedTopic == topic ? .red : .primary)
            }
          }
          .padding(.vertical, 2)
        }
      }

      if let message = store.homeState.message {
        Section {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Section("Listen Next") {
        if store.homeState.isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        } else {
          ForEach(store.homeVideos) { video in
            VideoRow(
              video: video,
              isSaved: store.isSaved(video),
              onPlay: { openURL(video.youtubeURL) },
              onSave: { store.toggleSaved(video) }
            )
          }
        }
      }
    }
    .navigationTitle("YouTube Audio")
    .refreshable {
      await load(topic: selectedTopic)
    }
    .task {
      guard store.homeState == .idle else {
        return
      }
      await load(topic: selectedTopic)
    }
  }

  private func load(topic: String) async {
    if topic == "Trending" {
      await store.loadHome()
    } else {
      await store.loadTopic(topic)
    }
  }
}
