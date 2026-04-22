import SwiftUI

struct ToolTabBar: View {
    let selectedTool: ToolKind
    let onSelect: (ToolKind) -> Void

    @Namespace private var selectionNamespace

    private let rowSpacing: CGFloat = 10
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
        .frame(height: 96)
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
        let accent = accentColor(for: tool)
        let isSelected = tool == selectedTool

        return Button {
            withAnimation(.snappy(duration: 0.22, extraBounce: 0.08)) {
                onSelect(tool)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : accent.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(accent.opacity(isSelected ? 0.22 : 0.12))
                    )

                Text(tool.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .center) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: backgroundColors(
                                        for: tool,
                                        isSelected: isSelected
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
                                isSelected ? accent.opacity(0.48) : Color.white.opacity(0.08),
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

    private func backgroundColors(for tool: ToolKind, isSelected: Bool) -> [Color] {
        let accent = accentColor(for: tool)
        if isSelected {
            return [
                accent.opacity(0.24),
                accent.opacity(0.14)
            ]
        }

        return [
            Color.white.opacity(0.06),
            accent.opacity(0.06)
        ]
    }

    private func accentColor(for tool: ToolKind) -> Color {
        switch tool {
        case .rewrite:
            Color(red: 0.33, green: 0.72, blue: 1.0)
        case .prompt:
            Color(red: 0.29, green: 0.82, blue: 0.74)
        case .extract:
            Color(red: 0.99, green: 0.74, blue: 0.38)
        case .reply:
            Color(red: 0.55, green: 0.76, blue: 0.47)
        case .reduce:
            Color(red: 0.76, green: 0.66, blue: 1.0)
        case .summarize:
            Color(red: 0.96, green: 0.53, blue: 0.67)
        }
    }
}
