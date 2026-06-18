# YouTube Audio Search

Native iOS starter app for audio-focused YouTube browsing.

This app uses the official YouTube Data API for discovery and opens videos in YouTube for playback. A YouTube Premium subscription does not make it compliant for a third-party app to extract audio, hide the player, or keep a YouTube API player running in the background.

## Current App Slice

- SwiftUI tab shell: Home, Search, Library, Settings
- YouTube Data API client for search and popular videos
- Google Sign-In support for YouTube readonly account data
- CarPlay template scene for in-car YouTube search
- Demo fallback when no API key is configured
- YouTube app/web deep links for playback
- Local saved-video library using `UserDefaults`
- TestFlight archive/export script using App Store Connect API signing

## Setup

1. Generate the project:

   ```sh
   xcodegen generate
   ```

2. Add a YouTube Data API key:

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

   Then edit `Config/Secrets.xcconfig`:

   ```xcconfig
   YOUTUBE_API_KEY = your_key_here
   GOOGLE_IOS_CLIENT_ID = your_ios_oauth_client_id_here
   GOOGLE_IOS_URL_SCHEME = your_reversed_ios_oauth_client_id_here
   ```

3. Open and run:

   ```sh
   open YouTubeAudioSearch.xcodeproj
   ```

## TestFlight

The upload script uses the machine's configured App Store Connect API key:

```sh
scripts/archive-testflight.sh
```

## CarPlay Simulator

The Debug build includes `Config/Debug.entitlements` with `com.apple.developer.carplay-maps` as a simulator-only search harness. The audio CarPlay category rejects `CPSearchTemplate`, so Debug uses a category that allows Apple's native CarPlay search field and keyboard while we test the search UX. Real devices and TestFlight still require Apple to approve the correct CarPlay entitlement for the app identifier and app category.

To test locally:

```sh
defaults write com.apple.iphonesimulator CarPlayExtraOptions -bool YES
xcodegen generate
```

Run the app on an iPhone Simulator, then in Simulator choose `I/O > External Displays > CarPlay...`. In the setup window, keep `Touch screen` enabled and click `Run`. The YouTube Audio icon should appear on the CarPlay home screen; open it, tap Search, and use the native CarPlay keyboard. Results refresh inside the CarPlay UI once the query has at least two characters.

## Product Direction

The compliant path is an audio-first YouTube companion:

- Search, browse, save, and queue videos quickly.
- Use a visible official YouTube player for playback.
- Open videos in the YouTube app when the user wants the full Premium playback experience, including YouTube-managed background play.
- Use Google OAuth for authorized API views such as subscriptions and playlists, using an approved external user-agent flow rather than collecting credentials in the app.

Useful policy/docs:

- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/terms/developer-policies-guide
- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/player_parameters
