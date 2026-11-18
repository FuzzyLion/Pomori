import Foundation
import UserNotifications

/// The store's link to the system notification center. It schedules the timer reminders and passes
/// on what the system reports back about them.
@MainActor
protocol ReminderNotificationScheduling: AnyObject {
    /// Lets the store that owns the scheduler hear about reminders that arrive while the app is open
    /// and about reminders someone opens.
    func attach(to store: PomodoroStore)
    /// Replaces every pending reminder.
    func replacePendingRequests(with requests: [UNNotificationRequest])
    func removeDeliveredNotifications()
}

@MainActor
final class ReminderNotificationScheduler: NSObject, ReminderNotificationScheduling {
    private weak var store: PomodoroStore?

    func attach(to store: PomodoroStore) {
        self.store = store
        // The center keeps only a weak reference. The store keeps the scheduler.
        UNUserNotificationCenter.current().delegate = self
    }

    func replacePendingRequests(with requests: [UNNotificationRequest]) {
        let center = UNUserNotificationCenter.current()
        // The app schedules nothing but its timer reminders, so clearing all of them also drops the
        // ones a session left behind after it stopped existing. Removing only the current session's
        // let those fire later.
        center.removeAllPendingNotificationRequests()
        for request in requests {
            center.add(request, withCompletionHandler: nil)
        }
    }

    func removeDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension ReminderNotificationScheduler: UNUserNotificationCenterDelegate {
    // These use the completion-handler forms and call the handler on the main queue themselves.
    // The async forms returned on a background thread, and UIKit asserts when the handler for an
    // opened notification runs off the main thread, so a tap on a reminder aborted the app.

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async {
            let options = MainActor.assumeIsolated {
                self.store?.notificationPresentationOptions ?? []
            }
            completionHandler(options)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let opensApp = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        DispatchQueue.main.async {
            if opensApp {
                MainActor.assumeIsolated {
                    self.store?.showFocusForOpenedNotification()
                }
            }
            completionHandler()
        }
    }
}
