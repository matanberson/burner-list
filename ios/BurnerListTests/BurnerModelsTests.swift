import XCTest
@testable import BurnerList

final class BurnerModelsTests: XCTestCase {
    func testDateKeyUsesCalendarDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 6, hour: 12
        ))!

        XCTAssertEqual(Date.burnerKey(for: date, calendar: calendar), "2026-09-06")
    }

    func testEveryZoneKeepsItsDatabaseValue() {
        XCTAssertEqual(BurnerZone.allCases.map(\.rawValue), [
            "front-burner", "back-burner", "kitchen-sink", "unscheduled"
        ])
    }

    func testTaskScopesMatchTheWebNavigationOrder() {
        XCTAssertEqual(TaskScope.allCases.map(\.title), [
            "Today's List", "All Tasks", "Upcoming", "Previous"
        ])
    }

    func testTaskScopesUseScheduledDatesAndTheSelectedTodayList() {
        let userID = UUID()
        func task(id: String, listKey: String, date: String?) -> BurnerTaskRow {
            BurnerTaskRow(
                userId: userID,
                id: id,
                listKey: listKey,
                zone: .sink,
                text: id,
                done: false,
                sortOrder: 0,
                inProgress: false,
                boardOrder: 0,
                scheduledDate: date,
                completedAt: nil,
                updatedAt: Date(),
                deletedAt: nil
            )
        }

        let today = task(id: "today", listKey: "today-list", date: "2026-08-19")
        let unscheduledInToday = task(id: "in-today", listKey: "today-list", date: nil)
        let inbox = task(id: "inbox", listKey: "__inbox__", date: nil)
        let future = task(id: "future", listKey: "future-list", date: "2026-08-20")
        let past = task(id: "past", listKey: "past-list", date: "2026-08-18")

        XCTAssertTrue(TaskScope.today.includes(today, todayKey: "2026-08-19", selectedListKey: "today-list"))
        XCTAssertTrue(TaskScope.today.includes(unscheduledInToday, todayKey: "2026-08-19", selectedListKey: "today-list"))
        XCTAssertFalse(TaskScope.today.includes(inbox, todayKey: "2026-08-19", selectedListKey: "today-list"))
        XCTAssertTrue(TaskScope.upcoming.includes(future, todayKey: "2026-08-19", selectedListKey: "today-list"))
        XCTAssertTrue(TaskScope.previous.includes(past, todayKey: "2026-08-19", selectedListKey: "today-list"))
        XCTAssertTrue(TaskScope.all.includes(inbox, todayKey: "2026-08-19", selectedListKey: "today-list"))
    }
}
