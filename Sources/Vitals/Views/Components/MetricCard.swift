import SwiftUI

/// A translucent rounded surface with a subtle top accent glow, used to group
/// content. Optional title row with an accent dot.
struct MetricCard<Content: View>: View {
    var title: String? = nil
    var accent: Accent? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || trailing != nil {
                HStack(spacing: 8) {
                    if let accent {
                        Circle()
                            .fill(accent.end)
                            .frame(width: 7, height: 7)

                    }
                    if let title {
                        Text(title)
                            .font(Theme.label(13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)

                    }
                    Spacer(minLength: 0)
                    if let trailing { trailing }
                }
            }
            content()
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(LinearGradient(colors: [Theme.card, Theme.bgElevated], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1)
                )
        )
    }
}

/// A big headline number with a caption, e.g. "47%" over "Utilization".
struct Headline: View {
    let value: String
    let caption: String
    var accent: Accent? = nil
    var size: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.number(size, weight: .bold))
                .foregroundStyle(
                    accent.map { AnyShapeStyle($0.horizontal) } ?? AnyShapeStyle(Theme.text)
                )
                .contentTransition(.numericText())
            Text(caption)
                .font(Theme.label(12))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
    }
}
