import CoreServices
import Foundation
import Combine
import OSLog

@available(macOS 10.15, *)
public struct FileSystemEvent {
    let path: String
    let flags: FSEventStreamEventFlags
    let id: FSEventStreamEventId
}

@available(macOS 10.15, *)
public class FileSystemWatcher {
    typealias FileSystemEventHandler = (FileSystemEvent)->Void
    typealias FileSystemEventStream = AsyncStream<FileSystemEvent>
    
    let paths: [String]
    var eventHandler: FileSystemEventHandler? = nil
    
    /// Combine publisher of `FileSystemEvent` instances.
    private let _eventPublisher = PassthroughSubject<FileSystemEvent,Never>()
    var eventPublisher: AnyPublisher<FileSystemEvent,Never> { _eventPublisher.eraseToAnyPublisher() }
    
    private var streamContinuation: FileSystemEventStream.Continuation? = nil
    /// `AsyncStream` of `FileSystemEvent` instances.
    lazy var eventStream: FileSystemEventStream = FileSystemEventStream { [weak self] continuation in
        self?.streamContinuation = continuation
    }
    
    init(paths: [String], handler: FileSystemEventHandler? = nil) {
        self.paths = paths
    }
    
    private var fsEventStream: FSEventStreamRef?
    private let eventQueue = DispatchQueue(label: "io.mikey.FileSystemEvents")
    
     

    // MARK: - Starting and Stopping
    
    func start(runLoop: RunLoop? = nil) {
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let configurationFlags = UInt32(
            kFSEventStreamCreateFlagWatchRoot |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes
        )
        
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,    // memory allocator
            callback,   // FSEventStreamCallback
            &context, // UnsafeMutablePointer<FSEventStreamContext>?
            paths as NSArray, // CFArray<String>
            UInt64(kFSEventStreamEventIdSinceNow), // FSEventStreamEventID to start from
            0.1, // desired latency
            configurationFlags
        ) else {
            fatalError("Failed to create event stream")
        }
        
        fsEventStream = stream
        // Starts the stream actually running.
        // Callback will be called periodically on the `eventQueue`.
        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }
    
    func stop() {
        guard let fsEventStream else { return }
        FSEventStreamStop(fsEventStream)
        FSEventStreamInvalidate(fsEventStream)
        FSEventStreamRelease(fsEventStream)
        self.fsEventStream = nil
    }
    
    // MARK: - Combine
    
    fileprivate func handleEvent(_ event: FileSystemEvent) {
        _eventPublisher.send(event)
        eventHandler?(event)
        streamContinuation?.yield(event)
    }
        
}

// MARK: - Global

@available(macOS 10.15, *)
private var watchers = [UUID: FileSystemWatcher]()

/// Callback to be called repeatedly by Apple when events are ready for processing.
/// See documentation for the `FSEventStreamCallback` function typealias.
@available(macOS 10.15, *)
private func callback(streamRef: ConstFSEventStreamRef,
                          clientInfo: UnsafeMutableRawPointer?,
                          eventCount: Int,
                          eventPaths: UnsafeMutableRawPointer,
                          eventFlags: UnsafePointer<FSEventStreamEventFlags>,
                          eventIDs: UnsafePointer<FSEventStreamEventId>) {
    
    let paths = eventPaths.load(as: [String].self)
    
    var flags = [FSEventStreamEventFlags]()
    eventFlags.withMemoryRebound(to: FSEventStreamEventFlags.self, capacity: eventCount) { pointer in
        flags.append(pointer.pointee)
    }
    
    var ids = [FSEventStreamEventId]()
    eventIDs.withMemoryRebound(to: FSEventStreamEventId.self, capacity: eventCount) { pointer in
        ids.append(pointer.pointee)
    }

    let events = (0 ..< eventCount).map { index in
        FileSystemEvent(path: paths[index], flags: flags[index], id: ids[index])
    }
    
    // Unmanaged approach recommended by QtE in forums:
    // https://forums.swift.org/t/callback-in-swift/4984
    let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientInfo!).takeUnretainedValue()
    for event in events {
        watcher.handleEvent(event)
    }
}
