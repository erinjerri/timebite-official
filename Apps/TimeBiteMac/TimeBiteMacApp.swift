import SwiftUI
import TimeBiteUI

@main
struct TimeBiteMacApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ActivityLoopView().tabItem { Label("Local Actions", systemImage: "bolt") }
                CompanionDashboardView().tabItem { Label("iPhone Companion", systemImage: "iphone") }
            }.frame(minWidth: 520, minHeight: 680)
        }
    }
}
