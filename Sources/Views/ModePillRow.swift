import SwiftUI

struct ModePillRow: View {
    let modes: [ToolMode]
    let selectedMode: ToolMode
    let onSelect: (ToolMode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    Button(mode.title) {
                        onSelect(mode)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(mode == selectedMode ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
