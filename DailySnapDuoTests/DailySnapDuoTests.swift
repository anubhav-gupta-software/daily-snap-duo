import XCTest
@testable import DailySnapDuo

final class DailySnapDuoTests: XCTestCase {
    func testAppGroupFallbackIsStable() {
        XCTAssertEqual(
            AppGroupLocator.fallbackIdentifier,
            "group.com.anubhavgupta.dailysnapduo"
        )
    }
}
