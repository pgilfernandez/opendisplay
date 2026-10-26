import CoreGraphics
import Foundation

/// A passive event tap; local input is never swallowed or delayed by the sender.
/// Lifecycle and callback run on the main run loop.
final class LocalInputMonitor {
    static let injectedEventTag: Int64 = 0x4F444953494E5054
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onActivity: (() -> Void)?

    func start(onActivity: @escaping () -> Void) {
        guard tap == nil else { return }
        self.onActivity = onActivity
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel, .keyDown, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<LocalInputMonitor>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                } else if LocalInputMonitor.isLocalActivity(event) {
                    monitor.onActivity?()
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            Log.info("local input monitor unavailable — check Accessibility permission")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.info("local input priority monitor ready")
    }

    static func isLocalActivity(_ event: CGEvent) -> Bool {
        isLocalActivity(userData: event.getIntegerValueField(.eventSourceUserData),
                        processID: event.getIntegerValueField(.eventSourceUnixProcessID))
    }

    static func isLocalActivity(userData: Int64, processID: Int64) -> Bool {
        userData != injectedEventTag && processID != Int64(ProcessInfo.processInfo.processIdentifier)
    }

    func stop() {
        if let tap { CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        onActivity = nil
    }

    deinit { stop() }
}
