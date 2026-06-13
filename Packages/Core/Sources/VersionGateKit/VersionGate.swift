import Foundation
import Combine
import LogKit

/// The version document for an app (Firestore `apps/{appKey}`).
public struct AppVersionInfo: Sendable, Equatable {
    public var minBuild: Int        // hard floor — below this, force update
    public var latestBuild: Int     // newest available build
    public var latestVersion: String
    public var forceUpdate: Bool    // escalate the floor to latestBuild (force everyone current)
    public var message: String
    public var downloadURL: String?
    public init(minBuild: Int, latestBuild: Int, latestVersion: String,
                forceUpdate: Bool, message: String, downloadURL: String?) {
        self.minBuild = minBuild; self.latestBuild = latestBuild; self.latestVersion = latestVersion
        self.forceUpdate = forceUpdate; self.message = message; self.downloadURL = downloadURL
    }
}

public enum VersionStatus: Sendable, Equatable {
    case ok
    case updateAvailable(latestVersion: String)
    case forceUpdate(message: String, downloadURL: String?)

    public var isForced: Bool { if case .forceUpdate = self { return true }; return false }
}

/// Checks an app's build number against a Firestore version document on launch,
/// over plain HTTPS (Firestore REST) — **no Firebase SDK**. Fails *open*: any
/// network/parse error leaves status `.ok`, so the app is never blocked by an
/// outage. Reads project id + API key from the bundled `GoogleService-Info.plist`.
@MainActor
public final class VersionGate: ObservableObject {
    @Published public private(set) var status: VersionStatus = .ok
    @Published public private(set) var info: AppVersionInfo?

    private let projectId: String
    private let apiKey: String
    private let appKey: String
    private let currentBuild: Int
    private let currentVersion: String
    private let session: URLSession

    nonisolated public init(projectId: String, apiKey: String, appKey: String,
                            currentBuild: Int, currentVersion: String, session: URLSession = .shared) {
        self.projectId = projectId; self.apiKey = apiKey; self.appKey = appKey
        self.currentBuild = currentBuild; self.currentVersion = currentVersion; self.session = session
    }

    /// Build a gate from the app's bundle. `appKey` is the Firestore doc id
    /// (e.g. "glaze"). Returns nil if no GoogleService-Info.plist is present.
    public static func fromBundle(appKey: String, bundle: Bundle = .main) -> VersionGate? {
        guard let url = bundle.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let projectId = dict["PROJECT_ID"] as? String,
              let apiKey = dict["API_KEY"] as? String else { return nil }
        let build = Int(bundle.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return VersionGate(projectId: projectId, apiKey: apiKey, appKey: appKey,
                           currentBuild: build, currentVersion: version)
    }

    private var documentURL: URL? {
        var c = URLComponents()
        c.scheme = "https"; c.host = "firestore.googleapis.com"
        c.path = "/v1/projects/\(projectId)/databases/(default)/documents/apps/\(appKey)"
        c.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return c.url
    }

    /// Fetch the version doc and update `status`. Safe to call on launch.
    public func check() async {
        guard let url = documentURL else { return }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                AppLog.warn("version check non-200 (\((resp as? HTTPURLResponse)?.statusCode ?? -1)) — failing open", category: "version")
                return
            }
            guard let info = Self.parse(data) else { return }
            self.info = info
            self.status = evaluate(info)
            AppLog.info("version check: build \(currentBuild) vs min \(info.minBuild)/latest \(info.latestBuild) → \(status)", category: "version")
        } catch {
            AppLog.warn("version check failed (\(error.localizedDescription)) — failing open", category: "version")
        }
    }

    nonisolated public func evaluate(_ i: AppVersionInfo) -> VersionStatus {
        let floor = i.forceUpdate ? i.latestBuild : i.minBuild
        if currentBuild < floor {
            return .forceUpdate(message: i.message.isEmpty
                ? "A newer version is required to keep using \(appKey.capitalized)."
                : i.message, downloadURL: i.downloadURL)
        }
        if currentBuild < i.latestBuild { return .updateAvailable(latestVersion: i.latestVersion) }
        return .ok
    }

    /// Parse a Firestore REST document JSON into `AppVersionInfo`.
    public static func parse(_ data: Data) -> AppVersionInfo? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else { return nil }
        func int(_ k: String) -> Int { Int((fields[k] as? [String: Any])?["integerValue"] as? String ?? "") ?? 0 }
        func str(_ k: String) -> String { (fields[k] as? [String: Any])?["stringValue"] as? String ?? "" }
        func bool(_ k: String) -> Bool { (fields[k] as? [String: Any])?["booleanValue"] as? Bool ?? false }
        let dl = str("downloadURL")
        return AppVersionInfo(
            minBuild: int("minBuild"), latestBuild: int("latestBuild"),
            latestVersion: str("latestVersion"), forceUpdate: bool("forceUpdate"),
            message: str("message"), downloadURL: dl.isEmpty ? nil : dl)
    }
}
