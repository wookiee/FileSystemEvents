
import Foundation
import CoreServices

@available(macOS 10.15, *) extension FileSystemObserver {
    
    /// Abstraction of an event affecting a file or directory on disk being watched by a `FileSystemObserver`.
    /// Instances will be vended to client code; it is generally not meaningful to create them yourself.
    public struct Event: Codable, Hashable, Identifiable {
        public let path: String
        public let flags: Flags
        public let id: UInt64
    }
    
}
