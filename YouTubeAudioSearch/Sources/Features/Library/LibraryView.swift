import SwiftUI

struct LibraryView: View {
  @Environment(YouTubeStore.self) private var store

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
              onPlay: { store.play(video) },
              onSave: { store.toggleSaved(video) }
            )
          }
        }
      }
    }
    .navigationTitle("Library")
  }
}

