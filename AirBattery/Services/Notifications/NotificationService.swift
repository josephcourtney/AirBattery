import AppKit
import Foundation
import UserNotifications

@MainActor
func createAlert(level: NSAlert.Style = .warning, title: String, message: String, button1: String, button2: String = "") -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title.local
    alert.informativeText = message.local
    alert.addButton(withTitle: button1.local)
    if button2 != "" { alert.addButton(withTitle: button2.local) }
    alert.alertStyle = level
    return alert
}

func registerNotificationCategory() {
    let delayAction = UNNotificationAction(
        identifier: "DELAY_30_MIN",
        title: "Snooze for 30 minutes".local,
        options: []
    )

    let category = UNNotificationCategory(
        identifier: "DELAY_CATEGORY",
        actions: [delayAction],
        intentIdentifiers: [],
        options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([category])
}

func createNotification(title: String, message: String, alertSound: Bool = true, interval: TimeInterval = 2, delay: Bool = false, info: String = "") {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.sound = alertSound ? UNNotificationSound.default : nil
    if delay { content.categoryIdentifier = "DELAY_CATEGORY" }
    content.userInfo = ["customInfo": info]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Notification failed to send：\(error.localizedDescription)")
        }
    }
}
