#if canImport(ActivityKit)
import ActivityKit
import Foundation

public struct ModelDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        
        public init(progress: Double) {
            self.progress = progress
        }
    }
    
    public var modelName: String
    
    public init(modelName: String) {
        self.modelName = modelName
    }
} 
#endif 