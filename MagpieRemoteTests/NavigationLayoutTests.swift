import SwiftUI
import XCTest
@testable import MagpieRemote

final class NavigationLayoutTests: XCTestCase {
    func testAllChipsShownWhenTheyFit() {
        let count = SessionsView.visibleChipCount(
            widths: [40, 60, 60], available: 200, spacing: 7, moreWidth: { _ in 50 }
        )
        XCTAssertEqual(count, 3)
    }

    func testOverflowLeavesRoomForMore() {
        // 40 + 7 + 60 + 7 + 50(更多) = 164 ≤ 170，第三个 60 放不下
        let count = SessionsView.visibleChipCount(
            widths: [40, 60, 60, 60], available: 170, spacing: 7, moreWidth: { _ in 50 }
        )
        XCTAssertEqual(count, 2)
    }

    func testAllChipAlwaysVisible() {
        let count = SessionsView.visibleChipCount(
            widths: [40, 300], available: 60, spacing: 7, moreWidth: { _ in 50 }
        )
        XCTAssertEqual(count, 1)
    }

    func testWiderMoreLabelWhenSelectionIsCollapsed() {
        // 选中的第 4 项被收起时，「更多」显示它的名字，按钮更宽，可见项相应减少
        let widths: [CGFloat] = [40, 60, 60, 60]
        let narrow = SessionsView.visibleChipCount(widths: widths, available: 240, spacing: 7, moreWidth: { _ in 50 })
        let wide = SessionsView.visibleChipCount(
            widths: widths, available: 240, spacing: 7, moreWidth: { $0 <= 3 ? 110 : 50 }
        )
        XCTAssertEqual(narrow, 3)
        XCTAssertEqual(wide, 2)
    }

    func testChipWidthGrowsWithTitle() {
        XCTAssertGreaterThan(SessionsView.chipWidth("Antigravity CLI"), SessionsView.chipWidth("ai"))
        XCTAssertGreaterThan(SessionsView.moreChipWidth("更多"), SessionsView.chipWidth("更多"))
    }

    func testRailOnlyForWideTrailingColumnInLandscape() {
        // iPhone Duo 横屏：右侧状态栏一列
        XCTAssertTrue(MainTabView.usesTrailingRail(
            size: CGSize(width: 715, height: 542),
            insets: EdgeInsets(top: 0, leading: 0, bottom: 21, trailing: 85)
        ))
        // 普通 iPhone 横屏：左右对称
        XCTAssertFalse(MainTabView.usesTrailingRail(
            size: CGSize(width: 750, height: 381),
            insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)
        ))
        // 竖屏
        XCTAssertFalse(MainTabView.usesTrailingRail(
            size: CGSize(width: 402, height: 800),
            insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        ))
    }
}
