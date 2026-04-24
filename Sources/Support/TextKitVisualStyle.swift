import SwiftUI

enum TextKitVisualStyle {
    static func panelGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color(red: 0.78, green: 0.92, blue: 0.91).opacity(0.22),
                    Color(red: 0.72, green: 0.82, blue: 0.88).opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.035),
                Color(red: 0.05, green: 0.18, blue: 0.16).opacity(0.24),
                Color.black.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.52),
                    Color(red: 0.90, green: 0.96, blue: 0.95).opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.055),
                Color.white.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func panelStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.16) : Color.white.opacity(0.08)
    }

    static func cardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.07)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.16) : Color.black.opacity(0.30)
    }

    static func toolSurfaceColors(
        accent: Color,
        isSelected: Bool,
        colorScheme: ColorScheme
    ) -> [Color] {
        if colorScheme == .light {
            return isSelected
                ? [accent.opacity(0.34), Color.white.opacity(0.28)]
                : [Color.white.opacity(0.42), accent.opacity(0.07)]
        }

        return isSelected
            ? [accent.opacity(0.24), accent.opacity(0.14)]
            : [Color.white.opacity(0.06), accent.opacity(0.06)]
    }

    static func modeSurfaceColors(
        accent: Color,
        isSelected: Bool,
        colorScheme: ColorScheme
    ) -> [Color] {
        if colorScheme == .light {
            return isSelected
                ? [accent.opacity(0.30), Color.white.opacity(0.34)]
                : [Color.white.opacity(0.34), accent.opacity(0.10)]
        }

        return isSelected
            ? [accent.opacity(0.24), accent.opacity(0.14)]
            : [accent.opacity(0.10), accent.opacity(0.05)]
    }
}

struct TextKitPanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(TextKitVisualStyle.panelGradient(for: colorScheme))
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(colorScheme == .light ? 0.22 : 0.06))
                    .frame(width: 180, height: 180)
                    .blur(radius: 42)
                    .offset(x: -72, y: -88)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(TextKitVisualStyle.panelStroke(for: colorScheme), lineWidth: 0.8)
            }
            .shadow(color: TextKitVisualStyle.shadow(for: colorScheme), radius: 26, y: 18)
    }
}

struct TextKitGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            configuration.content
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TextKitVisualStyle.cardGradient(for: colorScheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(TextKitVisualStyle.cardStroke(for: colorScheme), lineWidth: 0.7)
                }
        }
    }
}

struct TextKitHeaderIcon: View {
    let systemName: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 30, height: 28)
            .foregroundStyle(.secondary)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TextKitVisualStyle.cardGradient(for: colorScheme))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(TextKitVisualStyle.cardStroke(for: colorScheme), lineWidth: 0.7)
                    }
            }
    }
}

struct TextKitActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.65))
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(TextKitVisualStyle.cardGradient(for: colorScheme))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(TextKitVisualStyle.cardStroke(for: colorScheme), lineWidth: 0.7)
                    }
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
