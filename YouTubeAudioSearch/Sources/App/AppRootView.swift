import SwiftUI

@MainActor
struct AppRootView: View {
  @Environment(YouTubeStore.self) private var store
  @State private var selectedTab: AppTab = .home

  var body: some View {
    @Bindable var store = store

    TabView(selection: $selectedTab) {
      ForEach(AppTab.allCases) { tab in
        NavigationStack {
          tab.content
        }
        .tabItem { tab.label }
        .tag(tab)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let video = store.nowPlaying {
        NowPlayingBar(video: video) {
          store.presentedVideo = video
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
      }
    }
    .sheet(item: $store.presentedVideo) { video in
      PlayerView(video: video)
    }
  }
}

enum AppTab: String, CaseIterable, Identifiable {
  case home
  case search
  case library
  case settings

  var id: String { rawValue }

  @ViewBuilder
  var content: some View {
    switch self {
    case .home:
      HomeView()
    case .search:
      SearchView()
    case .library:
      LibraryView()
    case .settings:
      SettingsView()
    }
  }

  @ViewBuilder
  var label: some View {
    switch self {
    case .home:
      Label("Home", systemImage: "house")
    case .search:
      Label("Search", systemImage: "magnifyingglass")
    case .library:
      Label("Library", systemImage: "bookmark")
    case .settings:
      Label("Settings", systemImage: "gearshape")
    }
  }
}

