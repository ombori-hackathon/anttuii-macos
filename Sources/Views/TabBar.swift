import SwiftUI

struct TabBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Drag area / traffic light spacer
            Color.clear
                .frame(width: 70)

            // Sidebar toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.sidebarVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(appState.sidebarVisible ? .accentColor : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.sidebarVisible ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .help("Toggle Sidebar")
            .padding(.trailing, 12)

            // Tab buttons
            HStack(spacing: 4) {
                ForEach(appState.tabs) { tab in
                    TabButton(
                        tab: tab,
                        isActive: tab.id == appState.activeTabId,
                        onSelect: {
                            appState.activeTabId = tab.id
                        },
                        onClose: {
                            appState.closeTab(id: tab.id)
                        },
                        showCloseButton: appState.tabs.count > 1
                    )
                }
            }

            // Add tab button
            Button(action: {
                let newTabId = appState.createTab()
                appState.activeTabId = newTabId
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(Capsule())
            .padding(.leading, 8)

            Spacer()
        }
        .frame(height: 40)
        .background(WindowDragArea())
        .background(VibrancyView(material: .headerView))
    }
}

// Vibrancy background for the tab bar
struct VibrancyView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// Makes the tab bar draggable to move the window
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct TabButton: View {
    let tab: TerminalTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let showCloseButton: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Close button - left side (macOS HIG)
            if showCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color(nsColor: .separatorColor).opacity(isHovered ? 0.8 : 0)))
                .opacity(isHovered || isActive ? 1 : 0.3)
                .padding(.trailing, 4)
            }

            // Tab title
            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.leading, showCloseButton ? 8 : 14)
        .padding(.trailing, 14)
        .frame(minWidth: 100, maxWidth: 180)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .background(
            Capsule()
                .fill(isHovered && !isActive ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
        )
        .contentShape(Capsule())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onSelect)
    }
}
