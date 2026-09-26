import SwiftUI

/// Environment flag set during headless PNG snapshot rendering. `ImageRenderer`
/// does not render `ScrollView` content, so panels fall back to a plain stack.
private struct SnapshotModeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var snapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}

/// Standard vertical layout for a detail panel: a padded stack of cards, scrollable
/// in the live app and non-scrolling (renderable) during snapshots.
struct PanelScroll<Content: View>: View {
    @Environment(\.snapshotMode) private var snapshotMode
    @ViewBuilder var content: () -> Content

    var body: some View {
        let stack = VStack(spacing: Theme.gap) { content() }
            .padding(Theme.gap)
        if snapshotMode {
            GeometryReader { geo in
                stack.frame(width: geo.size.width)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: geo.size.height, alignment: .top)
                    .clipped()
            }
        } else {
            ScrollView { stack }
        }
    }
}
