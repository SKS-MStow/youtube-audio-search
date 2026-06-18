import SwiftUI

@main
@MainActor
struct YouTubeAudioSearchApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var store = YouTubeStore()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(store)
        .task {
          await store.restoreSignIn()
        }
        .onOpenURL { url in
          _ = GoogleAuthService.handle(url)
        }
    }
  }
}
