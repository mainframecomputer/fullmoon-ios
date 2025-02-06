import ActivityKit
import Foundation

struct ModelDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties
        var progress: Double
        var error: String?  // Add error state
        
        public init(progress: Double, error: String? = nil) {
            self.progress = progress
            self.error = error
        }
    }

    // Fixed non-changing properties
    var modelName: String
}
