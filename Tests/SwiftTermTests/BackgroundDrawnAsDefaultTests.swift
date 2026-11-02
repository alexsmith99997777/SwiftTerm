//
//  BackgroundDrawnAsDefaultTests.swift
//  SwiftTermTests
//
//  A host that paints the surface behind a transparent terminal tells programs one colour for "the background"
//  (OSC 11). A program that paints that colour back explicitly would show as a box where the host's surface is
//  lighter, so the host names that colour and cells painted exactly it are drawn as default-background cells, at
//  the draw: the stored cells keep the program's colour (Herdi's R175, Shepi's R248).
//

import Foundation
import Testing
@testable import SwiftTerm

#if os(macOS)
import AppKit

@Suite("BackgroundDrawnAsDefault")
@MainActor
struct BackgroundDrawnAsDefaultTests {
    private let surface = Attribute.Color.trueColor(red: 10, green: 10, blue: 12)

    private func makeView() -> TerminalView {
        TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    private func makeContext(_ view: TerminalView) -> SnapshotRenderContext {
        SnapshotRenderContext(viewState: FrameViewState(view: view), style: .empty,
                              ansiColors: view.withTerminal { $0.ansiColors }, cols: 80)
    }

    private func attributes(_ view: TerminalView, bg: Attribute.Color, fg: Attribute.Color = .defaultColor,
                            style: CharacterStyle = .none) -> SnapshotTextAttributes? {
        SnapshotTextBuilder().getAttributes(Attribute(fg: fg, bg: bg, style: style), withUrl: false, context: makeContext(view))
    }

    @Test func aCellPaintedTheNamedColourIsDrawnAsDefault() {
        let view = makeView()
        view.backgroundDrawnAsDefault = surface
        let painted = attributes(view, bg: surface)
        #expect(painted?[SwiftTermExplicitBackgroundKey] == nil, "not filled: the host's surface shows through")
    }

    @Test func everyOtherPaintedBackgroundStaysExplicit() {
        let view = makeView()
        view.backgroundDrawnAsDefault = surface
        let black = attributes(view, bg: .trueColor(red: 0, green: 0, blue: 0))
        #expect(black?[SwiftTermExplicitBackgroundKey] != nil, "an editor theme's black keeps its box")
        let nearby = attributes(view, bg: .trueColor(red: 10, green: 10, blue: 13))
        #expect(nearby?[SwiftTermExplicitBackgroundKey] != nil, "exactly the colour, not near it")
        let ansi = attributes(view, bg: .ansi256(code: 2))
        #expect(ansi?[SwiftTermExplicitBackgroundKey] != nil)
    }

    @Test func withoutANamedColourTheSameCellStaysExplicit() {
        let view = makeView()
        #expect(view.backgroundDrawnAsDefault == nil)
        let painted = attributes(view, bg: surface)
        #expect(painted?[SwiftTermExplicitBackgroundKey] != nil)
    }

    @Test func anInvertedCellWhoseTextIsTheNamedColourIsDrawnAsDefaultToo() {
        let view = makeView()
        view.backgroundDrawnAsDefault = surface
        // Inverse swaps the pair: the background to fill would be the text's colour.
        let inverted = attributes(view, bg: .defaultColor, fg: surface, style: .inverse)
        #expect(inverted?[SwiftTermExplicitBackgroundKey] == nil)
    }

    @Test func namingTheColourChangesTheFramesIdentity() {
        let view = makeView()
        let before = makeContext(view).identity
        view.backgroundDrawnAsDefault = surface
        #expect(makeContext(view).identity != before, "cached attribute dictionaries are rebuilt")
    }
}
#endif
