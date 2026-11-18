import Foundation
import SwiftUI
import UserNotifications

struct PomodoroNotificationPlan: Equatable {
    /// A timer reminder matters the moment it arrives, so it may break through a Focus and the
    /// scheduled summary. That takes the Time Sensitive Notifications capability, which only a paid
    /// developer team can sign. Without it iOS delivers the reminders as ordinary notifications.
    static let interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive

    let identifier: String
    let title: String
    let body: String
    let timeInterval: TimeInterval
    let soundResource: ReminderSoundResource?

    var soundName: String? {
        soundResource?.notificationSoundName
    }

    var request: UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = Self.interruptionLevel
        if let soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

/// What a reminder says.
struct PomodoroNotificationMessage: Equatable {
    let title: String
    let body: String

    /// One step ended and the next has already started: what ended, then what runs now and for how long.
    static func boundary(ending step: SessionStep, starting next: SessionStep, targetRounds: Int) -> Self {
        let title = step.phase == .focus ? "Focus complete" : "Break over"
        let duration = "\(Int((next.plannedDuration / 60).rounded())) min"

        switch next.phase {
        case .focus:
            return Self(title: title, body: "Focus round \(next.roundNumber) of \(targetRounds), \(duration).")
        case .shortBreak:
            return Self(title: title, body: "Short break, \(duration).")
        case .longBreak:
            // The long break follows the final round. A one-round session has no earlier round to
            // set the last one apart from.
            let lastRoundNote = targetRounds > 1 ? "That was the last round. " : ""
            return Self(title: title, body: "\(lastRoundNote)Long break, \(duration).")
        }
    }

    /// The whole session ended. The figures read like the summary the app shows.
    static func sessionComplete(_ statistics: SessionStatistics, targetRounds: Int) -> Self {
        let focus = FocusCompletionFormatting.durationText(statistics.focusTime)
        let blocks = FocusCompletionFormatting.focusBlocksText(
            completed: statistics.completedFocusCount,
            targetRounds: targetRounds
        )
        return Self(title: "Session complete", body: "\(focus) focused · \(blocks)")
    }
}

extension NotificationPermission {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized, .provisional, .ephemeral:
            self = .allowed
        @unknown default:
            self = .allowed
        }
    }
}

extension PomodoroStore {
    /// Asks iOS once, while notifications are on in the app and iOS hasn't been asked yet. Called on the
    /// first Start and when Notifications is turned on, so the prompt arrives when its reason is visible.
    func requestNotificationPermissionsIfNeeded() {
        guard !Self.isUITestingLaunch,
              settings.notificationsEnabled,
              notificationPermission == .unknown || notificationPermission == .notDetermined else {
            return
        }

        Task {
            // The app shows no badge, so it doesn't ask for one.
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await updateNotificationPermission()
            // Reminders for a session that started before the answer.
            syncNotifications()
        }
    }

    /// Reads what iOS allows now. Called at launch and whenever the app returns to the foreground,
    /// since people change it in iOS Settings.
    func refreshNotificationPermission() {
        Task {
            await updateNotificationPermission()
        }
    }

    func updateNotificationPermission() async {
        let permission: NotificationPermission
        if Self.isUITestingLaunch {
            permission = Self.uiTestingNotificationPermission ?? .notDetermined
        } else {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            permission = NotificationPermission(status)
        }

        // Publishing redraws every view that watches the store, the Focus bubble included.
        if notificationPermission != permission {
            notificationPermission = permission
        }
    }

    /// Replaces every pending reminder with the ones the session needs now.
    func syncNotifications() {
        notificationScheduler.replacePendingRequests(with: notificationPlans(now: .now).map(\.request))
    }

    /// Once the app is open it shows where the timer stands, so reminders already delivered are out
    /// of date.
    func clearDeliveredNotifications() {
        notificationScheduler.removeDeliveredNotifications()
    }

    /// While the app is open and active, its own sound and haptic mark a boundary, so a reminder that
    /// arrives then stays hidden. Behind Control Center or the app switcher the app gives no response
    /// of its own, so the reminder shows as it would in the background.
    var notificationPresentationOptions: UNNotificationPresentationOptions {
        currentScenePhase == .active ? [] : [.banner, .list, .sound]
    }

    /// Every reminder is about the timer, so opening one shows Focus.
    func showFocusForOpenedNotification() {
        selectedTab = .focus
    }

    func notificationPlans(now: Date = .now) -> [PomodoroNotificationPlan] {
        guard settings.notificationsEnabled,
              let session = activeSession,
              session.runState == .running,
              let firstBoundary = session.targetEndDate,
              session.currentStep != nil else {
            return []
        }

        var boundaryDate = firstBoundary
        var plans: [PomodoroNotificationPlan] = []

        for index in session.currentStepIndex..<session.steps.count {
            let step = session.steps[index]
            if index > session.currentStepIndex {
                boundaryDate = boundaryDate.addingTimeInterval(step.plannedDuration)
            }

            let nextStepIndex = index + 1
            let nextStep = session.steps.indices.contains(nextStepIndex) ? session.steps[nextStepIndex] : nil

            let message: PomodoroNotificationMessage
            let soundResource: ReminderSoundResource
            if let nextStep {
                message = .boundary(ending: step, starting: nextStep, targetRounds: session.targetRounds)
                soundResource = .nextPhaseWhoosh
            } else {
                message = .sessionComplete(
                    Self.projectedStatistics(of: session, endingAt: boundaryDate),
                    targetRounds: session.targetRounds
                )
                soundResource = .sessionCompleteThud
            }

            plans.append(PomodoroNotificationPlan(
                identifier: notificationIdentifier(for: session.id, stepIndex: index),
                title: message.title,
                body: message.body,
                timeInterval: max(1, boundaryDate.timeIntervalSince(now)),
                soundResource: settings.soundEnabled ? soundResource : nil
            ))
        }

        return plans
    }
}

private extension PomodoroStore {
    func notificationIdentifier(for sessionID: UUID, stepIndex: Int) -> String {
        "vibe.\(sessionID.uuidString).\(stepIndex)"
    }

    /// What the session will have recorded if it runs to its end unchanged. Any change reschedules
    /// the reminders, so the summary in the last one stays true. It runs the engine rather than adding
    /// up durations, so it counts blocks the way the app's summary does.
    static func projectedStatistics(of session: SessionSnapshot, endingAt endDate: Date) -> SessionStatistics {
        var projected = session
        _ = PomodoroEngine.reconcile(session: &projected, now: endDate)
        return projected.statistics(now: endDate)
    }
}
