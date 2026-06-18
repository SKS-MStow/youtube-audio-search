import SwiftUI

struct LibraryView: View {
  @Environment(YouTubeStore.self) private var store
  @Environment(\.openURL) private var openURL

  var body: some View {
    List {
      if store.savedVideos.isEmpty {
        ContentUnavailableView("No Saved Videos", systemImage: "bookmark")
      } else {
        Section("Saved") {
          ForEach(store.savedVideos) { video in
            VideoRow(
              video: video,
              isSaved: true,
              onPlay: { openURL(video.youtubeURL) },
              onSave: { store.toggleSaved(video) }
            )
          }
        }
      }
    }
    .navigationTitle("Library")
  }
}
