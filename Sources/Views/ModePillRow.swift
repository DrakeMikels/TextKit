import SwiftUI

struct ModePillRow: View {
    let modes: [ToolMode]
    let selectedMode: ToolMode
    let onSelect: (ToolMode) -> Void

    var body: some View {
        let accent = ToolTintPalette.accent(for: selectedMode.tool)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    Button(mode.title) {
                        onSelect(mode)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(mode == selectedMode ? .primary : accent.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: mode == selectedMode
                                                ? [accent.opacity(0.24), accent.opacity(0.14)]
                                                : [accent.opacity(0.10), accent.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        mode == selectedMode ? accent.opacity(0.48) : accent.opacity(0.18),
                                        lineWidth: mode == selectedMode ? 1.1 : 0.8
                                    )
                            }
                    }
                }
            }
        }
    }
}
