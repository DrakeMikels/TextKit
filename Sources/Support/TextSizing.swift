import AppKit
import Foundation

enum TextSizing {
    static func editorHeight(
        for text: String,
        width: CGFloat = 420,
        font: NSFont = .preferredFont(forTextStyle: .body),
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> CGFloat {
        let sample = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : text
        let bounds = (sample as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        let paddedHeight = ceil(bounds.height) + 32
        return min(max(paddedHeight, minHeight), maxHeight)
    }
}
