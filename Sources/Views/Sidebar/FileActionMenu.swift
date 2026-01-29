import SwiftUI
import AppKit

/// File actions available in the context menu
enum FileAction: String, CaseIterable, Identifiable {
    case copy = "Copy"
    case move = "Move"
    case rename = "Rename"
    case delete = "Delete"
    case mkdir = "New Folder"
    case touch = "New File"
    case open = "Open"
    case copyPath = "Copy Path"
    case edit = "Edit"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .copy: return "cp"
        case .move: return "mv"
        case .rename: return "rn"
        case .delete: return "rm"
        case .mkdir: return "mk"
        case .touch: return "tf"
        case .open: return "op"
        case .copyPath: return "cp"
        case .edit: return "ed"
        }
    }

    var shortcut: String {
        switch self {
        case .copy: return "c"
        case .move: return "m"
        case .rename: return "r"
        case .delete: return "d"
        case .mkdir: return "n"
        case .touch: return "t"
        case .open: return "o"
        case .copyPath: return "y"
        case .edit: return "e"
        }
    }

    var color: Color {
        switch self {
        case .delete: return .red
        case .mkdir, .touch: return .green
        case .copy, .move, .rename: return .cyan
        case .open, .edit: return .yellow
        case .copyPath: return .white
        }
    }

    /// Generate the shell command for this action
    func command(for item: FileItem, in directory: URL) -> String? {
        let escapedPath = shellEscape(item.path.path)

        switch self {
        case .copy:
            return "cp -r \(escapedPath) "
        case .move:
            return "mv \(escapedPath) "
        case .rename:
            let dir = item.path.deletingLastPathComponent().path
            return "mv \(escapedPath) \(shellEscape(dir))/"
        case .delete:
            if item.isDirectory {
                return "rm -rf \(escapedPath)"
            } else {
                return "rm \(escapedPath)"
            }
        case .mkdir:
            return "mkdir "
        case .touch:
            return "touch "
        case .open:
            return "open \(escapedPath)"
        case .copyPath:
            // Copy to clipboard instead of terminal
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path.path, forType: .string)
            return nil
        case .edit:
            return "$EDITOR \(escapedPath)"
        }
    }

    private func shellEscape(_ path: String) -> String {
        // Escape special characters for shell
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: " ", with: "\\ ")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "&", with: "\\&")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
        return escaped
    }
}

/// TUI-style action menu for file operations
struct FileActionMenu: View {
    let item: FileItem
    let directory: URL
    @Binding var isVisible: Bool
    @Binding var selectedAction: Int
    let onAction: (FileAction) -> Void

    private let actions: [FileAction] = [
        .open, .edit, .copy, .move, .rename, .delete, .mkdir, .touch, .copyPath
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("┌─ ")
                    .foregroundColor(tuiMenuBorder)
                Text("ACTIONS")
                    .foregroundColor(.cyan)
                    .fontWeight(.bold)
                Text(" ─ ")
                    .foregroundColor(tuiMenuBorder)
                Text(item.name)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(" ┐")
                    .foregroundColor(tuiMenuBorder)
            }
            .frame(height: 20)

            // Action list
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                ActionRow(
                    action: action,
                    isSelected: selectedAction == index
                )
                .onTapGesture {
                    selectedAction = index
                    executeAction(action)
                }
            }

            // Footer with hints
            HStack(spacing: 0) {
                Text("├")
                    .foregroundColor(tuiMenuBorder)
                Spacer(minLength: 0)
                Text("┤")
                    .foregroundColor(tuiMenuBorder)
            }
            .frame(height: 20)

            HStack(spacing: 0) {
                Text("│ ")
                    .foregroundColor(tuiMenuBorder)
                Text("↑↓")
                    .foregroundColor(.yellow)
                Text(" select  ")
                    .foregroundColor(tuiDimColor)
                Text("⏎")
                    .foregroundColor(.yellow)
                Text(" run  ")
                    .foregroundColor(tuiDimColor)
                Text("esc")
                    .foregroundColor(.yellow)
                Text(" close")
                    .foregroundColor(tuiDimColor)
                Spacer(minLength: 0)
                Text(" │")
                    .foregroundColor(tuiMenuBorder)
            }
            .frame(height: 20)

            // Bottom border
            HStack(spacing: 0) {
                Text("└")
                    .foregroundColor(tuiMenuBorder)
                GeometryReader { geo in
                    Text(String(repeating: "─", count: max(0, Int(geo.size.width / 8))))
                        .foregroundColor(tuiMenuBorder)
                }
                Text("┘")
                    .foregroundColor(tuiMenuBorder)
            }
            .frame(height: 20)
        }
        .font(.system(size: 13, design: .monospaced))
        .background(tuiMenuBg)
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            executeAction(actions[selectedAction])
            return .handled
        }
        .onKeyPress(.escape) {
            isVisible = false
            return .handled
        }
        // Shortcut keys
        .onKeyPress("o") { executeAction(.open); return .handled }
        .onKeyPress("e") { executeAction(.edit); return .handled }
        .onKeyPress("c") { executeAction(.copy); return .handled }
        .onKeyPress("m") { executeAction(.move); return .handled }
        .onKeyPress("r") { executeAction(.rename); return .handled }
        .onKeyPress("d") { executeAction(.delete); return .handled }
        .onKeyPress("n") { executeAction(.mkdir); return .handled }
        .onKeyPress("t") { executeAction(.touch); return .handled }
        .onKeyPress("y") { executeAction(.copyPath); return .handled }
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedAction + delta
        if newIndex >= 0 && newIndex < actions.count {
            selectedAction = newIndex
        }
    }

    private func executeAction(_ action: FileAction) {
        onAction(action)
        isVisible = false
    }
}

struct ActionRow: View {
    let action: FileAction
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(tuiMenuBorder)
            Text(isSelected ? ">" : " ")
                .foregroundColor(.yellow)
            Text(" [\(action.shortcut)] ")
                .foregroundColor(action.color)
            Text(action.rawValue)
                .foregroundColor(isSelected ? .white : tuiDimColor)
            Spacer(minLength: 0)
            Text(" │")
                .foregroundColor(tuiMenuBorder)
        }
        .frame(height: 20)
        .background(isSelected ? tuiMenuSelectedBg : tuiMenuBg)
    }
}

// Menu-specific colors (slightly different from sidebar for visual distinction)
private let tuiMenuBg = Color(nsColor: NSColor(red: 25/255, green: 25/255, blue: 35/255, alpha: 0.98))
private let tuiMenuBorder = Color(white: 0.5)
private let tuiMenuSelectedBg = Color(nsColor: NSColor(red: 50/255, green: 70/255, blue: 100/255, alpha: 1.0))
private let tuiDimColor = Color(white: 0.5)
