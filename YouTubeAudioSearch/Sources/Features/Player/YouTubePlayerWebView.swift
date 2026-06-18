import SwiftUI
import WebKit

struct YouTubePlayerWebView: UIViewRepresentable {
  let videoID: String

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.isScrollEnabled = false
    webView.isOpaque = false
    webView.backgroundColor = .clear
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.loadedVideoID != videoID else {
      return
    }

    context.coordinator.loadedVideoID = videoID
    webView.loadHTMLString(Self.html(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
  }

  final class Coordinator {
    var loadedVideoID: String?
  }

  private static func html(videoID: String) -> String {
    """
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width">
        <style>
          html, body {
            margin: 0;
            padding: 0;
            height: 100%;
            width: 100%;
            background: #000;
            overflow: hidden;
          }
          iframe {
            position: absolute;
            inset: 0;
            height: 100%;
            width: 100%;
            border: 0;
          }
        </style>
      </head>
      <body>
        <iframe
          src="https://www.youtube.com/embed/\(videoID)?playsinline=1&enablejsapi=1&origin=https://www.youtube.com"
          title="YouTube video player"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          allowfullscreen>
        </iframe>
      </body>
    </html>
    """
  }
}

