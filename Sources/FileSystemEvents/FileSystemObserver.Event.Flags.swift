
import Foundation
import CoreServices

@available(macOS 10.15, *) extension FileSystemObserver.Event {
    
    /// Abstraction of `FSEventStreamEventFlags`
    public struct Flags: OptionSet, Codable, Hashable {
        
        public let rawValue: FSEventStreamEventFlags
        public init(rawValue: FSEventStreamEventFlags) {
            self.rawValue = rawValue
        }
        
        public static let none = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagNone))
        public static let mustScanSubDirs = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs))
        public static let userDropped = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped))
        public static let kernelDropped = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped))
        public static let eventIDsWrapped = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped))
        public static let historyDone = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone))
        public static let rootChanged = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged))
        public static let mount = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMount))
        public static let unmount = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount))
        public static let itemChangeOwner = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner))
        public static let itemCreated = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
        public static let itemFinderInfoMod = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod))
        public static let itemInodeMetaMod = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod))
        public static let itemIsDir = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir))
        public static let itemIsFile = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile))
        public static let itemIsHardlink = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsHardlink))
        public static let itemIsLastHardlink = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsLastHardlink))
        public static let itemIsSymlink = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink))
        public static let itemModified = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified))
        public static let itemRemoved = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved))
        public static let itemRenamed = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed))
        public static let itemXattrMod = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod))
        public static let ownEvent = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent))
    
        static let allOptions: [Flags] = [
            .none,
            .mustScanSubDirs, .userDropped, .kernelDropped,
            .eventIDsWrapped, .historyDone,
            .rootChanged, .mount, .unmount,
            .itemChangeOwner, .itemCreated, .itemFinderInfoMod, .itemInodeMetaMod,
            .itemIsDir, .itemIsFile, .itemIsHardlink, .itemIsLastHardlink, .itemIsSymlink,
            .itemModified, .itemRemoved, .itemRenamed, .itemXattrMod,
            .ownEvent
        ]
    }
    
    public var readableFlags: [String] {
        let flagNames: [String] = FileSystemObserver.Event.Flags.allOptions.compactMap { (flagToTest: Flags) in
            
            guard flags.contains(flagToTest) else { return nil }
            
            switch flagToTest {
            case .none: return nil
            case .mustScanSubDirs: return "mustScanSubDirs"
            case .userDropped: return "userDropped"
            case .kernelDropped: return "kernelDropped"
            case .eventIDsWrapped: return "eventIDsWrapped"
            case .historyDone: return "historyDone"
            case .rootChanged: return "rootChanged"
            case .mount: return "mount"
            case .unmount: return "unmount"
            case .itemChangeOwner: return "itemChangeOwner"
            case .itemCreated: return "itemCreated"
            case .itemFinderInfoMod: return "itemFinderInfoMod"
            case .itemInodeMetaMod: return "itemInodeMetaMod"
            case .itemIsDir: return "itemIsDir"
            case .itemIsFile: return "itemIsFile"
            case .itemIsHardlink: return "itemIsHardlink"
            case .itemIsLastHardlink: return "itemIsLastHardlink"
            case .itemIsSymlink: return "itemIsSymlink"
            case .itemModified: return "itemModified"
            case .itemRemoved: return "itemRemoved"
            case .itemRenamed: return "itemRenamed"
            case .itemXattrMod: return "itemXattrMod"
            case .ownEvent: return "ownEvent"
            default:
                return "unknown(raw: \(flagToTest))"
            }
        }
        return flagNames.isEmpty ? ["(none)"] : flagNames
    }
}
