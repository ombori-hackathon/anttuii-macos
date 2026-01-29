import AppKit
import SwiftTerm

// Notifications for key events
extension Notification.Name {
    static let terminalTabPressed = Notification.Name("terminalTabPressed")
    static let terminalEnterPressed = Notification.Name("terminalEnterPressed")
    static let terminalEscapePressed = Notification.Name("terminalEscapePressed")
    static let terminalInsertCompletion = Notification.Name("terminalInsertCompletion")
}

class AnttuiiTerminalView: LocalProcessTerminalView {
    var onInputChanged: ((String) -> Void)?
    var onDirectoryChanged: ((String) -> Void)?

    private(set) var currentInput: String = ""
    private var hasStartedProcess = false
    private(set) var currentDirectory: String = ""
    nonisolated(unsafe) private var eventMonitor: Any?

    // Track if completion is visible (set externally)
    var completionVisible: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        currentDirectory = FileManager.default.currentDirectoryPath
        configureTerminal()
        setupEventMonitor()
        setupCompletionObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        currentDirectory = FileManager.default.currentDirectoryPath
        configureTerminal()
        setupEventMonitor()
        setupCompletionObserver()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func setupCompletionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInsertCompletion(_:)),
            name: .terminalInsertCompletion,
            object: nil
        )
    }

    @objc private func handleInsertCompletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let insertText = userInfo["insertText"] as? String,
              let prefixLength = userInfo["prefixLength"] as? Int else {
            return
        }

        // Delete the prefix by sending backspace characters
        let backspace = "\u{7F}" // DEL character (backspace in terminal)
        for _ in 0..<prefixLength {
            send(txt: backspace)
        }

        // Insert the completion text
        send(txt: insertText + " ")

        // Update our tracked input
        if prefixLength <= currentInput.count {
            let prefixIndex = currentInput.index(currentInput.startIndex, offsetBy: max(0, currentInput.count - prefixLength))
            let beforePrefix = String(currentInput[..<prefixIndex])
            currentInput = beforePrefix + insertText + " "
        } else {
            currentInput = insertText + " "
        }
        onInputChanged?(currentInput)
    }

    private func configureTerminal() {
        // Set font - prefer Ubuntu Mono, fall back to SF Mono, then system monospace
        let fontSize: CGFloat = 13
        let terminalFont: NSFont
        if let ubuntuMono = NSFont(name: "UbuntuMono-Regular", size: fontSize) {
            terminalFont = ubuntuMono
        } else if let sfMono = NSFont(name: "SFMono-Regular", size: fontSize) {
            terminalFont = sfMono
        } else {
            terminalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        font = terminalFont

        // Semi-transparent dark background
        let bgColor = NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 0.95)
        nativeBackgroundColor = bgColor
        nativeForegroundColor = NSColor.white

        // Configure cursor
        caretColor = NSColor.systemBlue
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard self.window?.firstResponder === self else { return event }

            // Only intercept keys when completions are visible
            guard self.completionVisible else {
                self.handleKeyEvent(event)
                return event
            }

            // Handle Tab key for completion navigation
            if event.keyCode == 48 { // Tab
                NotificationCenter.default.post(name: .terminalTabPressed, object: nil)
                return nil // Consume the event
            }

            // Handle Enter key for completion selection
            if event.keyCode == 36 { // Return/Enter
                NotificationCenter.default.post(name: .terminalEnterPressed, object: nil)
                return nil // Consume the event
            }

            // Handle Escape key for dismissing completions
            if event.keyCode == 53 { // Escape
                NotificationCenter.default.post(name: .terminalEscapePressed, object: nil)
                return nil // Consume the event
            }

            self.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let characters = event.characters else { return }

        // Handle special keys
        if event.keyCode == 36 { // Return key
            checkForDirectoryChange()
            currentInput = ""
            onInputChanged?(currentInput)
        } else if event.keyCode == 51 { // Backspace
            if !currentInput.isEmpty {
                currentInput.removeLast()
                onInputChanged?(currentInput)
            }
        } else if event.keyCode == 53 { // Escape
            // Don't track escape
        } else if event.modifierFlags.contains(.control) {
            if characters == "\u{03}" { // Ctrl+C
                currentInput = ""
                onInputChanged?(currentInput)
            }
        } else if !event.modifierFlags.contains(.command) && event.keyCode != 48 {
            // Regular character input (not cmd shortcuts, not tab)
            for char in characters {
                if char.isASCII && (char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation || char == "-" || char == "_" || char == "/" || char == ".") {
                    currentInput.append(char)
                }
            }
            onInputChanged?(currentInput)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil && !hasStartedProcess {
            hasStartedProcess = true
            startShell()
            onDirectoryChanged?(currentDirectory)
        }

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    private func startShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        startProcess(executable: shell, args: [], environment: nil, execName: nil)
    }

    private func checkForDirectoryChange() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("cd ") {
            let path = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var newDir = path

            if path.isEmpty || path == "~" {
                newDir = FileManager.default.homeDirectoryForCurrentUser.path
            } else if path.hasPrefix("~") {
                newDir = FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst())
            } else if !path.hasPrefix("/") {
                newDir = (currentDirectory as NSString).appendingPathComponent(path)
            }

            newDir = (newDir as NSString).standardizingPath
            currentDirectory = newDir
            onDirectoryChanged?(currentDirectory)
        } else if trimmed == "cd" {
            currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            onDirectoryChanged?(currentDirectory)
        }
    }

    func resetInput() {
        currentInput = ""
        onInputChanged?(currentInput)
    }
}
