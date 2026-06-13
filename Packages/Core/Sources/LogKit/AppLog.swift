import Foundation
import OSLog

public enum LogLevel: String, Sendable {
    case debug = "DEBUG", info = "INFO", warn = "WARN", error = "ERROR"
}

/// Simple, dependable file logger shared by every Plainware app.
///
/// Writes timestamped lines to `~/Library/Logs/Plainware/<App>.log` (the
/// standard macOS log location, also visible in Console.app), and mirrors to
/// the unified log (OSLog) and stderr. Call `AppLog.bootstrap(appName:)` once
/// at launch. Read the file to diagnose a launched app:
///
///     tail -f ~/Library/Logs/Plainware/<App>.log
public final class AppLog: @unchecked Sendable {
    public static let shared = AppLog()

    private let queue = DispatchQueue(label: "com.plainware.applog")
    private var fileHandle: FileHandle?
    private var fileURL: URL?
    private var osLogger: os.Logger?
    private var appName = "App"
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    /// Path of the active log file (or a hint if not bootstrapped yet).
    public var logPath: String { fileURL?.path ?? "~/Library/Logs/Plainware/<App>.log" }

    /// Initialise logging. Safe to call once at app startup.
    public static func bootstrap(appName: String, version: String = "") {
        shared.queue.sync { shared.openFile(appName: appName) }
        installUncaughtHandler()
        info("\(appName) launched (v\(version.isEmpty ? "?" : version), pid \(ProcessInfo.processInfo.processIdentifier))",
             category: "lifecycle")
        info("log file: \(shared.logPath)", category: "lifecycle")
    }

    private func openFile(appName: String) {
        self.appName = appName
        self.osLogger = os.Logger(subsystem: "com.plainware.\(appName.lowercased())", category: "app")
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Plainware", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(appName).log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        self.fileURL = url
        self.fileHandle = try? FileHandle(forWritingTo: url)
        _ = try? self.fileHandle?.seekToEnd()
        rawWrite("\n==== \(appName) session start \(formatter.string(from: Date())) ====")
    }

    // MARK: Public API

    public static func debug(_ m: @autoclosure () -> String, category: String = "app", file: String = #fileID, line: Int = #line) { shared.emit(.debug, m(), category, file, line) }
    public static func info(_ m: @autoclosure () -> String, category: String = "app", file: String = #fileID, line: Int = #line) { shared.emit(.info, m(), category, file, line) }
    public static func warn(_ m: @autoclosure () -> String, category: String = "app", file: String = #fileID, line: Int = #line) { shared.emit(.warn, m(), category, file, line) }
    public static func error(_ m: @autoclosure () -> String, category: String = "app", file: String = #fileID, line: Int = #line) { shared.emit(.error, m(), category, file, line) }

    private func emit(_ level: LogLevel, _ message: String, _ category: String, _ file: String, _ line: Int) {
        let ts = formatter.string(from: Date())
        let entry = "\(ts) [\(level.rawValue)] [\(category)] \(message)  (\(file):\(line))"
        queue.async {
            self.rawWrite(entry)
            switch level {
            case .error: self.osLogger?.error("\(message, privacy: .public)")
            case .warn:  self.osLogger?.warning("\(message, privacy: .public)")
            default:     self.osLogger?.log("\(message, privacy: .public)")
            }
            FileHandle.standardError.write(Data((entry + "\n").utf8))
        }
    }

    /// Must be called on `queue` (or during bootstrap).
    private func rawWrite(_ line: String) {
        guard let fh = fileHandle else { return }
        try? fh.write(contentsOf: Data((line + "\n").utf8))
    }
}

/// Logs uncaught Obj-C exceptions before the process dies. The handler is a
/// non-capturing C function pointer, so it only touches global state.
private func installUncaughtHandler() {
    NSSetUncaughtExceptionHandler { exception in
        let stack = exception.callStackSymbols.joined(separator: "\n  ")
        AppLog.error("UNCAUGHT EXCEPTION \(exception.name.rawValue): \(exception.reason ?? "nil")\n  \(stack)",
                     category: "crash")
    }
}
