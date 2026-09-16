import SwiftUI
import TimeBiteUI

@main
struct TimeBiteMacApp: App {
    var body: some Scene {
        WindowGroup {
            ActivityLoopView()
                .frame(minWidth: 520, minHeight: 580)
        }
    }
}
