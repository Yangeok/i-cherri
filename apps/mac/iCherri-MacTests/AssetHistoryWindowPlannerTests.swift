import Testing
@testable import iCherri_Mac

struct AssetHistoryWindowPlannerTests {

    @Test("Given a page near the middle, when range is planned, then it keeps a symmetric window around the anchor")
    func centersWindowAroundAnchorPage() {
        let range = AssetHistoryWindowPlanner.pageRange(centeringOn: 6, lastPage: 12, radius: 2)
        #expect(range == 4...8)
    }

    @Test("Given a page near the beginning, when range is planned, then it clamps to the first available pages")
    func clampsWindowAtBeginning() {
        let range = AssetHistoryWindowPlanner.pageRange(centeringOn: 1, lastPage: 12, radius: 2)
        #expect(range == 0...4)
    }

    @Test("Given a page near the end, when range is planned, then it clamps to the last available pages")
    func clampsWindowAtEnd() {
        let range = AssetHistoryWindowPlanner.pageRange(centeringOn: 12, lastPage: 12, radius: 2)
        #expect(range == 8...12)
    }

    @Test("Given the current item is close to the bottom edge, when checking for next-page loading, then it requests the next window")
    func nextWindowThreshold() {
        #expect(AssetHistoryWindowPlanner.shouldLoadNext(currentIndex: 570, lastVisibleIndex: 599, threshold: 30))
        #expect(!AssetHistoryWindowPlanner.shouldLoadNext(currentIndex: 540, lastVisibleIndex: 599, threshold: 30))
    }

    @Test("Given the current item is close to the top edge, when checking for previous-page loading, then it requests the previous window")
    func previousWindowThreshold() {
        #expect(AssetHistoryWindowPlanner.shouldLoadPrevious(currentIndex: 430, firstVisibleIndex: 400, threshold: 30))
        #expect(!AssetHistoryWindowPlanner.shouldLoadPrevious(currentIndex: 470, firstVisibleIndex: 400, threshold: 30))
    }
}
