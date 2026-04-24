import SwiftUI

struct ModePillRow: View {
    let modes: [ToolMode]
    let selectedMode: ToolMode
    let onSelect: (ToolMode) -> Void

    @Environment(\.colorScheme) private var colorScheme

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
                                            colors: TextKitVisualStyle.modeSurfaceColors(
                                                accent: accent,
                                                isSelected: mode == selectedMode,
                                                colorScheme: colorScheme
                                            ),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        mode == selectedMode
                                            ? accent.opacity(colorScheme == .light ? 0.56 : 0.52)
                                            : accent.opacity(colorScheme == .light ? 0.28 : 0.24),
                                        lineWidth: mode == selectedMode ? 1.1 : 0.8
                                    )
                            }
                    }
                }
            }
        }
    }
}
