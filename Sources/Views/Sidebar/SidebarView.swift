import SwiftUI
import AppKit

// MARK: - Constants
private let tuiFontSize: CGFloat = 13  // Match terminal font size
private let tuiLineHeight: CGFloat = 20
private let tuiBgColor = Color(nsColor: NSColor(red: 38/255, green: 38/255, blue: 40/255, alpha: 1.0))
private let tuiBorderColor = Color(white: 0.4)
private let tuiDimColor = Color(white: 0.5)
private let tuiSelectedBg = Color(nsColor: NSColor(red: 40/255, green: 80/255, blue: 120/255, alpha: 1.0))

// MARK: - Sidebar Tab
enum SidebarTab: String, CaseIterable {
    case files = "FILES"
    case apps = "APPS"

    var shortcut: String {
        switch self {
        case .files: return "1"
        case .apps: return "2"
        }
    }
}

/// TUI-style sidebar with tabs for files and apps
struct SidebarView: View {
    @Bindable var appState: AppState
    @StateObject private var fileService = FileSystemService()
    @StateObject private var appsService = AppsService()
    @State private var selectedTab: SidebarTab = .files
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    // Action menu state (files only)
    @State private var showActionMenu: Bool = false
    @State private var actionMenuSelectedIndex: Int = 0

    private var isActive: Bool {
        appState.focusedPane == .sidebar
    }

    private var selectedFileItem: FileItem? {
        guard selectedTab == .files else { return nil }
        let itemIndex = selectedIndex - (hasParent ? 1 : 0)
        guard itemIndex >= 0 && itemIndex < fileService.rootItems.count else { return nil }
        return fileService.rootItems[itemIndex]
    }

    private var selectedAppItem: AppItem? {
        guard selectedTab == .apps else { return nil }
        guard selectedIndex >= 0 && selectedIndex < appsService.apps.count else { return nil }
        return appsService.apps[selectedIndex]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                tabBar
                Divider().background(tuiBorderColor.opacity(0.3))
                if selectedTab == .files {
                    filesHeaderSection
                    Divider().background(tuiBorderColor.opacity(0.3))
                    fileListSection
                    Divider().background(tuiBorderColor.opacity(0.3))
                    filesStatusSection
                } else {
                    appsListSection
                    Divider().background(tuiBorderColor.opacity(0.3))
                    appsStatusSection
                }
            }

            // Action menu overlay (files only)
            if showActionMenu, let item = selectedFileItem {
                // Dismiss overlay - clicking outside closes the menu
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showActionMenu = false
                    }

                VStack {
                    Spacer()
                    FileActionMenu(
                        item: item,
                        directory: fileService.currentDirectory,
                        copyPending: appState.pendingCopyOperation,
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
        .onAppear {
            loadCurrentDirectory()
            appsService.loadApps()
        }
        .onChange(of: appState.activeTab?.workingDirectory) { _, newDir in
            if let dir = newDir {
                fileService.loadDirectory(dir)
                if selectedTab == .files {
                    selectedIndex = 0
                }
            }
        }
        .onChange(of: appState.focusedPane) { _, newPane in
            isFocused = (newPane == .sidebar)
        }
        .onChange(of: selectedTab) { _, _ in
            selectedIndex = 0
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
        .onKeyPress(.tab) {
            guard !showActionMenu else { return .ignored }
            switchTab()
            return .handled
        }
        .onKeyPress("1") {
            guard !showActionMenu else { return .ignored }
            selectedTab = .files
            return .handled
        }
        .onKeyPress("2") {
            guard !showActionMenu else { return .ignored }
            selectedTab = .apps
            return .handled
        }
        .onKeyPress("a") {
            guard !showActionMenu else { return .ignored }
            if selectedTab == .files {
                showActionMenuForSelected()
            }
            return .handled
        }
        .onKeyPress("g") {
            guard !showActionMenu else { return .ignored }
            selectedIndex = 0
            return .handled
        }
        .onKeyPress("r") {
            guard !showActionMenu else { return .ignored }
            if selectedTab == .files {
                fileService.refreshGitStatus()
            } else {
                appsService.loadApps()
            }
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

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 16) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: tuiLineHeight + 4)
        .background(tuiBgColor)
    }

    private func tabButton(for tab: SidebarTab) -> some View {
        let isSelected = selectedTab == tab
        return HStack(spacing: 4) {
            Text("[\(tab.shortcut)]")
                .foregroundColor(isSelected ? .yellow : tuiDimColor)
            Text(tab.rawValue)
                .foregroundColor(isSelected ? (isActive ? .cyan : .white) : tuiDimColor)
                .fontWeight(isSelected ? .bold : .regular)
        }
        .onTapGesture {
            selectedTab = tab
        }
    }

    // MARK: - Files Tab Components

    private var filesHeaderSection: some View {
        VStack(spacing: 0) {
            pathBar
            if fileService.isGitRepo {
                gitBranchBar
            }
        }
    }

    private var pathBar: some View {
        HStack(spacing: 4) {
            Text("~/")
                .foregroundColor(tuiDimColor)
            Text(currentPathDisplay)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }

    private var gitBranchBar: some View {
        HStack(spacing: 4) {
            Text("")
                .foregroundColor(.orange)
            if let branch = fileService.gitBranch {
                Text(branch)
                    .foregroundColor(.green)
            } else {
                Text("detached")
                    .foregroundColor(.red)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
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
            ClickableFileRow(
                item: item,
                isSelected: selectedIndex == adjustedIndex,
                iconColor: colorForItem(item),
                onLeftClick: {
                    selectedIndex = adjustedIndex
                    activateItem(item)
                },
                onRightClick: {
                    selectedIndex = adjustedIndex
                    showActionMenuForSelected()
                }
            )
        }
    }

    private var filesStatusSection: some View {
        HStack(spacing: 4) {
            Text("\(fileService.rootItems.count)")
                .foregroundColor(.yellow)
            Text("items")
                .foregroundColor(tuiDimColor)
            Spacer(minLength: 0)
            Text("a")
                .foregroundColor(.cyan)
            Text(":actions")
                .foregroundColor(tuiDimColor)
            if fileService.isGitRepo {
                Text("r")
                    .foregroundColor(.cyan)
                Text(":refresh")
                    .foregroundColor(tuiDimColor)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: tuiLineHeight)
        .background(tuiBgColor)
    }

    // MARK: - Apps Tab Components

    private var appsListSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if appsService.isLoading {
                    HStack {
                        Text("Loading...")
                            .foregroundColor(tuiDimColor)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: tuiLineHeight)
                } else {
                    appRows
                }
            }
        }
        .background(tuiBgColor)
    }

    private var appRows: some View {
        ForEach(Array(appsService.apps.enumerated()), id: \.element.id) { index, app in
            TUIAppLine(
                app: app,
                isSelected: selectedIndex == index
            )
            .onTapGesture {
                selectedIndex = index
                insertAppCommand(app)
            }
        }
    }

    private var appsStatusSection: some View {
        HStack(spacing: 4) {
            Text("\(appsService.apps.count)")
                .foregroundColor(.yellow)
            Text("commands")
                .foregroundColor(tuiDimColor)
            Spacer(minLength: 0)
            Text("⏎")
                .foregroundColor(.cyan)
            Text(":insert")
                .foregroundColor(tuiDimColor)
            Text("r")
                .foregroundColor(.cyan)
            Text(":refresh")
                .foregroundColor(tuiDimColor)
        }
        .padding(.horizontal, 12)
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

    private var totalItemsForCurrentTab: Int {
        switch selectedTab {
        case .files:
            return fileService.rootItems.count + (hasParent ? 1 : 0)
        case .apps:
            return appsService.apps.count
        }
    }

    // MARK: - Actions

    private func loadCurrentDirectory() {
        if let activeTab = appState.activeTab {
            fileService.loadDirectory(activeTab.workingDirectory)
        }
    }

    private func switchTab() {
        let allTabs = SidebarTab.allCases
        if let currentIndex = allTabs.firstIndex(of: selectedTab) {
            let nextIndex = (currentIndex + 1) % allTabs.count
            selectedTab = allTabs[nextIndex]
        }
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < totalItemsForCurrentTab {
            selectedIndex = newIndex
        }
    }

    private func activateSelected() {
        switch selectedTab {
        case .files:
            activateSelectedFile()
        case .apps:
            activateSelectedApp()
        }
    }

    private func activateSelectedFile() {
        if selectedIndex == 0 && hasParent {
            navigateToParent()
        } else {
            let itemIndex = selectedIndex - (hasParent ? 1 : 0)
            if itemIndex >= 0 && itemIndex < fileService.rootItems.count {
                activateItem(fileService.rootItems[itemIndex])
            }
        }
    }

    private func activateSelectedApp() {
        guard let app = selectedAppItem else { return }
        insertAppCommand(app)
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

    private func insertAppCommand(_ app: AppItem) {
        let command = appsService.commandForApp(app)

        NotificationCenter.default.post(
            name: .terminalInsertCommand,
            object: nil,
            userInfo: ["command": command]
        )

        appState.focusedPane = .terminal
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

    // MARK: - Action Menu (Files)

    private func showActionMenuForSelected() {
        guard selectedFileItem != nil else { return }
        actionMenuSelectedIndex = 0
        showActionMenu = true
    }

    private func handleFileAction(_ action: FileAction, for item: FileItem) {
        if action.isPreviewAction {
            appState.showPreview(for: item, gitStatus: item.gitStatus)
            return
        }

        if action.isPasteAction {
            guard let destinationPath = action.command(for: item, in: fileService.currentDirectory) else {
                return
            }

            NotificationCenter.default.post(
                name: .terminalAppendText,
                object: nil,
                userInfo: ["text": destinationPath]
            )

            appState.clearCopyPending()
            appState.focusedPane = .terminal
            return
        }

        guard let command = action.command(for: item, in: fileService.currentDirectory) else {
            return
        }

        if action == .copy {
            appState.setCopyPending()
        }

        NotificationCenter.default.post(
            name: .terminalInsertCommand,
            object: nil,
            userInfo: ["command": command]
        )

        appState.focusedPane = .terminal
    }
}

// MARK: - TUI App Line

struct TUIAppLine: View {
    let app: AppItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(isSelected ? ">" : " ")
                .foregroundColor(.yellow)
                .frame(width: 14)
            Text(app.category.icon)
                .foregroundColor(categoryColor)
                .frame(width: 16, alignment: .leading)
            Text(app.name)
                .foregroundColor(isSelected ? .white : categoryColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .font(.system(size: tuiFontSize, design: .monospaced))
        .frame(height: tuiLineHeight - 2)
        .background(isSelected ? tuiSelectedBg : tuiBgColor)
        .contentShape(Rectangle())
    }

    private var categoryColor: Color {
        switch app.category {
        case .common: return .yellow
        case .git: return .orange
        case .development: return .cyan
        case .system: return .red
        case .network: return .green
        case .files: return .blue
        case .other: return .white
        }
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
            Text(isSelected ? ">" : " ")
                .foregroundColor(.yellow)
                .frame(width: 14)

            // Git status indicator
            Text(gitStatus.icon)
                .foregroundColor(gitStatusColor)
                .frame(width: 14, alignment: .leading)

            Text(icon)
                .foregroundColor(iconColor)
            Text(name)
                .foregroundColor(isDirectory ? iconColor : nameColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
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

// MARK: - Clickable File Row (handles both left and right clicks)

struct ClickableFileRow: NSViewRepresentable {
    let item: FileItem
    let isSelected: Bool
    let iconColor: Color
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> ClickableRowNSView {
        let view = ClickableRowNSView()
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        updateHostingView(view)
        return view
    }

    func updateNSView(_ nsView: ClickableRowNSView, context: Context) {
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
        updateHostingView(nsView)
    }

    private func updateHostingView(_ nsView: ClickableRowNSView) {
        let swiftUIView = TUIFileLine(
            icon: item.isDirectory ? "/" : " ",
            name: item.name,
            iconColor: iconColor,
            isSelected: isSelected,
            isDirectory: item.isDirectory,
            gitStatus: item.gitStatus
        )

        if nsView.hostingView == nil {
            let hosting = NSHostingView(rootView: swiftUIView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            nsView.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: nsView.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
            ])
            nsView.hostingView = hosting
        } else {
            nsView.hostingView?.rootView = swiftUIView
        }
    }

    class ClickableRowNSView: NSView {
        var onLeftClick: (() -> Void)?
        var onRightClick: (() -> Void)?
        var hostingView: NSHostingView<TUIFileLine>?

        override func mouseDown(with event: NSEvent) {
            onLeftClick?()
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }

        override var intrinsicContentSize: NSSize {
            return NSSize(width: NSView.noIntrinsicMetric, height: tuiLineHeight - 2)
        }
    }
}

