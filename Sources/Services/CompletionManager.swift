import Foundation
import Observation

/// Manages completion state and requests
@MainActor
@Observable
class CompletionManager {
    var completions: [Completion] = []
    var selectedIndex: Int = 0
    var isVisible: Bool = false
    var prefixLength: Int = 0

    private var debounceTask: Task<Void, Never>?

    /// Request completions with debouncing
    /// - Parameters:
    ///   - input: Current command line input
    ///   - cwd: Current working directory
    func requestCompletions(input: String, cwd: String) {
        // Cancel any pending request
        debounceTask?.cancel()

        // Don't show completions for empty input
        guard !input.isEmpty else {
            dismiss()
            return
        }

        // Create new debounced task
        debounceTask = Task {
            // Wait 100ms before making the request
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            // Get history completions first (local, fast)
            let historyEntries = HistoryService.shared.getMatchingHistory(prefix: input, limit: 5)
            let historyCompletions = historyEntries.map { entry in
                Completion(
                    text: entry,
                    type: "history",
                    description: "From shell history",
                    insertText: entry,
                    score: 1.0  // High score for history
                )
            }

            do {
                let response = try await APIClient.shared.fetchCompletions(
                    input: input,
                    cursorPosition: input.count,
                    cwd: cwd,
                    shell: "zsh"
                )

                // Merge: history first, then API completions
                var allCompletions = historyCompletions

                // Add API completions that aren't duplicates of history
                let historyTexts = Set(historyEntries)
                for completion in response.completions {
                    if !historyTexts.contains(completion.insertText) {
                        allCompletions.append(completion)
                    }
                }

                // Update state (already on main actor)
                self.completions = allCompletions
                // For history completions, we replace the entire input
                // Use the full input length if we have history, otherwise use API's prefix
                self.prefixLength = !historyCompletions.isEmpty ? input.count : response.prefixLength
                self.selectedIndex = 0
                self.isVisible = !allCompletions.isEmpty
            } catch {
                // API failed but we might still have history completions
                if !historyCompletions.isEmpty {
                    self.completions = historyCompletions
                    self.prefixLength = input.count
                    self.selectedIndex = 0
                    self.isVisible = true
                } else {
                    self.dismiss()
                }
            }
        }
    }

    /// Select next completion (wrap around)
    func selectNext() {
        guard !completions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % completions.count
    }

    /// Select previous completion (wrap around)
    func selectPrevious() {
        guard !completions.isEmpty else { return }
        selectedIndex = selectedIndex == 0 ? completions.count - 1 : selectedIndex - 1
    }

    /// Get the currently selected completion
    var selectedCompletion: Completion? {
        guard selectedIndex >= 0 && selectedIndex < completions.count else {
            return nil
        }
        return completions[selectedIndex]
    }

    /// Hide and clear completions
    func dismiss() {
        isVisible = false
        completions = []
        selectedIndex = 0
        prefixLength = 0
        debounceTask?.cancel()
        debounceTask = nil
    }
}
