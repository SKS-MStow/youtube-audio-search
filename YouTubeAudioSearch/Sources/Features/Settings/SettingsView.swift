import SwiftUI

struct SettingsView: View {
  @Environment(YouTubeStore.self) private var store

  var body: some View {
    Form {
      Section("Connection") {
        LabeledContent {
          Label(store.apiStatus.title, systemImage: store.apiStatus.systemImage)
        } label: {
          Text("YouTube Data API")
        }
      }

      Section("Playback") {
        LabeledContent("Player", value: "Official Embed")
        LabeledContent("Background", value: "YouTube App")
      }

      Section("Links") {
        Link(destination: URL(string: "https://www.youtube.com/t/terms")!) {
          Label("YouTube Terms", systemImage: "doc.text")
        }

        Link(destination: URL(string: "https://policies.google.com/privacy")!) {
          Label("Google Privacy", systemImage: "hand.raised")
        }

        Link(destination: URL(string: "https://developers.google.com/youtube/v3")!) {
          Label("Data API", systemImage: "network")
        }
      }
    }
    .navigationTitle("Settings")
  }
}

