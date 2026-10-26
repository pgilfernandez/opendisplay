import XCTest
import CoreGraphics

final class InputInjectorTests: XCTestCase {
    func testMouseButtonsDragAndReset() {
        var events: [CGEvent] = []
        let injector = InputInjector(displayID: CGMainDisplayID(), postRemoteEvent: { events.append($0) })
        injector.handleMouse(phase: "down", x: 0.3, y: 0.4, button: 1, clicks: 2, modifiers: 0)
        injector.handleMouse(phase: "move", x: 0.5, y: 0.6, button: 1, clicks: 1, modifiers: 0)
        injector.releaseRemoteInput()
        injector.releaseRemoteInput()
        XCTAssertEqual(events.map(\.type), [.rightMouseDown, .rightMouseDragged, .rightMouseUp])
        XCTAssertEqual(events[0].getIntegerValueField(.mouseEventClickState), 2)
        let bounds = CGDisplayBounds(CGMainDisplayID())
        XCTAssertEqual(events[1].location.x, bounds.minX + bounds.width * 0.5, accuracy: 0.01)
        XCTAssertEqual(events[1].location.y, bounds.minY + bounds.height * 0.6, accuracy: 0.01)
    }

    func testKeysRepeatModifiersAndReset() {
        var events: [CGEvent] = []
        let injector = InputInjector(displayID: CGMainDisplayID(), postRemoteEvent: { events.append($0) })
        injector.handleKey(phase: "flags", keyCode: 55, modifiers: CGEventFlags.maskCommand.rawValue, repeatKey: false)
        injector.handleKey(phase: "down", keyCode: 0, modifiers: CGEventFlags.maskCommand.rawValue, repeatKey: false)
        injector.handleKey(phase: "down", keyCode: 0, modifiers: CGEventFlags.maskCommand.rawValue, repeatKey: true)
        injector.releaseRemoteInput()
        XCTAssertEqual(events.map(\.type), [.flagsChanged, .keyDown, .keyDown, .keyUp, .flagsChanged])
        XCTAssertTrue(events[1].flags.contains(.maskCommand))
        XCTAssertEqual(events[2].getIntegerValueField(.keyboardEventAutorepeat), 1)
        XCTAssertTrue(events[4].flags.isEmpty)
    }

    func testInvalidInputAndUnmatchedReleaseAreIgnored() {
        var events: [CGEvent] = []
        let injector = InputInjector(displayID: CGMainDisplayID(), postRemoteEvent: { events.append($0) })
        injector.handleMouse(phase: "down", x: .nan, y: 0, button: 0, clicks: 1, modifiers: 0)
        injector.handleMouse(phase: "down", x: 0, y: 0, button: 32, clicks: 1, modifiers: 0)
        injector.handleMouse(phase: "up", x: 0, y: 0, button: 0, clicks: 1, modifiers: 0)
        injector.handleKey(phase: "down", keyCode: -1, modifiers: 0, repeatKey: false)
        injector.handleKey(phase: "up", keyCode: 0, modifiers: 0, repeatKey: false)
        XCTAssertTrue(events.isEmpty)
    }
}
