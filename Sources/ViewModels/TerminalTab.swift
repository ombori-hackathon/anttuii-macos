import Foundation

struct TerminalTab: Identifiable {
    let id: UUID
    var workingDirectory: URL
    var currentInput: String = ""

    init(id: UUID = UUID(), workingDirectory: URL? = nil) {
        self.id = id
        // Default to current working directory, not home
        self.workingDirectory = workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // Title is the folder name
    var title: String {
        workingDirectory.lastPathComponent
    }
}
