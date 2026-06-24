import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AppKit)
import AppKit
#endif

/// A single release as published on the GitHub Releases API.
public struct GitHubRelease: Equatable, Sendable {
    public let tagName: String
    public let name: String
    public let htmlURL: URL
    /// First `.dmg` asset attached to the release, if any.
    public let dmgURL: URL?
    public let body: String

    public init(tagName: String, name: String, htmlURL: URL, dmgURL: URL?, body: String) {
        self.tagName = tagName
        self.name = name
        self.htmlURL = htmlURL
        self.dmgURL = dmgURL
        self.body = body
    }

    public var version: SemVer { SemVer(tagName) }
    /// Prefer the direct DMG download when present; fall back to the release page.
    public var downloadURL: URL { dmgURL ?? htmlURL }
}

public enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(current: String)
    case updateAvailable(GitHubRelease)
    case failed(String)
}

/// Pure, network-free helpers so the parsing/URL logic is unit-testable.
public enum GitHubReleaseFetcher {
    public static func latestURL(owner: String, repo: String) -> URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    /// Decode the `/releases/latest` JSON payload. Returns nil on malformed input.
    public static func parseLatest(from data: Data) -> GitHubRelease? {
        struct Asset: Decodable { let name: String; let browser_download_url: String }
        struct Payload: Decodable {
            let tag_name: String?
            let name: String?
            let html_url: String?
            let body: String?
            let draft: Bool?
            let prerelease: Bool?
            let assets: [Asset]?
        }
        guard let p = try? JSONDecoder().decode(Payload.self, from: data),
              p.draft != true,
              let tag = p.tag_name,
              let htmlStr = p.html_url, let html = URL(string: htmlStr) else { return nil }
        let dmg = p.assets?
            .first(where: { $0.name.lowercased().hasSuffix(".dmg") })
            .flatMap { URL(string: $0.browser_download_url) }
        return GitHubRelease(tagName: tag,
                             name: (p.name?.isEmpty == false ? p.name! : tag),
                             htmlURL: html,
                             dmgURL: dmg,
                             body: p.body ?? "")
    }
}

/// Checks a public GitHub repo's latest release and, if it is newer than the
/// running app's `CFBundleShortVersionString`, prompts the user to download it.
/// No external dependencies (no Sparkle); plain GitHub Releases.
@MainActor
public final class GitHubReleaseUpdater: ObservableObject {
    public let owner: String
    public let repo: String
    public let currentVersion: String
    private let session: URLSession

    /// Non-nil only when a strictly-newer release is found → drives the prompt.
    @Published public var available: GitHubRelease?
    /// Set after a *user-initiated* check that found nothing newer.
    @Published public var showUpToDateAlert = false
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastOutcome: UpdateCheckOutcome?

    public init(owner: String, repo: String, currentVersion: String, session: URLSession = .shared) {
        self.owner = owner
        self.repo = repo
        self.currentVersion = currentVersion
        self.session = session
    }

    /// Reads the running app's marketing version from its bundle.
    public static func fromBundle(owner: String, repo: String) -> GitHubReleaseUpdater {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return GitHubReleaseUpdater(owner: owner, repo: repo, currentVersion: v)
    }

    public var canCheckForUpdates: Bool { !isChecking }

    /// The explicit "Check for Updates…" menu action.
    public func checkForUpdates() { Task { await check(userInitiated: true) } }

    /// Silent check on launch: only surfaces a prompt when something newer exists.
    public func checkOnLaunch() { Task { await check(userInitiated: false) } }

    @discardableResult
    public func check(userInitiated: Bool) async -> UpdateCheckOutcome {
        guard !isChecking else { return lastOutcome ?? .upToDate(current: currentVersion) }
        isChecking = true
        defer { isChecking = false }

        var req = URLRequest(url: GitHubReleaseFetcher.latestURL(owner: owner, repo: repo))
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let outcome: UpdateCheckOutcome
        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 {
                // No releases published yet → treat as up to date.
                outcome = .upToDate(current: currentVersion)
            } else if status == 200, let rel = GitHubReleaseFetcher.parseLatest(from: data) {
                if rel.version > SemVer(currentVersion) {
                    outcome = .updateAvailable(rel)
                } else {
                    outcome = .upToDate(current: currentVersion)
                }
            } else {
                outcome = .failed("GitHub returned HTTP \(status)")
            }
        } catch {
            outcome = .failed(error.localizedDescription)
        }

        lastOutcome = outcome
        switch outcome {
        case .updateAvailable(let rel):
            available = rel
        case .upToDate:
            if userInitiated { showUpToDateAlert = true }
        case .failed:
            if userInitiated { showUpToDateAlert = true } // tell the user the check failed
        }
        return outcome
    }

    public func openDownload() {
        guard let rel = available else { return }
        #if canImport(AppKit)
        NSWorkspace.shared.open(rel.downloadURL)
        #endif
        available = nil
    }

    public func dismiss() { available = nil }
}

#if canImport(SwiftUI)
public struct GitHubUpdatePrompt: ViewModifier {
    @ObservedObject var updater: GitHubReleaseUpdater

    public func body(content: Content) -> some View {
        content
            .alert("Update Available",
                   isPresented: Binding(get: { updater.available != nil },
                                        set: { if !$0 { updater.dismiss() } })) {
                Button("Download") { updater.openDownload() }
                Button("Later", role: .cancel) { updater.dismiss() }
            } message: {
                if let rel = updater.available {
                    Text("Version \(rel.version.description) is available — you have \(updater.currentVersion). Download the latest from GitHub Releases.")
                }
            }
            .alert("Check for Updates",
                   isPresented: $updater.showUpToDateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                switch updater.lastOutcome {
                case .failed(let msg): Text("Couldn’t check for updates: \(msg)")
                default: Text("You’re on the latest version (\(updater.currentVersion)).")
                }
            }
    }
}

public extension View {
    /// Attach the GitHub-release update prompts (newer-version alert + up-to-date alert).
    func gitHubUpdatePrompt(_ updater: GitHubReleaseUpdater) -> some View {
        modifier(GitHubUpdatePrompt(updater: updater))
    }
}
#endif
