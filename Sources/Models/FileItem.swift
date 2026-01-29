import Foundation

/// Represents a file or directory in the file browser
struct FileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let isDirectory: Bool
    let isHidden: Bool
    var children: [FileItem]?
    var isExpanded: Bool = false

    // Git status
    var gitStatus: GitStatus = .none

    enum GitStatus {
        case none
        case modified
        case added
        case deleted
        case untracked
        case ignored

        var icon: String {
            switch self {
            case .none: return ""
            case .modified: return "M"
            case .added: return "A"
            case .deleted: return "D"
            case .untracked: return "?"
            case .ignored: return "!"
            }
        }

        var color: String {
            switch self {
            case .none: return ""
            case .modified: return "yellow"
            case .added: return "green"
            case .deleted: return "red"
            case .untracked: return "gray"
            case .ignored: return "gray"
            }
        }
    }

    init(url: URL, children: [FileItem]? = nil) {
        self.id = url.path
        self.name = url.lastPathComponent
        self.path = url
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        self.isHidden = url.lastPathComponent.hasPrefix(".")
        self.children = children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for loading file system contents
@MainActor
class FileSystemService: ObservableObject {
    @Published var rootItems: [FileItem] = []
    @Published var currentDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var expandedPaths: Set<String> = []
    @Published var gitBranch: String? = nil
    @Published var isGitRepo: Bool = false

    private let fileManager = FileManager.default
    private var gitStatusCache: [String: FileItem.GitStatus] = [:]

    // File system monitoring
    private var directoryMonitor: DirectoryMonitor?

    func loadDirectory(_ url: URL) {
        currentDirectory = url
        refreshGitStatus()
        rootItems = loadContents(of: url)
        startMonitoring(url)
    }

    // MARK: - Directory Monitoring

    private func startMonitoring(_ url: URL) {
        directoryMonitor?.stopMonitoring()
        directoryMonitor = nil

        directoryMonitor = DirectoryMonitor(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Reload contents when directory changes
                self.refreshGitStatus()
                self.rootItems = self.loadContents(of: self.currentDirectory)
            }
        }
        directoryMonitor?.startMonitoring()
    }

    func stopMonitoring() {
        directoryMonitor?.stopMonitoring()
        directoryMonitor = nil
    }

    func loadContents(of url: URL) -> [FileItem] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
            )

            return contents
                .filter { !$0.lastPathComponent.hasPrefix(".") } // Hide dotfiles by default
                .map { url in
                    var item = FileItem(url: url)
                    // Apply git status from cache
                    if let status = gitStatusCache[url.path] {
                        item.gitStatus = status
                    } else if let status = gitStatusForPath(url.path) {
                        item.gitStatus = status
                    }
                    return item
                }
                .sorted { item1, item2 in
                    // Directories first, then alphabetically
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
        } catch {
            return []
        }
    }

    func toggleExpanded(_ item: FileItem) {
        if expandedPaths.contains(item.id) {
            expandedPaths.remove(item.id)
        } else {
            expandedPaths.insert(item.id)
        }
    }

    func isExpanded(_ item: FileItem) -> Bool {
        expandedPaths.contains(item.id)
    }

    func childrenFor(_ item: FileItem) -> [FileItem]? {
        guard item.isDirectory, isExpanded(item) else { return nil }
        return loadContents(of: item.path)
    }

    // MARK: - Git Integration

    func refreshGitStatus() {
        gitStatusCache.removeAll()

        // Check if we're in a git repo
        let gitDir = findGitRoot(from: currentDirectory)
        isGitRepo = gitDir != nil

        guard isGitRepo else {
            gitBranch = nil
            return
        }

        // Get current branch
        gitBranch = getGitBranch()

        // Get file statuses
        loadGitFileStatuses()
    }

    private func findGitRoot(from url: URL) -> URL? {
        var current = url
        while current.path != "/" {
            let gitPath = current.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitPath.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private func getGitBranch() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["branch", "--show-current"]
        task.currentDirectoryURL = currentDirectory

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            // Ignore errors
        }
        return nil
    }

    private func loadGitFileStatuses() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["status", "--porcelain", "-uall"]
        task.currentDirectoryURL = currentDirectory

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseGitStatus(output)
            }
        } catch {
            // Ignore errors
        }
    }

    private func parseGitStatus(_ output: String) {
        // Git status --porcelain format:
        // XY filename
        // X = status in staging area, Y = status in working tree
        // M = modified, A = added, D = deleted, ? = untracked, ! = ignored

        guard let gitRoot = findGitRoot(from: currentDirectory) else { return }

        for line in output.split(separator: "\n") {
            guard line.count >= 3 else { continue }

            let statusChars = line.prefix(2)
            let filename = String(line.dropFirst(3))

            let fullPath = gitRoot.appendingPathComponent(filename).path

            let status: FileItem.GitStatus
            if statusChars.contains("?") {
                status = .untracked
            } else if statusChars.contains("A") {
                status = .added
            } else if statusChars.contains("D") {
                status = .deleted
            } else if statusChars.contains("M") || statusChars.contains("m") {
                status = .modified
            } else if statusChars.contains("!") {
                status = .ignored
            } else {
                status = .none
            }

            gitStatusCache[fullPath] = status

            // Also mark parent directories as modified if they contain modified files
            if status != .none && status != .ignored {
                var parent = URL(fileURLWithPath: fullPath).deletingLastPathComponent()
                while parent.path != gitRoot.path && parent.path != "/" {
                    if gitStatusCache[parent.path] == nil {
                        gitStatusCache[parent.path] = .modified
                    }
                    parent = parent.deletingLastPathComponent()
                }
            }
        }
    }

    private func gitStatusForPath(_ path: String) -> FileItem.GitStatus? {
        return gitStatusCache[path]
    }
}

// MARK: - Directory Monitor

/// Monitors a directory for file system changes using DispatchSource
class DirectoryMonitor {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.anttuii.directorymonitor", qos: .utility)

    // Debounce to avoid rapid-fire updates
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.3

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard source == nil else { return }

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.handleChange()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source?.resume()
    }

    func stopMonitoring() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        source?.cancel()
        source = nil
    }

    private func handleChange() {
        // Debounce rapid changes
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange()
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
