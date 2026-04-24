import SwiftUI

struct ToolTabBar: View {
    let selectedTool: ToolKind
    let onSelect: (ToolKind) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    private let rowSpacing: CGFloat = 8
    private let rowTools = [
        Array(ToolKind.allCases.prefix(3)),
        Array(ToolKind.allCases.dropFirst(3))
    ]

    var body: some View {
        GeometryReader { geometry in
            let buttonWidth = max(120, floor((geometry.size.width - (rowSpacing * 2)) / 3))

            VStack(spacing: rowSpacing) {
                toolRow(rowTools[0], buttonWidth: buttonWidth, centered: false)
                toolRow(rowTools[1], buttonWidth: buttonWidth, centered: rowTools[1].count < 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 84)
    }

    private func toolRow(_ tools: [ToolKind], buttonWidth: CGFloat, centered: Bool) -> some View {
        HStack(spacing: rowSpacing) {
            if centered {
                Spacer(minLength: 0)
            }

            ForEach(tools) { tool in
                toolButton(for: tool)
                    .frame(width: buttonWidth)
            }

            if centered {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private func toolButton(for tool: ToolKind) -> some View {
        let accent = ToolTintPalette.accent(for: tool)
        let isSelected = tool == selectedTool

        return Button {
            withAnimation(.snappy(duration: 0.22, extraBounce: 0.08)) {
                onSelect(tool)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : accent.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(accent.opacity(isSelected ? 0.24 : 0.14))
                    )

                Text(tool.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .center) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: TextKitVisualStyle.toolSurfaceColors(
                                        accent: accent,
                                        isSelected: isSelected,
                                        colorScheme: colorScheme
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accent.opacity(0.12))
                                .matchedGeometryEffect(id: "selectedToolFill", in: selectionNamespace)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? accent.opacity(colorScheme == .light ? 0.56 : 0.48)
                                    : TextKitVisualStyle.cardStroke(for: colorScheme),
                                lineWidth: isSelected ? 1.2 : 0.9
                            )
                    }
                    .shadow(
                        color: isSelected ? accent.opacity(0.18) : Color.black.opacity(0.10),
                        radius: isSelected ? 14 : 8,
                        y: isSelected ? 6 : 4
                    )
            }
        }
        .buttonStyle(.plain)
        .help(tool.description)
    }
}
