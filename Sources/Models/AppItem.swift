import Foundation

/// Represents a CLI application/command
struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let category: Category

    enum Category: String, CaseIterable {
        case common = "Common"
        case git = "Git"
        case development = "Development"
        case system = "System"
        case network = "Network"
        case files = "Files"
        case other = "Other"

        var icon: String {
            switch self {
            case .common: return "★"
            case .git: return ""
            case .development: return "λ"
            case .system: return "⚙"
            case .network: return "⌁"
            case .files: return "◫"
            case .other: return "○"
            }
        }

        var color: String {
            switch self {
            case .common: return "yellow"
            case .git: return "orange"
            case .development: return "cyan"
            case .system: return "red"
            case .network: return "green"
            case .files: return "blue"
            case .other: return "white"
            }
        }
    }

    init(name: String, path: String, category: Category = .other) {
        self.id = path
        self.name = name
        self.path = path
        self.category = category
    }
}

/// Service for discovering installed CLI applications
@MainActor
class AppsService: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var isLoading: Bool = false

    // Common commands that users frequently need
    private let commonCommands: [(String, AppItem.Category)] = [
        // Common
        ("ls", .common),
        ("cd", .common),
        ("pwd", .common),
        ("cat", .common),
        ("echo", .common),
        ("clear", .common),
        ("history", .common),

        // Git
        ("git", .git),

        // Development
        ("python", .development),
        ("python3", .development),
        ("node", .development),
        ("npm", .development),
        ("npx", .development),
        ("yarn", .development),
        ("swift", .development),
        ("cargo", .development),
        ("go", .development),
        ("ruby", .development),
        ("java", .development),
        ("javac", .development),
        ("gcc", .development),
        ("make", .development),
        ("cmake", .development),

        // Package managers
        ("brew", .development),
        ("pip", .development),
        ("pip3", .development),
        ("gem", .development),

        // System
        ("sudo", .system),
        ("top", .system),
        ("htop", .system),
        ("ps", .system),
        ("kill", .system),
        ("killall", .system),
        ("df", .system),
        ("du", .system),
        ("whoami", .system),
        ("uname", .system),
        ("which", .system),
        ("env", .system),
        ("export", .system),

        // Network
        ("curl", .network),
        ("wget", .network),
        ("ssh", .network),
        ("scp", .network),
        ("ping", .network),
        ("ifconfig", .network),
        ("netstat", .network),
        ("nc", .network),

        // Files
        ("cp", .files),
        ("mv", .files),
        ("rm", .files),
        ("mkdir", .files),
        ("rmdir", .files),
        ("touch", .files),
        ("chmod", .files),
        ("chown", .files),
        ("ln", .files),
        ("find", .files),
        ("grep", .files),
        ("sed", .files),
        ("awk", .files),
        ("tar", .files),
        ("zip", .files),
        ("unzip", .files),
        ("head", .files),
        ("tail", .files),
        ("less", .files),
        ("more", .files),
        ("nano", .files),
        ("vim", .files),

        // Other useful
        ("man", .other),
        ("open", .other),
        ("xcode-select", .development),
        ("xcrun", .development),
        ("docker", .development),
        ("kubectl", .development),
        ("terraform", .development),
        ("aws", .network),
        ("gcloud", .network),
        ("az", .network),
        ("jq", .other),
        ("yq", .other),
        ("bat", .files),
        ("exa", .files),
        ("fd", .files),
        ("rg", .files),
        ("fzf", .other),
        ("tmux", .other),
        ("screen", .other),
    ]

    // Directories to search for commands
    private let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    func loadApps() {
        isLoading = true
        apps = []

        var foundApps: [AppItem] = []
        var seenNames = Set<String>()

        // Build category lookup from common commands
        var categoryLookup: [String: AppItem.Category] = [:]
        for (name, category) in commonCommands {
            categoryLookup[name] = category
        }

        // First, add common commands that exist
        for (name, category) in commonCommands {
            if let path = findCommand(name), !seenNames.contains(name) {
                foundApps.append(AppItem(name: name, path: path, category: category))
                seenNames.insert(name)
            }
        }

        // Add Homebrew formulae (CLI tools only, not casks)
        let brewFormulae = getBrewFormulae()
        for name in brewFormulae {
            guard !seenNames.contains(name) else { continue }
            if let path = findCommand(name) {
                let category = categoryLookup[name] ?? .other
                foundApps.append(AppItem(name: name, path: path, category: category))
                seenNames.insert(name)
            }
        }

        // Sort by category, then by name
        apps = foundApps.sorted { a, b in
            if a.category == b.category {
                return a.name < b.name
            }
            // Common first, then alphabetically by category
            if a.category == .common { return true }
            if b.category == .common { return false }
            return a.category.rawValue < b.category.rawValue
        }

        isLoading = false
    }

    private func getBrewFormulae() -> [String] {
        // Try to find brew
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return []
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = ["list", "--formula", "-1"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output
                    .split(separator: "\n")
                    .map(String.init)
                    .filter { !$0.isEmpty }
            }
        } catch {
            // Ignore errors
        }

        return []
    }

    private func findCommand(_ name: String) -> String? {
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    func commandForApp(_ app: AppItem) -> String {
        // Just return the command name (not full path) for cleaner terminal usage
        return app.name + " "
    }
}
