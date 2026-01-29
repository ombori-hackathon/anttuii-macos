import SwiftUI
import AppKit

// MARK: - Constants
private let tuiFontSize: CGFloat = 13  // Match terminal font size
private let tuiLineHeight: CGFloat = 20
private let tuiBgColor = Color(nsColor: NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 0.95))
private let tuiBorderColor = Color(white: 0.4)
private let tuiDimColor = Color(white: 0.5)
private let tuiSelectedBg = Color(nsColor: NSColor(red: 40/255, green: 80/255, blue: 120/255, alpha: 1.0))

/// TUI-style sidebar that looks like a terminal file manager (ranger/mc style)
struct SidebarView: View {
    @Bindable var appState: AppState
    @StateObject private var fileService = FileSystemService()
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    // Action menu state
    @State private var showActionMenu: Bool = false
    @State private var actionMenuSelectedIndex: Int = 0

    private var isActive: Bool {
        appState.focusedPane == .sidebar
    }

    private var selectedItem: FileItem? {
        let itemIndex = selectedIndex - (hasParent ? 1 : 0)
        guard itemIndex >= 0 && itemIndex < fileService.rootItems.count else { return nil }
        return fileService.rootItems[itemIndex]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerSection
                TUIBoxSeparator()
                fileListSection
                TUIBoxSeparator()
                statusSection
                TUIBoxBottom()
            }

            // Action menu overlay
            if showActionMenu, let item = selectedItem {
                VStack {
                    Spacer()
                    FileActionMenu(
                        item: item,
                        directory: fileService.currentDirectory,
                        isVisible: $showActionMenu,
                        selectedAction: $actionMenuSelectedIndex,
                        onAction: { action in
                            handleFileAction(action, for: item)
                        }
                    )
                    .frame(maxWidth: 280)
                    .padding(.bottom, 40)
                }
            }
        }
        .font(.system(size: tuiFontSize, design: .monospaced))
        .background(tuiBgColor)
        .focusable()
        .focused($isFocused)
        .onAppear { loadCurrentDirectory() }
        .onChange(of: appState.activeTab?.workingDirectory) { _, newDir in
            if let dir = newDir {
                fileService.loadDirectory(dir)
                selectedIndex = 0
            }
        }
        .onChange(of: appState.focusedPane) { _, newPane in
            isFocused = (newPane == .sidebar)
        }
        .onTapGesture {
            appState.focusedPane = .sidebar
        }
        .onKeyPress(.upArrow) {
            guard !showActionMenu else { return .ignored }
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !showActionMenu else { return .ignored }
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            guard !showActionMenu else { return .ignored }
            activateSelected()
            return .handled
        }
        .onKeyPress("a") {
            guard !showActionMenu else { return .ignored }
            showActionMenuForSelected()
            return .handled
        }
        .onKeyPress("g") {
            guard !showActionMenu else { return .ignored }
            selectedIndex = 0
            return .handled
        }
        .onKeyPress("r") {
            guard !showActionMenu else { return .ignored }
            fileService.refreshGitStatus()
            return .handled
        }
        .onKeyPress(.escape) {
            if showActionMenu {
                showActionMenu = false
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 0) {
            TUIBoxTop(title: "FILES", isActive: isActive)
            pathBar
            if fileService.isGitRepo {
                gitBranchBar
            }
        }
    }

    private var pathBar: some View {
        HStack(spacing: 0) {
            Text("│ ~/")
                .foregroundColor(tuiBorderColor)
            Text(currentPathDisplay)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(" │")
                .foregroundColor(tuiBorderColor)
        }
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }

    private var gitBranchBar: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(tuiBorderColor)
            Text("")
                .foregroundColor(.orange)
            Text(" ")
            if let branch = fileService.gitBranch {
                Text(branch)
                    .foregroundColor(.green)
            } else {
                Text("detached")
                    .foregroundColor(.red)
            }
            Spacer(minLength: 0)
            Text(" │")
                .foregroundColor(tuiBorderColor)
        }
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }

    private var fileListSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                parentDirectoryRow
                fileRows
            }
        }
        .background(tuiBgColor)
    }

    @ViewBuilder
    private var parentDirectoryRow: some View {
        if fileService.currentDirectory.path != "/" {
            TUIFileLine(
                icon: "/..",
                name: "",
                iconColor: .cyan,
                isSelected: selectedIndex == 0,
                isDirectory: true,
                gitStatus: .none
            )
            .onTapGesture { navigateToParent() }
        }
    }

    private var fileRows: some View {
        ForEach(Array(fileService.rootItems.enumerated()), id: \.element.id) { index, item in
            let adjustedIndex = hasParent ? index + 1 : index
            TUIFileLine(
                icon: item.isDirectory ? "/" : " ",
                name: item.name,
                iconColor: colorForItem(item),
                isSelected: selectedIndex == adjustedIndex,
                isDirectory: item.isDirectory,
                gitStatus: item.gitStatus
            )
            .onTapGesture {
                selectedIndex = adjustedIndex
                if item.isDirectory {
                    activateItem(item)
                }
            }
        }
    }

    private var statusSection: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(tuiBorderColor)
            Text("\(fileService.rootItems.count)")
                .foregroundColor(.yellow)
            Text(" items")
                .foregroundColor(tuiDimColor)
            Spacer(minLength: 0)
            Text("a")
                .foregroundColor(.cyan)
            Text(":actions ")
                .foregroundColor(tuiDimColor)
            if fileService.isGitRepo {
                Text("r")
                    .foregroundColor(.cyan)
                Text(":refresh ")
                    .foregroundColor(tuiDimColor)
            }
            Text("│")
                .foregroundColor(tuiBorderColor)
        }
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }

    // MARK: - Computed Properties

    private var currentPathDisplay: String {
        let path = fileService.currentDirectory.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return String(path.dropFirst(home.count))
        }
        return path
    }

    private var hasParent: Bool {
        fileService.currentDirectory.path != "/"
    }

    private var totalItems: Int {
        fileService.rootItems.count + (hasParent ? 1 : 0)
    }

    // MARK: - Actions

    private func loadCurrentDirectory() {
        if let activeTab = appState.activeTab {
            fileService.loadDirectory(activeTab.workingDirectory)
        }
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < totalItems {
            selectedIndex = newIndex
        }
    }

    private func activateSelected() {
        if selectedIndex == 0 && hasParent {
            navigateToParent()
        } else {
            let itemIndex = selectedIndex - (hasParent ? 1 : 0)
            if itemIndex >= 0 && itemIndex < fileService.rootItems.count {
                activateItem(fileService.rootItems[itemIndex])
            }
        }
    }

    private func activateItem(_ item: FileItem) {
        if item.isDirectory {
            fileService.loadDirectory(item.path)
            selectedIndex = 0
            if let tabId = appState.activeTabId {
                appState.updateTabDirectory(tabId, directory: item.path.path)
            }
        } else {
            NSWorkspace.shared.open(item.path)
        }
    }

    private func navigateToParent() {
        let parent = fileService.currentDirectory.deletingLastPathComponent()
        fileService.loadDirectory(parent)
        selectedIndex = 0
        if let tabId = appState.activeTabId {
            appState.updateTabDirectory(tabId, directory: parent.path)
        }
    }

    private func colorForItem(_ item: FileItem) -> Color {
        // Git status takes priority for coloring
        switch item.gitStatus {
        case .modified: return .yellow
        case .added: return .green
        case .deleted: return .red
        case .untracked: return Color(white: 0.6)
        default: break
        }

        if item.isDirectory { return .cyan }
        switch item.path.pathExtension.lowercased() {
        case "swift": return .orange
        case "py", "js", "ts": return .yellow
        case "json", "yaml", "yml", "sh": return .green
        case "zip", "tar", "gz", "exe", "app": return .red
        default: return .white
        }
    }

    // MARK: - Action Menu

    private func showActionMenuForSelected() {
        // Only show menu for actual files/directories, not parent (..)
        guard selectedItem != nil else { return }
        actionMenuSelectedIndex = 0
        showActionMenu = true
    }

    private func handleFileAction(_ action: FileAction, for item: FileItem) {
        // Handle preview action specially
        if action.isPreviewAction {
            appState.showPreview(for: item, gitStatus: item.gitStatus)
            return
        }

        guard let command = action.command(for: item, in: fileService.currentDirectory) else {
            // Some actions like copyPath handle themselves
            return
        }

        // Send command to terminal via notification
        NotificationCenter.default.post(
            name: .terminalInsertCommand,
            object: nil,
            userInfo: ["command": command]
        )

        // Switch focus to terminal so user can complete the command
        appState.focusedPane = .terminal
    }
}

// MARK: - TUI Box Drawing Components

struct TUIBoxTop: View {
    let title: String
    var isActive: Bool = false

    private var borderColor: Color {
        isActive ? .cyan : tuiBorderColor
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("┌─ ")
                .foregroundColor(borderColor)
            Text(title)
                .foregroundColor(isActive ? .cyan : .white)
                .fontWeight(.bold)
            Text(" ")
            GeometryReader { geo in
                Text(String(repeating: "─", count: max(0, Int(geo.size.width / 8))))
                    .foregroundColor(borderColor)
            }
            Text("┐")
                .foregroundColor(borderColor)
        }
        .font(.system(size: tuiFontSize, design: .monospaced))
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }
}

struct TUIBoxBottom: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("└")
                .foregroundColor(tuiBorderColor)
            GeometryReader { geo in
                Text(String(repeating: "─", count: max(0, Int(geo.size.width / 8))))
                    .foregroundColor(tuiBorderColor)
            }
            Text("┘")
                .foregroundColor(tuiBorderColor)
        }
        .font(.system(size: tuiFontSize, design: .monospaced))
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }
}

struct TUIBoxSeparator: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("├")
                .foregroundColor(tuiBorderColor)
            GeometryReader { geo in
                Text(String(repeating: "─", count: max(0, Int(geo.size.width / 8))))
                    .foregroundColor(tuiBorderColor)
            }
            Text("┤")
                .foregroundColor(tuiBorderColor)
        }
        .font(.system(size: tuiFontSize, design: .monospaced))
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }
}

struct TUIFileLine: View {
    let icon: String
    let name: String
    let iconColor: Color
    let isSelected: Bool
    let isDirectory: Bool
    let gitStatus: FileItem.GitStatus

    var body: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(tuiBorderColor)
            Text(isSelected ? ">" : " ")
                .foregroundColor(.yellow)

            // Git status indicator
            Text(gitStatus.icon)
                .foregroundColor(gitStatusColor)
                .frame(width: 12, alignment: .leading)

            Text(icon)
                .foregroundColor(iconColor)
            Text(name)
                .foregroundColor(isDirectory ? iconColor : nameColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(" │")
                .foregroundColor(tuiBorderColor)
        }
        .font(.system(size: tuiFontSize, design: .monospaced))
        .frame(height: tuiLineHeight - 2)
        .background(isSelected ? tuiSelectedBg : tuiBgColor)
        .contentShape(Rectangle())
    }

    private var gitStatusColor: Color {
        switch gitStatus {
        case .modified: return .yellow
        case .added: return .green
        case .deleted: return .red
        case .untracked: return Color(white: 0.6)
        case .ignored: return Color(white: 0.4)
        case .none: return .clear
        }
    }

    private var nameColor: Color {
        switch gitStatus {
        case .modified: return .yellow
        case .added: return .green
        case .deleted: return .red
        case .untracked: return Color(white: 0.6)
        default: return .white
        }
    }
}
