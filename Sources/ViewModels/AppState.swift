import Foundation
import Observation

enum FocusedPane {
    case terminal
    case sidebar
}

@MainActor
@Observable
class AppState {
    var tabs: [TerminalTab] = []
    var activeTabId: UUID?
    var sidebarVisible: Bool = false
    var previewVisible: Bool = false
    var completionManager = CompletionManager()
    var focusedPane: FocusedPane = .terminal

    // Preview state
    var previewItem: FileItem?
    var previewGitStatus: FileItem.GitStatus = .none

    // Clipboard state for copy/paste workflow
    var pendingCopyOperation: Bool = false

    init() {
        // Create first tab automatically
        let firstTabId = createTab()
        activeTabId = firstTabId
    }

    @discardableResult
    func createTab() -> UUID {
        let newTab = TerminalTab()
        tabs.append(newTab)
        return newTab.id
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return } // Keep at least one tab

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)

            // If we closed the active tab, activate another
            if activeTabId == id {
                if index < tabs.count {
                    activeTabId = tabs[index].id
                } else if !tabs.isEmpty {
                    activeTabId = tabs[tabs.count - 1].id
                }
            }
        }
    }

    var activeTab: TerminalTab? {
        guard let activeTabId = activeTabId else { return nil }
        return tabs.first(where: { $0.id == activeTabId })
    }

    func updateTabInput(_ tabId: UUID, input: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].currentInput = input
        }
    }

    func updateTabDirectory(_ tabId: UUID, directory: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].workingDirectory = URL(fileURLWithPath: directory)
        }
    }

    func updateTabSubprocess(_ tabId: UUID, inSubprocess: Bool) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].inSubprocess = inSubprocess
        }
    }

    // Handle Tab key for completion navigation
    func handleTabKey() -> Bool {
        if completionManager.isVisible {
            completionManager.selectNext()
            return true
        }
        return false
    }

    // Handle Enter key for completion selection
    func handleEnterKey() -> Bool {
        guard completionManager.isVisible,
              let selected = completionManager.selectedCompletion else {
            return false
        }

        let prefixLength = completionManager.prefixLength

        // Post notification for terminal to insert the completion
        NotificationCenter.default.post(
            name: .terminalInsertCompletion,
            object: nil,
            userInfo: [
                "insertText": selected.insertText,
                "prefixLength": prefixLength
            ]
        )

        completionManager.dismiss()
        return true
    }

    // Handle Escape key to dismiss completions
    func handleEscapeKey() -> Bool {
        if completionManager.isVisible {
            completionManager.dismiss()
            return true
        }
        return false
    }

    // Toggle focus between sidebar and terminal
    func toggleFocus() {
        if sidebarVisible {
            focusedPane = focusedPane == .terminal ? .sidebar : .terminal
        } else {
            focusedPane = .terminal
        }
    }

    // Focus specific pane
    func focusSidebar() {
        if sidebarVisible {
            focusedPane = .sidebar
        }
    }

    func focusTerminal() {
        focusedPane = .terminal
    }

    // MARK: - Preview

    func showPreview(for item: FileItem, gitStatus: FileItem.GitStatus) {
        previewItem = item
        previewGitStatus = gitStatus
        previewVisible = true
    }

    func dismissPreview() {
        previewVisible = false
        previewItem = nil
        previewGitStatus = .none
    }

    // MARK: - Copy/Paste Workflow

    func setCopyPending() {
        pendingCopyOperation = true
    }

    func clearCopyPending() {
        pendingCopyOperation = false
    }
}
