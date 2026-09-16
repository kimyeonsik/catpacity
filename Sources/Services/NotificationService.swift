import Foundation
import UserNotifications

public class NotificationService {
    public static let shared = NotificationService()
    
    private var didNotify80 = false
    private var didNotify95 = false
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    public func checkAndNotify(usedPercent: Double) {
        let enabled = UserDefaults.standard.bool(forKey: "catpacity_notify_on_high_usage")
        guard enabled else { return }
        
        let remainingPercent = max(0.0, 100.0 - usedPercent)
        if remainingPercent <= 5.0 && !didNotify95 {
            sendNotification(
                title: "Catpacity: 고양이가 완전히 방전되었어요! 🫠",
                body: "잔여량이 \(Int(remainingPercent))% 남았습니다. 곧 한도에 도달하므로 리셋 시간을 확인하세요."
            )
            didNotify95 = true
        } else if remainingPercent <= 20.0 && !didNotify80 {
            sendNotification(
                title: "Catpacity: 고양이가 축 늘어지고 있어요... 🙀",
                body: "잔여량이 \(Int(remainingPercent))%밖에 남지 않았습니다! 작업을 아껴주세요."
            )
            didNotify80 = true
        } else if remainingPercent > 20.0 {
            // Reset notification state when quota recovers or resets
            didNotify80 = false
            didNotify95 = false
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}
