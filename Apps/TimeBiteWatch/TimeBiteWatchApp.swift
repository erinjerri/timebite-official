import SwiftUI
import TimeBiteCore
import TimeBiteUI

@main
struct TimeBiteWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchCurrentActionView() }
    }
}

private struct WatchCurrentActionView: View {
    @StateObject private var controller = ActivityLoopController()

    var body: some View {
        ScrollView {
            if let session = controller.currentSession, let action = controller.currentAction {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    VStack(spacing: 8) {
                        Text(action.title).font(.headline)
                        ActivityRingView(progress: session.ringProgress(at: timeline.date),
                                         label: elapsedLabel(session.elapsed(at: timeline.date)))
                            .frame(width: 110, height: 110)
                        if session.status == .running {
                            Button("Pause") { controller.pause() }
                        } else {
                            Button("Resume") { controller.resume() }
                        }
                        Button("Complete") { controller.complete() }
                    }
                }
            } else {
                Text("No current action")
            }
        }
    }

    private func elapsedLabel(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
