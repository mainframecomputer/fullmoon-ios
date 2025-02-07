import UIKit
import BackgroundTasks

#if os(iOS)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        scheduleBackgroundTask()
        
        // Post notification to pause model loading when progress reaches 95%
        NotificationCenter.default.post(name: .modelPauseNotification, object: nil)
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Post notification so that observers can reset the Live Activity.
        NotificationCenter.default.post(name: .modelResumeNotification, object: nil)
    }
    
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.fullmoon.modeldownload")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Post notification to resume model loading if needed
        NotificationCenter.default.post(name: .modelResumeNotification, object: nil)
    }
}

extension Notification.Name {
    static let modelPauseNotification = Notification.Name("modelPauseNotification")
    static let modelResumeNotification = Notification.Name("modelResumeNotification")
    static let saveInterruptedDownload = Notification.Name("saveInterruptedDownload")
}
#endif 
