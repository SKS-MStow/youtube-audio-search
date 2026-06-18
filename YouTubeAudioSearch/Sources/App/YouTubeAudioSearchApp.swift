import SwiftUI

@main
@MainActor
struct YouTubeAudioSearchApp: App {
  @State private var store = YouTubeStore()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(store)
    }
  }
}

