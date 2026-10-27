import CoreGraphics

/// Mirror an existing desktop when available; otherwise own a virtual one.
enum MirrorDisplayPolicy {
    /// WindowServer can expose a synthetic 1080p desktop on a headless Mac.
    /// Its `unkn` / `virt` identity is not a physical mirror source.
    static func isHeadlessPlaceholder(vendor: UInt32, model: UInt32) -> Bool {
        vendor == 0x756E6B6E && model == 0x76697274
    }

    static func referenceDisplay(available: [CGDirectDisplayID],
                                 main: CGDirectDisplayID,
                                 openDisplayVirtuals: Set<CGDirectDisplayID>) -> CGDirectDisplayID? {
        let candidates = available.filter { !openDisplayVirtuals.contains($0) }
        return candidates.contains(main) ? main : candidates.first
    }

    /// Match the receiver's physical pixels, independent of its scaled desktop
    /// setting or a sender display-size preference. Fall back to 1x if 2x
    /// would change the native raster through point rounding.
    static func nativeCanvas(pixelsWide: Int, pixelsHigh: Int, scale: Double) -> VirtualCanvasSize? {
        if scale >= 1.5,
           let retina = VirtualCanvasSizing.requested(pixelsWide: pixelsWide, pixelsHigh: pixelsHigh),
           retina.pixelsWide == pixelsWide, retina.pixelsHigh == pixelsHigh { return retina }
        return VirtualCanvasSizing.requested(pixelsWide: pixelsWide, pixelsHigh: pixelsHigh, scale: 1)
    }
}
