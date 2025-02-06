import UIKit
import BackgroundTasks

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background task handlers before app finishes launching
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.fullmoon.modeldownload", using: .main) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            
            bgTask.expirationHandler = {
                bgTask.setTaskCompleted(success: false)
            }
            
            // Set up a task to handle background download continuation
            Task {
                do {
                    // Keep the background task running until download completes
                    try await Task.sleep(for: .seconds(30)) // Maximum background time
                    bgTask.setTaskCompleted(success: true)
                } catch {
                    bgTask.setTaskCompleted(success: false)
                }
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
#endif 