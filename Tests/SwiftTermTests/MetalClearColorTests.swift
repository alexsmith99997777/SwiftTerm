//
//  MetalClearColorTests.swift
//  SwiftTermTests
//
//  A translucent background's color must not stay in the cleared pixels: the
//  layer composites premultiplied, and a translucent quad (a selection) blended
//  onto that clear brought the color back. Measured on screen: a 28% selection
//  over a pane whose terminal background is #0E0E11 with alpha 0 came out 10
//  levels lighter than 28%.
//

#if os(macOS) || os(iOS) || os(visionOS)
import Metal
import Testing
@testable import SwiftTerm

struct MetalClearColorTests {
    @Test func clearColorIsPremultipliedByTheBackgroundsAlpha() {
        let transparent = MetalTerminalRenderer.clearColor(for: SIMD4<Float>(14 / 255, 14 / 255, 17 / 255, 0))
        #expect(transparent.red == 0 && transparent.green == 0 && transparent.blue == 0 && transparent.alpha == 0)

        let half = MetalTerminalRenderer.clearColor(for: SIMD4<Float>(0.5, 0.25, 1, 0.5))
        #expect(abs(half.red - 0.25) < 0.000_1 && abs(half.green - 0.125) < 0.000_1 && abs(half.blue - 0.5) < 0.000_1)
        #expect(half.alpha == 0.5)

        let opaque = MetalTerminalRenderer.clearColor(for: SIMD4<Float>(0.2, 0.3, 0.4, 1))
        #expect(abs(opaque.red - 0.2) < 0.000_1 && abs(opaque.green - 0.3) < 0.000_1 && abs(opaque.blue - 0.4) < 0.000_1,
                "an opaque background clears to itself")
        #expect(opaque.alpha == 1)
    }
}
#endif
