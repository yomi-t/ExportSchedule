//
//  FreeDayCalculatorTests.swift
//  ExportScheduleTests
//
//  「空いてる日」判定ロジックの単体テスト。
//

import Testing
import Foundation
@testable import ExportSchedule

struct FreeDayCalculatorTests {

    private let calculator = FreeDayCalculator()
    private let calendar = TestSupport.tokyoCalendar

    private func settings(start: Date, end: Date,
                          window: WorkingHours = WorkingHours(start: TimeOfDay(hour: 10, minute: 0),
                                                              end: TimeOfDay(hour: 18, minute: 0))) -> FreeDaySettings {
        FreeDaySettings(rangeStart: start, rangeEnd: end, timeWindow: window, timeZoneIdentifier: "Asia/Tokyo")
    }

    @Test func dayWithNoEventsIsFullyFree() {
        let day = TestSupport.date(2026, 6, 15)
        let result = calculator.computeFreeDays(busyIntervals: [],
                                                settings: settings(start: day, end: day),
                                                calendar: calendar)
        #expect(result == [day])
    }

    @Test func dayWithEventInsideWindowIsExcluded() {
        let day = TestSupport.date(2026, 6, 15)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0),
                                 end: TestSupport.date(2026, 6, 15, 13, 0))]
        let result = calculator.computeFreeDays(busyIntervals: busy,
                                                settings: settings(start: day, end: day),
                                                calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test func dayWithAllDayEventIsExcluded() {
        let day = TestSupport.date(2026, 6, 15)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 0, 0),
                                 end: TestSupport.date(2026, 6, 16, 0, 0),
                                 isAllDay: true)]
        let result = calculator.computeFreeDays(busyIntervals: busy,
                                                settings: settings(start: day, end: day),
                                                calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test func eventOutsideWindowDoesNotExcludeDay() {
        // 9:00〜9:30の予定は時間帯(10:00〜18:00)の外なので、この日はまるごと空きとして扱われる。
        let day = TestSupport.date(2026, 6, 15)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 9, 0),
                                 end: TestSupport.date(2026, 6, 15, 9, 30))]
        let result = calculator.computeFreeDays(busyIntervals: busy,
                                                settings: settings(start: day, end: day),
                                                calendar: calendar)
        #expect(result == [day])
    }

    @Test func onlyFullyFreeDaysAreReturnedAcrossRange() {
        // 15日は予定あり(除外)、16日・17日は予定なし(採用)。土日を含む3連休でも曜日を問わず判定される。
        let start = TestSupport.date(2026, 6, 15)
        let end = TestSupport.date(2026, 6, 17)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0),
                                 end: TestSupport.date(2026, 6, 15, 13, 0))]
        let result = calculator.computeFreeDays(busyIntervals: busy,
                                                settings: settings(start: start, end: end),
                                                calendar: calendar)
        #expect(result == [TestSupport.date(2026, 6, 16), TestSupport.date(2026, 6, 17)])
    }

    @Test func weekendDaysAreIncludedUnlikeFreeSlotMode() {
        // 2026-06-13(土)・14(日) も、空いてる日モードでは曜日を問わず判定対象になる。
        let start = TestSupport.date(2026, 6, 13)
        let end = TestSupport.date(2026, 6, 14)
        let result = calculator.computeFreeDays(busyIntervals: [],
                                                settings: settings(start: start, end: end),
                                                calendar: calendar)
        #expect(result == [TestSupport.date(2026, 6, 13), TestSupport.date(2026, 6, 14)])
    }

    // MARK: - eventsByDay（カレンダーUIのドット・ポップオーバー表示用）

    @Test func eventsByDayIncludesEventsOutsideTheTimeWindow() {
        // 9:00〜9:30は時間帯(10:00〜18:00)の外だが、eventsByDayでは判定用の時間帯と無関係にその日の予定として含まれる。
        let day = TestSupport.date(2026, 6, 15)
        let event = BusyInterval(start: TestSupport.date(2026, 6, 15, 9, 0),
                                 end: TestSupport.date(2026, 6, 15, 9, 30),
                                 title: "早朝ミーティング")
        let result = calculator.eventsByDay(busyIntervals: [event], calendar: calendar)
        #expect(result[day] == [event])
    }

    @Test func eventsByDaySpanningMultipleDaysAppearsOnEachDay() {
        // 6/15 23:00 〜 6/16 1:00 の予定は、開始日・終了日の両方に含まれる。
        let event = BusyInterval(start: TestSupport.date(2026, 6, 15, 23, 0),
                                 end: TestSupport.date(2026, 6, 16, 1, 0))
        let result = calculator.eventsByDay(busyIntervals: [event], calendar: calendar)
        #expect(result[TestSupport.date(2026, 6, 15)] == [event])
        #expect(result[TestSupport.date(2026, 6, 16)] == [event])
    }

    @Test func eventsByDayGroupsMultipleEventsOnSameDay() {
        let day = TestSupport.date(2026, 6, 15)
        let morning = BusyInterval(start: TestSupport.date(2026, 6, 15, 9, 0), end: TestSupport.date(2026, 6, 15, 9, 30))
        let afternoon = BusyInterval(start: TestSupport.date(2026, 6, 15, 14, 0), end: TestSupport.date(2026, 6, 15, 15, 0))
        let result = calculator.eventsByDay(busyIntervals: [afternoon, morning], calendar: calendar)
        #expect(result[day] == [morning, afternoon])
    }
}
