import SwiftUI

enum ToolTintPalette {
    static func accent(for tool: ToolKind) -> Color {
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
