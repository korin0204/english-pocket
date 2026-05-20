import Foundation

struct AppLogger {
    private let category: String

    init(category: String) {
        self.category = category
    }

    func write(_ message: String) {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("EnglishPocket", isDirectory: true)
        let fileURL = directory.appendingPathComponent("EnglishPocket.log")
        let line = "[\(Self.timestamp())] [\(category)] \(message)\n"

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("EnglishPocket log failed: %@", error.localizedDescription)
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
