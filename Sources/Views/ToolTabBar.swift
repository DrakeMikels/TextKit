import SwiftUI

struct ToolTabBar: View {
    let selectedTool: ToolKind
    let onSelect: (ToolKind) -> Void

    private let gridColumns = [
        GridItem(.adaptive(minimum: 128), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowLayout
            gridLayout
        }
    }

    private var rowLayout: some View {
        HStack(spacing: 8) {
            ForEach(ToolKind.allCases) { tool in
                toolButton(for: tool)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gridLayout: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(ToolKind.allCases) { tool in
                toolButton(for: tool)
            }
        }
    }

    private func toolButton(for tool: ToolKind) -> some View {
        Button {
            onSelect(tool)
        } label: {
            Label(tool.title, systemImage: tool.systemImage)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    tool == selectedTool
                        ? Color.accentColor.opacity(0.18)
                        : Color.secondary.opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tool.description)
    }
}
