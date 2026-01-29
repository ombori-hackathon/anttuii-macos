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

    private let fileManager = FileManager.default

    func loadDirectory(_ url: URL) {
        currentDirectory = url
        rootItems = loadContents(of: url)
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
                .map { FileItem(url: $0) }
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
}
