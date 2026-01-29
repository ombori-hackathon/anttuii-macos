import AppKit
import SwiftTerm

// Notifications for key events
extension Notification.Name {
    static let terminalTabPressed = Notification.Name("terminalTabPressed")
    static let terminalEnterPressed = Notification.Name("terminalEnterPressed")
    static let terminalEscapePressed = Notification.Name("terminalEscapePressed")
    static let terminalInsertCompletion = Notification.Name("terminalInsertCompletion")
    static let terminalInsertCommand = Notification.Name("terminalInsertCommand")
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

    // Track if we're in a subprocess (nano, vim, etc.) - completions disabled
    private(set) var inSubprocess: Bool = false
    private var lastCommand: String = ""

    // Known interactive commands that take over the terminal
    private let interactiveCommands: Set<String> = [
        "nano", "vim", "vi", "nvim", "emacs", "pico", "joe", "ne",  // editors
        "less", "more", "most", "bat",                               // pagers
        "man", "info",                                               // documentation
        "top", "htop", "btop", "glances", "nmon",                   // monitors
        "ssh", "telnet", "nc", "netcat",                            // network
        "python", "python3", "node", "irb", "ghci", "lua",          // REPLs
        "mysql", "psql", "sqlite3", "redis-cli", "mongo",           // databases
        "ftp", "sftp",                                               // file transfer
        "screen", "tmux", "byobu",                                   // multiplexers
        "watch", "tail -f",                                          // continuous output
        "git log", "git diff", "git show",                          // git pagers
    ]

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInsertCommand(_:)),
            name: .terminalInsertCommand,
            object: nil
        )
    }

    @objc private func handleInsertCommand(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let command = userInfo["command"] as? String else {
            return
        }

        // Clear current input line first (send Ctrl+U to clear)
        send(txt: "\u{15}")

        // Insert the command
        send(txt: command)

        // Update our tracked input
        currentInput = command
        onInputChanged?(currentInput)
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

        // If in subprocess, don't track input (user is in nano/vim/etc.)
        if inSubprocess {
            // Check if this might be exiting the subprocess (Ctrl+C, Ctrl+D, Ctrl+X, q, :q, etc.)
            if event.modifierFlags.contains(.control) {
                if characters == "\u{03}" || characters == "\u{04}" { // Ctrl+C or Ctrl+D
                    // Schedule a check to see if we're back at shell prompt
                    schedulePromptCheck()
                }
            }
            return
        }

        // Handle special keys
        if event.keyCode == 36 { // Return key
            checkForDirectoryChange()
            checkForSubprocessStart()
            lastCommand = currentInput
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

    // MARK: - Subprocess Detection

    private func checkForSubprocessStart() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Get the command (first word or first two words for "git log" etc.)
        let words = trimmed.split(separator: " ", maxSplits: 2).map(String.init)
        guard let firstWord = words.first else { return }

        // Check single command
        if interactiveCommands.contains(firstWord) {
            inSubprocess = true
            return
        }

        // Check two-word commands like "git log", "git diff"
        if words.count >= 2 {
            let twoWordCommand = "\(words[0]) \(words[1])"
            if interactiveCommands.contains(twoWordCommand) {
                inSubprocess = true
                return
            }
        }

        // Check for piped commands ending in less/more
        if trimmed.contains(" | less") || trimmed.contains(" | more") {
            inSubprocess = true
            return
        }
    }

    private func schedulePromptCheck() {
        // After a potential subprocess exit, wait a moment then check if we're back at prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.checkIfBackAtPrompt()
        }
    }

    private func checkIfBackAtPrompt() {
        // We can't easily access the terminal buffer content from SwiftTerm
        // Use a simple heuristic: after Ctrl+C/D, wait a moment then assume we're back at prompt
        // A more sophisticated approach would require patching SwiftTerm or using a different method

        // For now, just reset subprocess state after a brief delay
        // This works well for most cases (Ctrl+C exits most programs immediately)
        inSubprocess = false
    }

    /// Call this when terminal receives output that looks like a prompt
    func notifyPromptDetected() {
        inSubprocess = false
    }
}
