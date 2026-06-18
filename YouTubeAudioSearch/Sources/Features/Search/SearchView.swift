import SwiftUI

struct SearchView: View {
  @Environment(YouTubeStore.self) private var store
  @State private var query = ""

  private let suggestions = [
    "acoustic covers",
    "developer podcasts",
    "deep house",
    "swiftui tutorials"
  ]

  var body: some View {
    List {
      if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Section("Quick Searches") {
          ForEach(suggestions, id: \.self) { suggestion in
            Button {
              query = suggestion
            } label: {
              Label(suggestion, systemImage: "magnifyingglass")
            }
          }
        }
      }

      if let message = store.searchState.message {
        Section {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Section("Results") {
        if store.searchState.isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        } else if store.searchResults.isEmpty {
          ContentUnavailableView("Search YouTube", systemImage: "magnifyingglass")
        } else {
          ForEach(store.searchResults) { video in
            VideoRow(
              video: video,
              isSaved: store.isSaved(video),
              onPlay: { store.play(video) },
              onSave: { store.toggleSaved(video) }
            )
          }
        }
      }
    }
    .navigationTitle("Search")
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search YouTube")
    .task(id: query) {
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else {
        return
      }
      await store.search(query)
    }
  }
}

