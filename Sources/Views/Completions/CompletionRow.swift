import SwiftUI

/// A single row in the completion list
struct CompletionRow: View {
    let completion: Completion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon based on completion type
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 18)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                // Main text
                Text(completion.text)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(.primary)

                // Description if available
                if let description = completion.description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Return icon when selected
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch completion.type {
        case "command":
            return "terminal"
        case "option":
            return "minus"
        case "subcommand":
            return "chevron.right"
        case "argument":
            return "text.cursor"
        case "file":
            return "doc"
        case "directory":
            return "folder"
        default:
            return "chevron.right"
        }
    }

    private var iconColor: Color {
        switch completion.type {
        case "command":
            return .blue
        case "option":
            return .purple
        case "subcommand":
            return .green
        case "argument":
            return .orange
        case "file":
            return .gray
        case "directory":
            return .cyan
        default:
            return .green
        }
    }
}
