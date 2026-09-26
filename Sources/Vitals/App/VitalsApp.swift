import SwiftUI

/// The SwiftUI app: a main dashboard window plus a live menu-bar extra.
struct VitalsApp: App {
    @StateObject private var engine = MetricsEngine()

    var body: some Scene {
        Window("Vitals", id: "main") {
            DashboardView()
                .environmentObject(engine)
                .frame(minWidth: 1020, minHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1220, height: 900)

        MenuBarExtra {
            MenuBarPanel(engine: engine)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
