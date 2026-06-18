# YouTube Audio Search

Native iOS starter app for audio-focused YouTube browsing.

This app uses the official YouTube Data API for discovery and the official embedded YouTube player for playback. That means the player stays visible and standard YouTube controls remain available. A YouTube Premium subscription does not make it compliant for a third-party app to extract audio, hide the player, or keep a YouTube API player running in the background.

## Current App Slice

- SwiftUI tab shell: Home, Search, Library, Settings
- YouTube Data API client for search and popular videos
- Demo fallback when no API key is configured
- WKWebView wrapper for the official YouTube iframe player
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
   ```

3. Open and run:

   ```sh
   open YouTubeAudioSearch.xcodeproj
   ```

## TestFlight

The upload script uses the machine's App Store Connect API key at `~/.appstoreconnect/private_keys/AuthKey_Y3JLHLYZD5.p8`:

```sh
scripts/archive-testflight.sh
```

## Product Direction

The compliant path is an audio-first YouTube companion:

- Search, browse, save, and queue videos quickly.
- Use a visible official YouTube player for playback.
- Open videos in the YouTube app when the user wants the full Premium playback experience, including YouTube-managed background play.
- Add Google OAuth later for authorized API views such as subscriptions and playlists, using an approved external user-agent flow rather than collecting credentials in the app.

Useful policy/docs:

- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/terms/developer-policies-guide
- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/player_parameters
