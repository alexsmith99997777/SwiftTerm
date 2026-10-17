//
//  MarkedTextCompositionTests.swift
//
//  AppKit coverage for the composition caret: while an input method composes, the
//  insertion indicator and the candidate-panel geometry follow the marked-text selection
//  while the terminal cursor stays its anchor. Enable with:
//  RUN_APPKIT_TESTS=1 swift test --filter MarkedTextCompositionTests
//

#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import SwiftTerm

private func appKitTestsEnabled() -> Bool {
    ProcessInfo.processInfo.environment["RUN_APPKIT_TESTS"] == "1"
}

@Suite(.enabled(if: appKitTestsEnabled()), .serialized)
@MainActor
final class MarkedTextCompositionTests {
    private final class CapturingDelegate: TerminalViewDelegate {
        var sent: [String] = []
        func send(source: TerminalView, data: ArraySlice<UInt8>) { sent.append(String(decoding: data, as: UTF8.self)) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }

    private func configuredView() -> (TerminalView, CapturingDelegate, NSWindow) {
        _ = NSApplication.shared
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        let capture = CapturingDelegate()
        view.terminalDelegate = capture
        view.feed(text: "prompt> ")
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(view)
        window.makeFirstResponder(view)
        view.updateCursorPosition()
        return (view, capture, window)
    }

    private func caretHidden(_ view: TerminalView) -> Bool {
        view.subviews.first { $0 is CaretView }?.isHidden ?? true
    }

    private func compositionIndicator(_ view: TerminalView) -> NSView? {
        view.subviews.first { $0 is CompositionCaretView }
    }

    @Test func insertionIndicatorFollowsTheMarkedSelectionAndTheServerCursorStays() {
        let (view, capture, window) = configuredView()
        defer { window.close() }
        let anchor = view.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        let cursorBefore = view.withTerminal { ($0.buffer.x, $0.buffer.y) }

        view.setMarkedText("abc", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(view.hasMarkedText())
        #expect(view.selectedRange() == NSRange(location: 3, length: 0))
        #expect(view.markedRange() == NSRange(location: 0, length: 3))
        #expect(caretHidden(view), "the terminal caret hides behind the composition")
        let trailing = view.firstRect(forCharacterRange: NSRange(location: 3, length: 0), actualRange: nil)
        let leading = view.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        #expect(trailing.minX > leading.minX, "offset 3 is after the whole marked string")
        #expect(abs(trailing.minX - leading.minX - 3 * view.cellDimension.width) < 1, "three cells along the grid")
        #expect(abs(leading.minX - anchor.minX) < 1, "the composition starts at the anchor cursor")
        let indicatorAtEnd = compositionIndicator(view)?.frame
        #expect(indicatorAtEnd != nil)

        view.setMarkedText("abc", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(view.selectedRange() == NSRange(location: 1, length: 0))
        let interior = view.firstRect(forCharacterRange: NSRange(location: 1, length: 0), actualRange: nil)
        #expect(interior.minX > leading.minX && interior.minX < trailing.minX, "an interior selection sits at its own position")
        let indicatorInside = compositionIndicator(view)?.frame
        #expect(indicatorInside != nil && indicatorAtEnd != nil && indicatorInside!.minX < indicatorAtEnd!.minX, "the local caret moved")

        var actual = NSRange(location: NSNotFound, length: 0)
        let clause = view.firstRect(forCharacterRange: NSRange(location: 1, length: 2), actualRange: &actual)
        #expect(actual == NSRange(location: 1, length: 2))
        #expect(clause.width > view.cellDimension.width, "a selected clause reports its own rectangle")

        #expect(view.withTerminal { ($0.buffer.x, $0.buffer.y) } == cursorBefore, "the server cursor never moved")
        #expect(capture.sent.isEmpty, "nothing reached the terminal before the commit")

        view.unmarkText()
        #expect(!view.hasMarkedText())
        #expect(!caretHidden(view), "cancelling restores the terminal caret")
        #expect(compositionIndicator(view) == nil)
        #expect(capture.sent.isEmpty, "cancellation commits nothing")
    }

    @Test func wideGlyphsAdvanceTwoCellsAndCommitSendsOnce() {
        let (view, capture, window) = configuredView()
        defer { window.close() }
        view.setMarkedText("日本語", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        let first = view.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        let second = view.firstRect(forCharacterRange: NSRange(location: 1, length: 0), actualRange: nil)
        let end = view.firstRect(forCharacterRange: NSRange(location: 3, length: 0), actualRange: nil)
        #expect(second.minX > first.minX && end.minX > second.minX)
        #expect(second.minX - first.minX > view.cellDimension.width, "a wide glyph is wider than one cell")

        view.setMarkedText("🙂a", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        let afterSurrogate = view.firstRect(forCharacterRange: NSRange(location: 2, length: 0), actualRange: nil)
        let beforeSurrogate = view.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        #expect(afterSurrogate.minX > beforeSurrogate.minX, "UTF-16 offsets inside a surrogate pair resolve")

        view.insertText("日本語", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!view.hasMarkedText())
        #expect(capture.sent == ["日本語"], "exactly one commit")
        #expect(!caretHidden(view))
    }
}
#endif
