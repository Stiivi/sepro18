import Logging
import Foundation

/// Persistence wrapper for sepro sessions.
///
/// File hierarchy:
/// ```
/// workspace/
///     model.sepro 
///     output/
///         dots/
/// ```
public final class Workspace {
    let logger = Logger(label: "sepro.main")
    
    public let path: String
    public let modelPath: String

    init(path: String) {
        self.path = path
        // FIXME: Use URL path appending
        modelPath = path + "/model.sepro"
    }

    public func load() {
        let source: String

        do {
            source = try String(contentsOfFile: modelPath, encoding:String.Encoding.utf8)
        } catch {
            logger.error("Unable to read model '\(modelPath)'")
            exit(1)
        }
    }
}
