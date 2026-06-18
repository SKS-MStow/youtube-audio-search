import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSearchTemplateDelegate {
  private var interfaceController: CPInterfaceController?
  private let client = YouTubeAPIClient()
  private let auth = GoogleAuthService()
  private var resultLookup: [String: YouTubeVideo] = [:]
  private var searchQuery = ""
  private var searchGeneration = 0
  private let quickSearches = [
    "new music",
    "live acoustic",
    "developer podcasts",
    "deep house",
    "swiftui tutorials"
  ]
  private let queryPrefix = "query:"

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = interfaceController
    setRootTemplate(animated: false)

    Task { [weak self] in
      guard let self else { return }
      await auth.restorePreviousSignIn()
      setRootTemplate(animated: true)
    }
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    if self.interfaceController === interfaceController {
      self.interfaceController = nil
    }
  }

  private func setRootTemplate(animated: Bool) {
    interfaceController?.setRootTemplate(rootTemplate(), animated: animated, completion: nil)
  }

  private func rootTemplate() -> CPListTemplate {
    let search = CPListItem(text: "Search YouTube", detailText: "Search inside CarPlay")
    search.handler = { [weak self] _, completion in
      self?.showSearch()
      completion()
    }

    let feed = CPListItem(text: "Subscription Feed", detailText: feedDetailText)
    feed.isEnabled = auth.isSignedIn
    feed.handler = { [weak self] _, completion in
      self?.showSubscriptionFeed()
      completion()
    }

    let quickItems = quickSearches.map { query in
      let item = CPListItem(text: query.capitalized, detailText: "Search")
      item.handler = { [weak self] _, completion in
        self?.showResults(for: query)
        completion()
      }
      return item
    }

    let sections = [
      CPListSection(items: [search, feed], header: "YouTube", sectionIndexTitle: nil),
      CPListSection(items: quickItems, header: "Quick Searches", sectionIndexTitle: nil)
    ]

    return CPListTemplate(title: "YouTube Audio", sections: sections)
  }

  private var feedDetailText: String {
    if auth.isSignedIn {
      "Latest uploads from your subscriptions"
    } else {
      "Sign in on iPhone first"
    }
  }

  private func showSearch() {
    searchQuery = ""
    searchGeneration += 1

    let template = CPSearchTemplate()
    template.delegate = self
    interfaceController?.pushTemplate(template, animated: true, completion: nil)
  }

  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    updatedSearchText searchText: String,
    completionHandler: @escaping ([CPListItem]) -> Void
  ) {
    searchQuery = searchText
    searchGeneration += 1
    let generation = searchGeneration
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard query.count >= 2 else {
      completionHandler(suggestionItems(matching: query))
      return
    }

    Task { [weak self] in
      guard let self else {
        completionHandler([])
        return
      }
      let videos = await videos(matching: query)
      guard generation == searchGeneration else {
        completionHandler([])
        return
      }
      completionHandler(resultItems(for: Array(videos.prefix(8))))
    }
  }

  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    selectedResult item: CPListItem,
    completionHandler: @escaping () -> Void
  ) {
    if let query = query(for: item) {
      showResults(for: query)
    } else if let video = video(for: item) {
      showVideoDetail(video)
    }
    completionHandler()
  }

  func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    showResults(for: query)
  }

  private func suggestionItems(matching query: String) -> [CPListItem] {
    let loweredQuery = query.lowercased()
    let matchingSearches = quickSearches.filter { search in
      loweredQuery.isEmpty || search.localizedCaseInsensitiveContains(loweredQuery)
    }

    return matchingSearches.map { search in
      let item = CPListItem(text: search.capitalized, detailText: "Search")
      item.userInfo = queryPrefix + search
      return item
    }
  }

  private func showSubscriptionFeed() {
    guard auth.isSignedIn else { return }
    let template = pushLoadingTemplate(title: "Subscription Feed")

    Task { [weak self] in
      guard let self else { return }
      let videos = await subscriptionVideos()
      update(template, with: videos)
    }
  }

  private func showResults(for query: String) {
    let template = pushLoadingTemplate(title: query.capitalized)

    Task { [weak self] in
      guard let self else { return }
      let videos = await videos(matching: query)
      update(template, with: videos)
    }
  }

  private func pushLoadingTemplate(title: String) -> CPListTemplate {
    let item = CPListItem(text: "Loading", detailText: nil)
    item.isEnabled = false
    let template = CPListTemplate(title: title, sections: [CPListSection(items: [item])])
    interfaceController?.pushTemplate(template, animated: true, completion: nil)
    return template
  }

  private func update(_ template: CPListTemplate, with videos: [YouTubeVideo]) {
    let items = resultItems(for: videos)
    let sectionItems: [CPListItem]
    if items.isEmpty {
      let empty = CPListItem(text: "No Results", detailText: nil)
      empty.isEnabled = false
      sectionItems = [empty]
    } else {
      sectionItems = items
    }

    template.updateSections([CPListSection(items: sectionItems)])
  }

  private func showVideoDetail(_ video: YouTubeVideo) {
    resultLookup[video.id] = video

    let rows = [
      CPListItem(text: "Channel", detailText: video.channelTitle),
      CPListItem(text: "Published", detailText: video.publishedDescription ?? "YouTube video"),
      CPListItem(text: "Views", detailText: video.viewCountDescription ?? "Not available")
    ]
    rows.forEach { $0.isEnabled = false }

    let template = CPListTemplate(title: video.title, sections: [CPListSection(items: rows)])
    interfaceController?.pushTemplate(template, animated: true, completion: nil)
  }

  private func resultItems(for videos: [YouTubeVideo]) -> [CPListItem] {
    return videos.map { video in
      resultLookup[video.id] = video
      let item = CPListItem(text: video.title, detailText: video.channelTitle)
      item.userInfo = video.id
      item.handler = { [weak self] selectedItem, completion in
        if let item = selectedItem as? CPListItem,
           let video = self?.video(for: item) {
          self?.showVideoDetail(video)
        }
        completion()
      }
      return item
    }
  }

  private func video(for item: CPListItem) -> YouTubeVideo? {
    guard let id = item.userInfo as? String else {
      return nil
    }

    return resultLookup[id]
  }

  private func query(for item: CPListItem) -> String? {
    guard let value = item.userInfo as? String,
          value.hasPrefix(queryPrefix) else {
      return nil
    }

    return String(value.dropFirst(queryPrefix.count))
  }

  private func videos(matching query: String) async -> [YouTubeVideo] {
    let accessToken = await auth.accessToken()
    do {
      if client.hasLiveCredentials(accessToken: accessToken) {
        return try await client.searchVideos(query: query, accessToken: accessToken)
      }
    } catch {
      return YouTubeVideo.samples(matching: query)
    }

    return YouTubeVideo.samples(matching: query)
  }

  private func subscriptionVideos() async -> [YouTubeVideo] {
    guard let accessToken = await auth.accessToken() else {
      return []
    }

    do {
      let videos = try await client.fetchSubscriptionUploads(accessToken: accessToken)
      if videos.isEmpty {
        return try await client.fetchPopularVideos(accessToken: accessToken)
      }
      return videos
    } catch {
      return []
    }
  }
}
