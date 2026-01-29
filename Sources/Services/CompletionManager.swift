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

            do {
                let response = try await APIClient.shared.fetchCompletions(
                    input: input,
                    cursorPosition: input.count,
                    cwd: cwd,
                    shell: "zsh"
                )

                // Update state (already on main actor)
                self.completions = response.completions
                self.prefixLength = response.prefixLength
                self.selectedIndex = 0
                self.isVisible = !response.completions.isEmpty
            } catch {
                // Silently fail - just hide completions
                self.dismiss()
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
