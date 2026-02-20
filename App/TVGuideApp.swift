// TVGuideApp.swift
// App entry point – registers the background-refresh handler and bootstraps the UI.

import SwiftUI
import BackgroundTasks

@main
struct TVGuideApp: App {

    init() {
        // Register the background-refresh task handler once at launch.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: FeedService.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(refreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Background Refresh Handler

private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
    // Re-schedule the next background refresh immediately.
    FeedService.shared.scheduleBackgroundRefresh()

    let handle = Task {
        do {
            try await FeedService.shared.update()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        handle.cancel()
        task.setTaskCompleted(success: false)
    }
}
