import SwiftUI
import AppKit

// MARK: - Preview Constants
private let previewBgColor = Color(nsColor: NSColor(red: 25/255, green: 25/255, blue: 30/255, alpha: 0.98))
private let previewBorderColor = Color(white: 0.4)
private let previewDimColor = Color(white: 0.5)
private let previewFontSize: CGFloat = 12
private let previewLineHeight: CGFloat = 18

/// TUI-style file preview overlay that appears over the terminal
struct FilePreviewOverlay: View {
    let item: FileItem
    let gitStatus: FileItem.GitStatus
    let onDismiss: () -> Void

    @State private var fileContent: String = ""
    @State private var gitDiff: GitDiffResult?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            separatorLine

            // Content area
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let diff = gitDiff, gitStatus == .modified {
                // Split diff view for modified files
                diffView(diff)
            } else {
                // Regular file content view
                contentView
            }

            separatorLine
            // Footer with hints
            footerSection
            bottomBorder
        }
        .font(.system(size: previewFontSize, design: .monospaced))
        .background(previewBgColor)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            loadContent()
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress("q") {
            onDismiss()
            return .handled
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        HStack(spacing: 0) {
            Text("┌─ ")
                .foregroundColor(previewBorderColor)
            Text("PREVIEW")
                .foregroundColor(.cyan)
                .fontWeight(.bold)
            Text(" ─ ")
                .foregroundColor(previewBorderColor)
            Text(item.name)
                .foregroundColor(.white)
                .lineLimit(1)
            if gitStatus == .modified {
                Text(" ")
                Text("[M]")
                    .foregroundColor(.yellow)
            }
            Spacer(minLength: 0)
            Text(" ┐")
                .foregroundColor(previewBorderColor)
        }
        .frame(height: 24)
        .padding(.horizontal, 4)
    }

    private var separatorLine: some View {
        HStack(spacing: 0) {
            Text("├")
                .foregroundColor(previewBorderColor)
            GeometryReader { geo in
                Text(String(repeating: "─", count: max(0, Int(geo.size.width / 7))))
                    .foregroundColor(previewBorderColor)
            }
            Text("┤")
                .foregroundColor(previewBorderColor)
        }
        .frame(height: 18)
    }

    private var bottomBorder: some View {
        HStack(spacing: 0) {
            Text("└")
                .foregroundColor(previewBorderColor)
            GeometryReader { geo in
                Text(String(repeating: "─", count: max(0, Int(geo.size.width / 7))))
                    .foregroundColor(previewBorderColor)
            }
            Text("┘")
                .foregroundColor(previewBorderColor)
        }
        .frame(height: 18)
    }

    private var footerSection: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(previewBorderColor)
            Text("esc")
                .foregroundColor(.yellow)
            Text("/")
                .foregroundColor(previewDimColor)
            Text("q")
                .foregroundColor(.yellow)
            Text(" close")
                .foregroundColor(previewDimColor)
            Spacer(minLength: 0)
            if gitStatus == .modified {
                Text("showing diff ")
                    .foregroundColor(previewDimColor)
            }
            Text(" │")
                .foregroundColor(previewBorderColor)
        }
        .frame(height: 20)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            Text("Loading...")
                .foregroundColor(previewDimColor)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text("Error: \(message)")
                .foregroundColor(.red)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                let lines = fileContent.components(separatedBy: "\n")
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: 0) {
                        Text("│ ")
                            .foregroundColor(previewBorderColor)
                        Text(String(format: "%4d", index + 1))
                            .foregroundColor(previewDimColor)
                            .frame(width: 40, alignment: .trailing)
                        Text(" │ ")
                            .foregroundColor(previewBorderColor)
                        Text(line.isEmpty ? " " : line)
                            .foregroundColor(.white)
                        Spacer(minLength: 0)
                        Text(" │")
                            .foregroundColor(previewBorderColor)
                    }
                    .frame(height: previewLineHeight)
                }
            }
        }
        .background(previewBgColor)
    }

    private func diffView(_ diff: GitDiffResult) -> some View {
        HSplitView {
            // Left side: committed version
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("│ ")
                        .foregroundColor(previewBorderColor)
                    Text("COMMITTED")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    Spacer()
                    Text(" │")
                        .foregroundColor(previewBorderColor)
                }
                .frame(height: 20)
                .background(Color(white: 0.15))

                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.oldLines.enumerated()), id: \.offset) { index, line in
                            DiffLineView(
                                lineNumber: index + 1,
                                content: line.content,
                                status: line.status
                            )
                        }
                    }
                }
            }
            .frame(minWidth: 200)

            // Right side: current/modified version
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("│ ")
                        .foregroundColor(previewBorderColor)
                    Text("MODIFIED")
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                    Spacer()
                    Text(" │")
                        .foregroundColor(previewBorderColor)
                }
                .frame(height: 20)
                .background(Color(white: 0.15))

                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.newLines.enumerated()), id: \.offset) { index, line in
                            DiffLineView(
                                lineNumber: index + 1,
                                content: line.content,
                                status: line.status
                            )
                        }
                    }
                }
            }
            .frame(minWidth: 200)
        }
        .background(previewBgColor)
    }

    // MARK: - Data Loading

    private func loadContent() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Check if file is too large (> 1MB)
                let attrs = try FileManager.default.attributesOfItem(atPath: item.path.path)
                if let size = attrs[.size] as? Int, size > 1_000_000 {
                    await MainActor.run {
                        errorMessage = "File too large to preview (> 1MB)"
                        isLoading = false
                    }
                    return
                }

                // Check if file is binary
                if isBinaryFile(item.path) {
                    await MainActor.run {
                        errorMessage = "Binary file cannot be previewed"
                        isLoading = false
                    }
                    return
                }

                let content = try String(contentsOf: item.path, encoding: .utf8)

                // If git modified, load diff
                if gitStatus == .modified {
                    let diff = await loadGitDiff()
                    await MainActor.run {
                        self.fileContent = content
                        self.gitDiff = diff
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.fileContent = content
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func isBinaryFile(_ url: URL) -> Bool {
        // Check common binary extensions
        let binaryExtensions = Set([
            "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp",
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "zip", "tar", "gz", "rar", "7z",
            "exe", "dll", "so", "dylib", "app",
            "mp3", "mp4", "wav", "avi", "mov", "mkv",
            "ttf", "otf", "woff", "woff2",
            "sqlite", "db"
        ])

        return binaryExtensions.contains(url.pathExtension.lowercased())
    }

    private func loadGitDiff() async -> GitDiffResult? {
        // Run git diff to get the changes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["diff", item.path.path]
        task.currentDirectoryURL = item.path.deletingLastPathComponent()

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseGitDiff(output)
            }
        } catch {
            // Ignore errors
        }

        return nil
    }

    private func parseGitDiff(_ diffOutput: String) -> GitDiffResult {
        var oldLines: [DiffLine] = []
        var newLines: [DiffLine] = []

        // Also load the current file content for the right side
        let currentContent = (try? String(contentsOf: item.path, encoding: .utf8)) ?? ""
        let currentLines = currentContent.components(separatedBy: "\n")

        // Get the committed version using git show
        let committedContent = getCommittedContent()
        let committedLines = committedContent.components(separatedBy: "\n")

        // Parse the diff to identify changed lines
        var addedNewLineNumbers = Set<Int>()
        var removedOldLineNumbers = Set<Int>()

        var oldLineNum = 0
        var newLineNum = 0

        for line in diffOutput.components(separatedBy: "\n") {
            if line.hasPrefix("@@") {
                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
                if let match = line.range(of: #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#, options: .regularExpression) {
                    let hunkInfo = String(line[match])
                    let numbers = hunkInfo.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                    if numbers.count >= 2 {
                        oldLineNum = Int(numbers[0]) ?? 1
                        newLineNum = Int(numbers[1]) ?? 1
                    }
                }
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                removedOldLineNumbers.insert(oldLineNum)
                oldLineNum += 1
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                addedNewLineNumbers.insert(newLineNum)
                newLineNum += 1
            } else if !line.hasPrefix("\\") && !line.hasPrefix("diff") && !line.hasPrefix("index") {
                oldLineNum += 1
                newLineNum += 1
            }
        }

        // Build old lines (committed version)
        for (index, line) in committedLines.enumerated() {
            let lineNum = index + 1
            let status: DiffLine.Status
            if removedOldLineNumbers.contains(lineNum) {
                status = .removed
            } else {
                status = .unchanged
            }
            oldLines.append(DiffLine(content: line, status: status))
        }

        // Build new lines (current version)
        for (index, line) in currentLines.enumerated() {
            let lineNum = index + 1
            let status: DiffLine.Status
            if addedNewLineNumbers.contains(lineNum) {
                status = .added
            } else {
                status = .unchanged
            }
            newLines.append(DiffLine(content: line, status: status))
        }

        return GitDiffResult(oldLines: oldLines, newLines: newLines)
    }

    private func getCommittedContent() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["show", "HEAD:\(item.path.lastPathComponent)"]
        task.currentDirectoryURL = item.path.deletingLastPathComponent()

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

// MARK: - Supporting Types

struct GitDiffResult {
    let oldLines: [DiffLine]
    let newLines: [DiffLine]
}

struct DiffLine: Identifiable {
    let id = UUID()
    let content: String
    let status: Status

    enum Status {
        case unchanged
        case added
        case removed
        case modified
    }
}

struct DiffLineView: View {
    let lineNumber: Int
    let content: String
    let status: DiffLine.Status

    var body: some View {
        HStack(spacing: 0) {
            Text("│ ")
                .foregroundColor(previewBorderColor)

            // Status indicator
            Text(statusSymbol)
                .foregroundColor(statusColor)
                .frame(width: 12)

            Text(String(format: "%4d", lineNumber))
                .foregroundColor(previewDimColor)
                .frame(width: 40, alignment: .trailing)
            Text(" │ ")
                .foregroundColor(previewBorderColor)
            Text(content.isEmpty ? " " : content)
                .foregroundColor(contentColor)
            Spacer(minLength: 0)
            Text(" │")
                .foregroundColor(previewBorderColor)
        }
        .frame(height: previewLineHeight)
        .background(backgroundColor)
    }

    private var statusSymbol: String {
        switch status {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        case .modified: return "~"
        }
    }

    private var statusColor: Color {
        switch status {
        case .unchanged: return .clear
        case .added: return .green
        case .removed: return .red
        case .modified: return .yellow
        }
    }

    private var contentColor: Color {
        switch status {
        case .unchanged: return .white
        case .added: return .green
        case .removed: return .red
        case .modified: return .yellow
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .unchanged: return .clear
        case .added: return Color.green.opacity(0.1)
        case .removed: return Color.red.opacity(0.1)
        case .modified: return Color.yellow.opacity(0.1)
        }
    }
}

