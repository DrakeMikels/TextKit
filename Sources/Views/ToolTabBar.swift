import SwiftUI

struct ToolTabBar: View {
    let selectedTool: ToolKind
    let onSelect: (ToolKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ToolKind.allCases) { tool in
                Button {
                    onSelect(tool)
                } label: {
                    Label(tool.title, systemImage: tool.systemImage)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(tool == selectedTool ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tool.description)
            }
        }
    }
}
