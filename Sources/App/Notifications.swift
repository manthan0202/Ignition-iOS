import Foundation
import UserNotifications

// Notification actions must be routed through an application-owned delegate.
// The persisted pending action survives a cold launch before AppModel is ready.
private final class IgnitionNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = IgnitionNotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "IGNITION_START_TASK",
           let id = response.notification.request.content.userInfo["taskID"] as? String,
           UUID(uuidString: id) != nil {
            UserDefaults.standard.set(id, forKey: "ignition.pendingStartTaskID")
            NotificationCenter.default.post(name: .ignitionNotificationStartFocus, object: nil)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let ignitionNotificationStartFocus = Notification.Name("ignition.notification.startFocus")
}

@MainActor
final class Notifications {
    init() {
        let center = UNUserNotificationCenter.current()
        center.delegate = IgnitionNotificationDelegate.shared
        let start = UNNotificationAction(identifier: "IGNITION_START_TASK", title: "Start focus", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "IGNITION_PLANNED_TASK", actions: [start], intentIdentifiers: [], options: [])
        ])
    }
    func authorize() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    func scheduleCompletion(session: FocusSession) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session-complete"])
        guard session.phase == .active else { return }
        let remaining = session.remainingSeconds(asOf: Date())
        guard remaining > 1 else { return }
        let message = UNMutableNotificationContent()
        message.title = "Focus block finished"
        message.body = "\(session.title) · Save where you left off."
        message.sound = .default
        message.userInfo = ["sessionID": session.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: "session-complete", content: message, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    func cancelCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session-complete"])
    }
    func scheduleReminder(for item: WorkItem) {
        let identifier = "planned-\(item.id.uuidString)"
        let rescueID = "rescue-\(item.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier, rescueID])
        guard let when = item.scheduledStart, !item.isComplete, !item.isFixed else { return }
        if when > Date() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.nextStep.isEmpty ? "It's time for your planned block." : "Next: " + item.nextStep
            content.sound = .default
            content.categoryIdentifier = "IGNITION_PLANNED_TASK"
            content.userInfo = ["taskID": item.id.uuidString]
            let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: when)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
        if UserDefaults.standard.bool(forKey: "rescueEnabled"),
           let rescue = Calendar.current.date(byAdding:.minute,value:10,to:when),
           rescue > Date() {
            let followUp = UNMutableNotificationContent()
            followUp.title = "A small start still counts"
            followUp.body = "\(item.title) · Start with two minutes when you're ready."
            followUp.sound = .default
            let rc = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:rescue)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:rescueID,content:followUp,trigger:UNCalendarNotificationTrigger(dateMatching:rc,repeats:false)))
        }
    }
    func cancelForItem(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:[
            "planned-\(id.uuidString)", "rescue-\(id.uuidString)"
        ])
    }
    func cancelRescue(taskID: UUID?) {
        guard let taskID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["rescue-\(taskID.uuidString)"])
    }
    func scheduleBreakReminder(after seconds: Int = 300) {
        let msg = UNMutableNotificationContent()
        msg.title = "Break is over"
        msg.body = "Your work is ready when you are."
        msg.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"break-complete",content:msg,trigger:UNTimeIntervalNotificationTrigger(timeInterval:Double(seconds),repeats:false)))
    }
    func cancelBreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["break-complete"])
    }
}
