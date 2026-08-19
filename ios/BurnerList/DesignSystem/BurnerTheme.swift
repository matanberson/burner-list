import SwiftUI

enum BurnerTheme {
    static let paper = BurnerTokens.paper
    static let fieldSurface = BurnerTokens.fieldSurface
    static let border = BurnerTokens.border
    static let borderStrong = BurnerTokens.borderStrong
    static let textDark = BurnerTokens.textDark
    static let textMid = BurnerTokens.textMid
    static let textSoft = BurnerTokens.textSoft
    static let textFaint = BurnerTokens.textFaint
    static let danger = BurnerTokens.danger

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct BurnerFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(BurnerTheme.body(15))
            .foregroundStyle(BurnerTheme.textDark)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(BurnerTheme.fieldSurface)
            .overlay(
                RoundedRectangle(cornerRadius: BurnerTokens.radiusMD)
                    .stroke(BurnerTheme.border, lineWidth: 1)
            )
    }
}

struct BurnerDateHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: BurnerTokens.space1) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(BurnerTheme.textDark)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(BurnerTheme.textSoft)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct BurnerScopeTabLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
    }
}

private struct BurnerDateHeaderPreview: PreviewProvider {
    static var previews: some View {
        BurnerDateHeader(title: "Today's List", subtitle: "Tuesday, August 18, 2026")
            .padding()
            .background(BurnerTheme.paper)
            .previewDisplayName("Date header")
    }
}

struct BurnerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BurnerTheme.body(14, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(BurnerTheme.textMid.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: BurnerTokens.radiusMD))
    }
}
