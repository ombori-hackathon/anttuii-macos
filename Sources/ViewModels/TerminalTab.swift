import Foundation

struct TerminalTab: Identifiable {
    let id: UUID
    var workingDirectory: URL
    var currentInput: String = ""
    var inSubprocess: Bool = false  // True when in nano/vim/etc.
    var cursorY: CGFloat = 0  // Cursor Y position in pixels for completion positioning

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
