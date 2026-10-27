import XCTest
import CoreGraphics
import Foundation

final class RemoteInputOwnershipTests: XCTestCase {
    func testLocalInputRevokesRemoteKeysDragAndScroll() {
        var ownership = RemoteInputOwnership()
        XCTAssertFalse(ownership.accept(type: "key", phase: "down", epoch: 0))
        XCTAssertTrue(ownership.accept(type: "mouse", phase: "down", epoch: 0))
        XCTAssertTrue(ownership.accept(type: "key", phase: "down", epoch: 0))
        XCTAssertTrue(ownership.localActivity())
        XCTAssertFalse(ownership.accept(type: "mouse", phase: "move", epoch: 0))
        XCTAssertFalse(ownership.accept(type: "key", phase: "down", epoch: 0))
        XCTAssertFalse(ownership.accept(type: "scroll", phase: nil, epoch: 0))
    }

    func testQueuedClickCannotStealControlButFreshClickCan() {
        var ownership = RemoteInputOwnership()
        XCTAssertTrue(ownership.accept(type: "mouse", phase: "down", epoch: 0))
        XCTAssertTrue(ownership.localActivity())
        XCTAssertFalse(ownership.accept(type: "mouse", phase: "down", epoch: 0))
        XCTAssertFalse(ownership.accept(type: "mouse", phase: "move", epoch: 1))
        XCTAssertTrue(ownership.accept(type: "mouse", phase: "down", epoch: 1))
        XCTAssertTrue(ownership.accept(type: "key", phase: "down", epoch: 1))
    }

    func testIdleLocalInputDoesNotContinuouslyChangeEpoch() {
        var ownership = RemoteInputOwnership()
        XCTAssertFalse(ownership.localActivity())
        XCTAssertEqual(ownership.epoch, 0)
        XCTAssertTrue(ownership.accept(type: "mouse", phase: "down", epoch: 0))
        ownership.reset()
        XCTAssertFalse(ownership.receiverActive)
        XCTAssertFalse(ownership.localActivity())
    }

    func testInjectedEventsDoNotCountAsLocalActivity() throws {
        XCTAssertTrue(LocalInputMonitor.isLocalActivity(userData: 0, processID: 0))
        XCTAssertFalse(LocalInputMonitor.isLocalActivity(
            userData: LocalInputMonitor.injectedEventTag, processID: 0))
        XCTAssertFalse(LocalInputMonitor.isLocalActivity(userData: 0,
            processID: Int64(ProcessInfo.processInfo.processIdentifier)))

        let source = try XCTUnwrap(CGEventSource(stateID: .privateState))
        source.userData = LocalInputMonitor.injectedEventTag
        let event = try XCTUnwrap(CGEvent(source: source))
        XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), LocalInputMonitor.injectedEventTag)
        XCTAssertFalse(LocalInputMonitor.isLocalActivity(event))
    }
}
