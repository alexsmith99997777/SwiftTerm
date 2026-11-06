#if !SWIFTTERM_EMBEDDED && (os(macOS) || os(iOS) || os(visionOS)) && canImport(MetalKit)
import XCTest
@testable import SwiftTerm

/// Shepi's owner saw rows of a terminal stop updating while the rows around them did, until a full redraw (2026-11-06).
/// The Metal row cache reuses a row's drawing by its source line's identity and generation (ee9425c). Kept only as an
/// address, that identity could be taken by a line allocated later at the freed line's place (ABA), with a generation
/// that matches too, and the cache would draw the freed line's text in the new line's row. A cache entry must keep the
/// identity alive for as long as it can be matched, as the snapshot's rows already do.
final class MetalRowCacheIdentityTests: XCTestCase {
    func testARowCacheEntryKeepsItsLinesIdentityAlive() {
        weak var identity: BufferLine.RenderIdentity?
        var entry: RowCacheEntry?
        do {
            let line = BufferLine(cols: 8)
            identity = line.renderIdentity
            entry = RowCacheEntry(source: line.renderIdentity, sourceGeneration: line.generation, revision: 0,
                                  canRelocate: true, data: nil, buffers: nil)
        }
        XCTAssertNotNil(identity, "the line is gone, but its cached row still holds the identity, so no new line can take its address")
        XCTAssertEqual(entry?.sourceIdentity, identity.map(ObjectIdentifier.init))
        entry = nil
        XCTAssertNil(identity, "dropping the entry lets it go")
    }

    /// A snapshot row hands the cache the same token it holds.
    func testASnapshotRowGivesItsSourcesToken() {
        let line = BufferLine(cols: 8)
        let row = TerminalSnapshot.Row(source: line)
        row.recordSource(line)
        XCTAssertTrue(row.sourceToken === line.renderIdentity)
        XCTAssertEqual(row.sourceIdentity, ObjectIdentifier(line.renderIdentity))
    }
}
#endif
