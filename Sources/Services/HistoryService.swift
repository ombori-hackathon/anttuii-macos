import Foundation

/// Service for reading shell history
@MainActor
class HistoryService {
    static let shared = HistoryService()

    private var historyCache: [String] = []
    private var lastLoadTime: Date?
    private let cacheTimeout: TimeInterval = 60  // Reload every 60 seconds

    private init() {}

    /// Get history entries matching the given prefix
    func getMatchingHistory(prefix: String, limit: Int = 10) -> [String] {
        loadHistoryIfNeeded()

        guard !prefix.isEmpty else { return [] }

        let lowercasedPrefix = prefix.lowercased()

        // Find matching entries, prioritizing:
        // 1. Exact prefix matches (case-insensitive)
        // 2. Contains matches

        var prefixMatches: [String] = []
        var containsMatches: [String] = []
        var seen = Set<String>()

        // Search from most recent (end) to oldest (start)
        for entry in historyCache.reversed() {
            let lowercased = entry.lowercased()

            // Skip if already seen (dedupe)
            guard !seen.contains(entry) else { continue }

            // Skip if it's exactly the prefix (user is still typing)
            guard entry != prefix else { continue }

            if lowercased.hasPrefix(lowercasedPrefix) {
                prefixMatches.append(entry)
                seen.insert(entry)
            } else if lowercased.contains(lowercasedPrefix) {
                containsMatches.append(entry)
                seen.insert(entry)
            }

            // Stop early if we have enough
            if prefixMatches.count + containsMatches.count >= limit * 2 {
                break
            }
        }

        // Combine: prefix matches first, then contains matches
        let combined = prefixMatches + containsMatches
        return Array(combined.prefix(limit))
    }

    /// Force reload history from disk
    func reloadHistory() {
        lastLoadTime = nil
        loadHistoryIfNeeded()
    }

    private func loadHistoryIfNeeded() {
        // Check if cache is still valid
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < cacheTimeout {
            return
        }

        loadHistory()
        lastLoadTime = Date()
    }

    private func loadHistory() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Try zsh history first, then bash
        let historyFiles = [
            "\(homeDir)/.zsh_history",
            "\(homeDir)/.bash_history"
        ]

        for historyFile in historyFiles {
            if let entries = loadHistoryFile(historyFile) {
                historyCache = entries
                return
            }
        }

        historyCache = []
    }

    private func loadHistoryFile(_ path: String) -> [String]? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")

            var entries: [String] = []

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip empty lines
                guard !trimmed.isEmpty else { continue }

                // Handle zsh extended history format: ": timestamp:0;command"
                if trimmed.hasPrefix(": ") && trimmed.contains(";") {
                    if let semicolonIndex = trimmed.firstIndex(of: ";") {
                        let command = String(trimmed[trimmed.index(after: semicolonIndex)...])
                        if !command.isEmpty {
                            entries.append(command)
                        }
                    }
                } else {
                    // Regular history entry (bash format or simple zsh)
                    entries.append(trimmed)
                }
            }

            return entries.isEmpty ? nil : entries
        } catch {
            return nil
        }
    }
}
