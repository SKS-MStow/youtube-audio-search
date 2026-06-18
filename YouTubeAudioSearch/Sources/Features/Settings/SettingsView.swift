import SwiftUI

struct SettingsView: View {
  @Environment(YouTubeStore.self) private var store

  var body: some View {
    Form {
      Section("Google Account") {
        if let account = store.auth.account {
          LabeledContent("Name", value: account.name)
          LabeledContent("Email", value: account.email)

          Button(role: .destructive) {
            store.signOut()
          } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
          }
        } else {
          LabeledContent {
            Label(store.auth.state.title, systemImage: store.auth.state.systemImage)
          } label: {
            Text("Status")
          }

          Button {
            Task {
              await store.signIn()
            }
          } label: {
            Label("Sign In with Google", systemImage: "person.crop.circle.badge.plus")
          }
          .disabled(store.auth.state == .signingIn)
        }

        if !store.auth.isConfigured {
          Label("Google OAuth is missing from this build.", systemImage: "key.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if let message = store.accountMessage {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

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
