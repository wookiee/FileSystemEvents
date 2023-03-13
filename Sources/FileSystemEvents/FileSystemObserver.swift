import CoreServices
import Foundation
import Combine

/// A `FileSystemObserver` watches paths for events such as file modification or directory metadata changes.
/// There are three different reporting patterns supported by `FileSystemObserver`:
/// - For classical closure-based handling, assign a non-nil value to the `eventHandler` property
/// - For a Combine publisher, access the `eventPublisher` property
/// - For an `AsyncStream` to use with Swift structured concurrency, use the `eventStream` property
/// Events are processed in the background,
@available(macOS 10.15, iOS 13, *) public class FileSystemObserver {

    public init() { }
    
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
    
    public func start(paths: [String], flags: FSEventStreamEventFlags? = nil) {
        stop() // in case there was already a running stream
        
        let context = makeContext()
        let flags = flags ?? makeFlags()
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
    
    // MARK: - Private Helpers
    
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
    
    private func makeStream(
                            callback: FSEventStreamCallback,
                            context:  FSEventStreamContext,
                            paths: [String],
                            flags: FSEventStreamEventFlags) -> FSEventStreamRef {
        var context = context // the context argument below requires that the context struct be mutable
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,    // memory allocator
            callback,   // FSEventStreamCallback
            &context, // UnsafeMutablePointer<FSEventStreamContext>?
            paths as CFArray, // CFArray of CFStrings
            UInt64(kFSEventStreamEventIdSinceNow), // FSEventStreamEventID to start from
            0.1, // desired latency
            flags
        ) else {
            fatalError("Failed to create event stream")
        }
        return stream
    }
        
}

// MARK: - Global event callback

/// Callback to be called repeatedly by Apple when events are ready for processing.
/// See documentation for the `FSEventStreamCallback` function typealias.
@available(macOS 10.15, iOS 13, *)
private func callback(streamRef: ConstFSEventStreamRef,
                          clientInfo: UnsafeMutableRawPointer?,
                          eventCount: Int,
                          eventPaths: UnsafeMutableRawPointer,
                          eventFlags: UnsafePointer<FSEventStreamEventFlags>,
                          eventIDs: UnsafePointer<FSEventStreamEventId>) {
    
    let paths = unsafeBitCast(eventPaths, to: NSArray.self)
    
    var flags = [FSEventStreamEventFlags]()
    for i in 0 ..< eventCount {
        flags.append(eventFlags.pointee.advanced(by: i) as FSEventStreamEventFlags)
    }
    
    var ids = [FSEventStreamEventId]()
    for i in 0 ..< eventCount {
        ids.append(eventIDs.pointee.advanced(by: i) as FSEventStreamEventId)
    }

    let events = (0 ..< eventCount).map { index in
        FileSystemObserver.Event(
            path: paths[index] as! String,
            flags: FileSystemObserver.Event.Flags(rawValue: flags[index]),
            id: ids[index]
        )
    }
    
    // Unmanaged approach recommended by Quinn in the forums:
    // https://forums.swift.org/t/callback-in-swift/4984
    let watcher = Unmanaged<FileSystemObserver>.fromOpaque(clientInfo!).takeUnretainedValue()
    for event in events {
        watcher.handleEvent(event)
    }
}
