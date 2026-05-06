import XCTest
import AppKit
@testable import openTalk

final class PasterTests: XCTestCase {
    private var savedClipboard: PasteboardSnapshot!

    override func setUp() {
        super.setUp()
        savedClipboard = PasteboardSnapshot.capture(NSPasteboard.general)
    }

    override func tearDown() {
        savedClipboard.restore(into: NSPasteboard.general)
        super.tearDown()
    }

    func test_snapshot_thenRestore_returnsExactPriorString() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("BEFORE", forType: .string)

        let snapshot = PasteboardSnapshot.capture(pb)
        pb.clearContents()
        pb.setString("MIDDLE", forType: .string)
        XCTAssertEqual(pb.string(forType: .string), "MIDDLE")

        snapshot.restore(into: pb)
        XCTAssertEqual(pb.string(forType: .string), "BEFORE")
    }

    func test_snapshot_preservesMultipleTypes() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("hello", forType: .string)
        pb.setData(Data([0x01, 0x02]), forType: .tabularText)

        let snapshot = PasteboardSnapshot.capture(pb)
        pb.clearContents()
        pb.setString("ZAP", forType: .string)

        snapshot.restore(into: pb)
        XCTAssertEqual(pb.string(forType: .string), "hello")
        XCTAssertEqual(pb.data(forType: .tabularText), Data([0x01, 0x02]))
    }
}
