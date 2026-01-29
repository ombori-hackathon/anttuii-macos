import SwiftUI
import SwiftTerm
import AppKit

/// Container view that adds a blur effect behind the terminal
class BlurredTerminalContainer: NSView {
    let visualEffectView: NSVisualEffectView
    let terminalView: AnttuiiTerminalView

    override init(frame frameRect: NSRect) {
        // Create visual effect view for blur
        visualEffectView = NSVisualEffectView(frame: frameRect)
        visualEffectView.material = .underWindowBackground  // Modern dark material
        visualEffectView.blendingMode = .behindWindow  // Blur content behind window
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.appearance = NSAppearance(named: .vibrantDark)

        // Create terminal view
        terminalView = AnttuiiTerminalView(frame: frameRect)

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Add visual effect view as background
        addSubview(visualEffectView)

        // Add terminal view on top
        addSubview(terminalView)

        // Make terminal background semi-transparent so blur shows through
        terminalView.wantsLayer = true
        terminalView.layer?.isOpaque = false

        // Configure terminal with semi-transparent dark background
        // Lower alpha = more blur visible, higher alpha = more solid
        let bgColor = NSColor(red: 15/255, green: 15/255, blue: 20/255, alpha: 0.65)
        terminalView.nativeBackgroundColor = bgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        visualEffectView.frame = bounds
        terminalView.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Ensure terminal gets focus
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.terminalView)
        }
    }
}

struct TerminalWrapper: NSViewRepresentable {
    @Binding var currentInput: String
    @Binding var inSubprocess: Bool
    var completionVisible: Bool
    var onInputChanged: ((String) -> Void)?
    var onDirectoryChanged: ((String) -> Void)?

    func makeNSView(context: Context) -> BlurredTerminalContainer {
        let container = BlurredTerminalContainer(frame: .zero)
        let terminalView = container.terminalView

        terminalView.onInputChanged = { newInput in
            DispatchQueue.main.async {
                currentInput = newInput
                // Also update subprocess state
                inSubprocess = terminalView.inSubprocess
                onInputChanged?(newInput)
            }
        }
        terminalView.onDirectoryChanged = { newDir in
            DispatchQueue.main.async {
                onDirectoryChanged?(newDir)
            }
        }
        terminalView.completionVisible = completionVisible

        context.coordinator.container = container
        return container
    }

    func updateNSView(_ nsView: BlurredTerminalContainer, context: Context) {
        // Sync completion visibility state
        nsView.terminalView.completionVisible = completionVisible
        // Update subprocess state from terminal
        DispatchQueue.main.async {
            inSubprocess = nsView.terminalView.inSubprocess
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: TerminalWrapper
        var container: BlurredTerminalContainer?

        init(_ parent: TerminalWrapper) {
            self.parent = parent
        }
    }
}
