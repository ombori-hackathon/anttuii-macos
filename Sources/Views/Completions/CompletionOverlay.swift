import SwiftUI

/// Overlay that displays completion suggestions
struct CompletionOverlay: View {
    let completions: [Completion]
    let selectedIndex: Int
    let onSelect: (Completion) -> Void

    var body: some View {
        if !completions.isEmpty {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(completions.enumerated()), id: \.element.id) { index, completion in
                                CompletionRow(
                                    completion: completion,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(completion)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                    }
                    .frame(maxHeight: 280)
                    .onChange(of: selectedIndex) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                // Navigation hints
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        KeyHint(key: "Tab")
                        Text("navigate")
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyHint(key: "↵")
                        Text("select")
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyHint(key: "Esc")
                        Text("close")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
    }
}

struct KeyHint: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}
