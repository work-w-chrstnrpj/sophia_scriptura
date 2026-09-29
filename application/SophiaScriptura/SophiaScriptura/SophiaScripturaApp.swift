import SwiftUI

/// App entry point for Sophia Scriptura.
///
/// The composition root supplies bundled Scripture and local reader state through RootTabView.
@main
struct SophiaScripturaApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CanvasMemoryProbe.isEnabled {
                NavigationStack { CanvasExperimentView() }
            } else {
                RootTabView()
            }
            #else
            RootTabView()
            #endif
        }
    }
}
