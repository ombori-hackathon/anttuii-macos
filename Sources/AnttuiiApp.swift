import SwiftUI
import AppKit

@main
struct AnttuiiApp: App {
    @State private var appState = AppState()

    init() {
        // Required for swift run to show GUI window
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            MainContentView(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    let newTabId = appState.createTab()
                    appState.activeTabId = newTabId
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let activeTabId = appState.activeTabId {
                        appState.closeTab(id: activeTabId)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.tabs.count <= 1)
            }

            CommandGroup(after: .sidebar) {
                Button(appState.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.sidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button("Focus Sidebar") {
                    appState.focusSidebar()
                }
                .keyboardShortcut("h", modifiers: .control)
                .disabled(!appState.sidebarVisible)

                Button("Focus Terminal") {
                    appState.focusTerminal()
                }
                .keyboardShortcut("l", modifiers: .control)

                Button("Toggle Focus") {
                    appState.toggleFocus()
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
        }
    }
}
