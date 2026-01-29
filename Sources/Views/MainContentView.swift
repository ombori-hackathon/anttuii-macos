import SwiftUI

struct MainContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (acts as titlebar)
            TabBar(appState: appState)

            // Main content area with optional sidebar
            HStack(spacing: 0) {
                // Sidebar
                if appState.sidebarVisible {
                    SidebarView(appState: appState)
                        .frame(width: 240)
                        .transition(.move(edge: .leading))
                }

                // Terminal content for active tab
                if let activeTab = appState.activeTab {
                    TerminalContent(
                        appState: appState,
                        tab: activeTab
                    )
                } else {
                    Text("No active terminal")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0)))
                }
            }
        }
    }
}

struct TerminalContent: View {
    @Bindable var appState: AppState
    let tab: TerminalTab

    var body: some View {
        ZStack(alignment: .top) {
            // Terminal
            TerminalWrapper(
                currentInput: Binding(
                    get: { tab.currentInput },
                    set: { newValue in
                        appState.updateTabInput(tab.id, input: newValue)
                    }
                ),
                inSubprocess: Binding(
                    get: { tab.inSubprocess },
                    set: { newValue in
                        appState.updateTabSubprocess(tab.id, inSubprocess: newValue)
                    }
                ),
                completionVisible: appState.completionManager.isVisible,
                onInputChanged: { newInput in
                    appState.updateTabInput(tab.id, input: newInput)
                    // Only request completions when not in subprocess (nano, vim, etc.)
                    if !tab.inSubprocess {
                        appState.completionManager.requestCompletions(
                            input: newInput,
                            cwd: tab.workingDirectory.path
                        )
                    } else {
                        appState.completionManager.dismiss()
                    }
                },
                onDirectoryChanged: { newDir in
                    appState.updateTabDirectory(tab.id, directory: newDir)
                }
            )

            // Completion overlay - top center
            if appState.completionManager.isVisible {
                VStack {
                    CompletionOverlay(
                        completions: appState.completionManager.completions,
                        selectedIndex: appState.completionManager.selectedIndex,
                        onSelect: { completion in
                            selectCompletion(completion)
                        }
                    )
                    .frame(maxWidth: 400)
                    .padding(.top, 50)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupNotificationObservers()
        }
    }

    private func setupNotificationObservers() {
        // Tab key - navigate completions
        NotificationCenter.default.addObserver(
            forName: .terminalTabPressed,
            object: nil,
            queue: .main
        ) { [appState] _ in
            Task { @MainActor in
                _ = appState.handleTabKey()
            }
        }

        // Enter key - select completion
        NotificationCenter.default.addObserver(
            forName: .terminalEnterPressed,
            object: nil,
            queue: .main
        ) { [appState] _ in
            Task { @MainActor in
                _ = appState.handleEnterKey()
            }
        }

        // Escape key - dismiss completions
        NotificationCenter.default.addObserver(
            forName: .terminalEscapePressed,
            object: nil,
            queue: .main
        ) { [appState] _ in
            Task { @MainActor in
                _ = appState.handleEscapeKey()
            }
        }
    }

    private func selectCompletion(_ completion: Completion) {
        let currentInput = tab.currentInput
        let prefixLength = appState.completionManager.prefixLength

        let newInput: String
        if prefixLength > 0 && prefixLength <= currentInput.count {
            let prefixIndex = currentInput.index(currentInput.startIndex, offsetBy: max(0, currentInput.count - prefixLength))
            let beforePrefix = String(currentInput[..<prefixIndex])
            newInput = beforePrefix + completion.insertText + " "
        } else {
            newInput = currentInput + completion.insertText + " "
        }

        appState.updateTabInput(tab.id, input: newInput)
        appState.completionManager.dismiss()
    }
}
