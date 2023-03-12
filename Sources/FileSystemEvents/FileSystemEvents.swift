import CoreServices
import Foundation
import Combine
import OSLog

/// A `FileSystemWatcher` watches paths for events such as file modification or directory metadata changes.
/// There are three different reporting patterns supported by `FileSystemWatcher`:
/// - For classical closure-based handling, assign a non-nil value to the `eventHandler` property
/// - For a Combine publisher, access the `eventPublisher` property
/// - For an `AsyncStream` to use with Swift structured concurrency, use the `eventStream` property
/// Events are processed in the background,
@available(macOS 10.15, *) public class FileSystemWatcher {
    
    let paths: [String]
    
    init(paths: [String]) {
        self.paths = paths
    }
    
    deinit {
        stop()
    }
    
    private var fsEventStream: FSEventStreamRef?
    private let eventQueue = DispatchQueue(label: "io.mikey.FileSystemEvents")
    
    // MARK: - Event Sources
    
    public typealias FileSystemEventHandler = (Event)->Void
    public typealias FileSystemEventStream = AsyncStream<Event>
    
    /// A closure handler, called once for each event
    public var eventHandler: FileSystemEventHandler? = nil
    
    /// Combine publisher of `FileSystemEvent` instances
    private let _eventPublisher = PassthroughSubject<Event,Never>()
    public lazy var eventPublisher: AnyPublisher<Event,Never> = { _eventPublisher.eraseToAnyPublisher() }()
    
    /// For modern Swift concurrency, an `AsyncStream` of `FileSystemWatcher.Event` instances
    public lazy var eventStream: FileSystemEventStream = FileSystemEventStream { [weak self] continuation in
        self?.streamContinuation = continuation
    }
    private var streamContinuation: FileSystemEventStream.Continuation? = nil
    
     
    // MARK: - Behavior
    
    public func start() {
        stop() // in case there was already a running stream
        
        let context = makeContext()
        let flags = makeFlags()
        let stream = makeStream(callback: callback, context: context, paths: paths, flags: flags)
        
        fsEventStream = stream
        
        // Starts the stream actually running.
        // Callback will be called periodically on the `eventQueue`.
        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }
    
    public func stop() {
        guard let fsEventStream else { return }
        FSEventStreamStop(fsEventStream)
        FSEventStreamInvalidate(fsEventStream)
        FSEventStreamRelease(fsEventStream)
        self.fsEventStream = nil
    }
    
    fileprivate func handleEvent(_ event: Event) {
        _eventPublisher.send(event)
        eventHandler?(event)
        streamContinuation?.yield(event)
    }
    
    // MARK: - Helpers
    
    private func makeFlags() -> UInt32 {
        return UInt32(
            kFSEventStreamCreateFlagWatchRoot |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes
        )
    }
    
    private func makeContext() -> FSEventStreamContext {
        return FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
    }
    
    private func makeStream(callback: FSEventStreamCallback,
                            context:  FSEventStreamContext,
                            paths: [String],
                            flags: FSEventStreamEventFlags) -> FSEventStreamRef {
        var context = context // the context argument below requires that the context struct be mutable
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,    // memory allocator
            callback,   // FSEventStreamCallback
            &context, // UnsafeMutablePointer<FSEventStreamContext>?
            paths as NSArray, // CFArray<String>
            UInt64(kFSEventStreamEventIdSinceNow), // FSEventStreamEventID to start from
            0.1, // desired latency
            flags
        ) else {
            fatalError("Failed to create event stream")
        }
        return stream
    }
        
}

@available(macOS 10.15, *) public extension FileSystemWatcher {
    /// Abstraction of an event affecting a file or directory on disk being watched by a `FileSystemWatcher`.
    /// Instances will be vended to client code; it is generally not meaningful to create them yourself.
    struct Event {
        let path: String
        let flags: FSEventStreamEventFlags
        let id: FSEventStreamEventId
    }
}

// MARK: - Global event callback

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
        FileSystemWatcher.Event(path: paths[index], flags: flags[index], id: ids[index])
    }
    
    // Unmanaged approach recommended by QtE in forums:
    // https://forums.swift.org/t/callback-in-swift/4984
    let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientInfo!).takeUnretainedValue()
    for event in events {
        watcher.handleEvent(event)
    }
}
