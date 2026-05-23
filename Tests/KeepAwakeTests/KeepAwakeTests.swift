import XCTest
@testable import KeepAwake

final class KeepAwakeTests: XCTestCase {
    func testCaffeinateFlagsBuildArgumentsInExpectedOrder() {
        var flags = CaffeinateFlags()
        flags.preventDisplaySleep = true
        flags.preventIdleSleep = true
        flags.preventDiskSleep = true
        flags.preventSystemSleep = true
        flags.declareUserActivity = true

        XCTAssertEqual(flags.arguments, ["-d", "-i", "-m", "-s", "-u"])
    }

    func testCaffeinateFlagsSummaryShowsNoneWhenEmpty() {
        let flags = CaffeinateFlags()
        XCTAssertTrue(flags.arguments.isEmpty)
        XCTAssertEqual(flags.summary, "(none)")
    }
}
