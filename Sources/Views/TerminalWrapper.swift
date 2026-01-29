import SwiftUI
import SwiftTerm

struct TerminalWrapper: NSViewRepresentable {
    @Binding var currentInput: String
    @Binding var inSubprocess: Bool
    @Binding var cursorY: CGFloat
    var completionVisible: Bool
    var onInputChanged: ((String) -> Void)?
    var onDirectoryChanged: ((String) -> Void)?

    func makeNSView(context: Context) -> AnttuiiTerminalView {
        let terminalView = AnttuiiTerminalView(frame: .zero)
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
        terminalView.onCursorPositionChanged = { newY in
            DispatchQueue.main.async {
                cursorY = newY
            }
        }
        terminalView.completionVisible = completionVisible

        context.coordinator.terminalView = terminalView
        return terminalView
    }

    func updateNSView(_ nsView: AnttuiiTerminalView, context: Context) {
        // Sync completion visibility state
        nsView.completionVisible = completionVisible
        // Update subprocess state from terminal
        DispatchQueue.main.async {
            inSubprocess = nsView.inSubprocess
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: TerminalWrapper
        var terminalView: AnttuiiTerminalView?

        init(_ parent: TerminalWrapper) {
            self.parent = parent
        }
    }
}
