import Testing
@testable import iCherri_Mac

struct MenuBarStateTests {

    @Test("Given no startup issue, when offline status is shown, then default copy stays unchanged")
    func offlineCopyWithoutIssueUsesDefaultText() {
        #expect(MenuBarState.normalizedIssue(nil) == nil)
        #expect(MenuBarState.normalizedIssue("   \n") == nil)
    }

    @Test("Given startup issue, when issue is normalized, then trimmed detail is preserved for menu bar display")
    func normalizedIssueTrimsWhitespace() {
        #expect(MenuBarState.normalizedIssue(" Listener failed: Address already in use \n") == "Listener failed: Address already in use")
    }
}
