import XCTest

final class MirrorDisplayPolicyTests: XCTestCase {
    func testNoDisplaysRequiresVirtualDesktop() {
        XCTAssertNil(MirrorDisplayPolicy.referenceDisplay(available: [], main: 0, openDisplayVirtuals: []))
    }

    func testMainReferenceIsPreferredOverEnumerationOrder() {
        XCTAssertEqual(MirrorDisplayPolicy.referenceDisplay(available: [2, 1], main: 1,
                                                             openDisplayVirtuals: []), 1)
    }

    func testOwnAndSiblingVirtualsCannotBecomeMirrorReference() {
        XCTAssertNil(MirrorDisplayPolicy.referenceDisplay(available: [3, 4], main: 3,
                                                           openDisplayVirtuals: [3, 4]))
        XCTAssertEqual(MirrorDisplayPolicy.referenceDisplay(available: [3, 4, 2], main: 3,
                                                             openDisplayVirtuals: [3, 4]), 2)
    }

    func testReceiverNativeRetinaRasterIsPreserved() throws {
        let native = try XCTUnwrap(MirrorDisplayPolicy.nativeCanvas(pixelsWide: 2880, pixelsHigh: 1800, scale: 2))
        XCTAssertEqual(native.pointsWide, 1440)
        XCTAssertEqual(native.pointsHigh, 900)
        XCTAssertEqual(native.scale, 2)
        XCTAssertEqual(native.pixelsWide, 2880)
        XCTAssertEqual(native.pixelsHigh, 1800)
    }

    func testNativeNonRetinaAndPortraitPanels() {
        XCTAssertEqual(MirrorDisplayPolicy.nativeCanvas(pixelsWide: 1920, pixelsHigh: 1080, scale: 1),
                       VirtualCanvasSize(pointsWide: 1920, pointsHigh: 1080, scale: 1))
        XCTAssertEqual(MirrorDisplayPolicy.nativeCanvas(pixelsWide: 2880, pixelsHigh: 5120, scale: 2),
                       VirtualCanvasSize(pointsWide: 1440, pointsHigh: 2560))
    }

    func testNativePixelsWinOverHiDPIWhenPointRoundingWouldChangeRaster() {
        let native = MirrorDisplayPolicy.nativeCanvas(pixelsWide: 1170, pixelsHigh: 2532, scale: 3)
        XCTAssertEqual(native?.pixelsWide, 1170)
        XCTAssertEqual(native?.pixelsHigh, 2532)
        XCTAssertEqual(native?.scale, 1)
        XCTAssertNil(MirrorDisplayPolicy.nativeCanvas(pixelsWide: 1, pixelsHigh: 1, scale: 2))
    }
}
