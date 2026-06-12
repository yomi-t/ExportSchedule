//
//  FreeSlotCalculatorTests.swift
//  ExportScheduleTests
//
//  空き時間計算ロジックの単体テスト。
//

import Testing
import Foundation
@testable import ExportSchedule

struct FreeSlotCalculatorTests {

    private let calculator = FreeSlotCalculator()
    private let calendar = TestSupport.tokyoCalendar

    // 2026-06-15 は月曜（営業日）。
    private func singleDaySettings(minimumSlotMinutes: Int = 30) -> FreeSlotSettings {
        let day = TestSupport.date(2026, 6, 15)
        return TestSupport.settings(start: day, end: day, minimumSlotMinutes: minimumSlotMinutes)
    }

    @Test func noEventsYieldsFullyFreeWindow() {
        let result = calculator.computeAvailability(busyIntervals: [],
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        #expect(result.count == 1)
        let day = try! #require(result.first)
        #expect(day.isFullyFree)
        #expect(day.freeIntervals.count == 1)
        #expect(day.freeIntervals[0].start == TestSupport.date(2026, 6, 15, 10, 0))
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 18, 0))
    }

    @Test func midDayEventSplitsWindow() {
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0),
                                 end: TestSupport.date(2026, 6, 15, 13, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(!day.isFullyFree)
        #expect(day.freeIntervals.count == 2)
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 12, 0))
        #expect(day.freeIntervals[1].start == TestSupport.date(2026, 6, 15, 13, 0))
    }

    @Test func eventFillingWindowLeavesNoFreeTime() {
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 10, 0),
                                 end: TestSupport.date(2026, 6, 15, 18, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(!day.isFullyFree)
        #expect(day.freeIntervals.isEmpty)
    }

    @Test func overlappingEventsAreMerged() {
        let busy = [
            BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0), end: TestSupport.date(2026, 6, 15, 14, 0)),
            BusyInterval(start: TestSupport.date(2026, 6, 15, 13, 0), end: TestSupport.date(2026, 6, 15, 15, 0)),
        ]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.count == 2)
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 12, 0))
        #expect(day.freeIntervals[1].start == TestSupport.date(2026, 6, 15, 15, 0))
    }

    @Test func adjacentEventsAreMerged() {
        let busy = [
            BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0), end: TestSupport.date(2026, 6, 15, 13, 0)),
            BusyInterval(start: TestSupport.date(2026, 6, 15, 13, 0), end: TestSupport.date(2026, 6, 15, 14, 0)),
        ]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.count == 2)
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 12, 0))
        #expect(day.freeIntervals[1].start == TestSupport.date(2026, 6, 15, 14, 0))
    }

    @Test func eventBeforeWindowClampsStart() {
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 9, 0),
                                 end: TestSupport.date(2026, 6, 15, 11, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.count == 1)
        #expect(day.freeIntervals[0].start == TestSupport.date(2026, 6, 15, 11, 0))
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 18, 0))
    }

    @Test func eventAfterWindowClampsEnd() {
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 17, 0),
                                 end: TestSupport.date(2026, 6, 15, 20, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.count == 1)
        #expect(day.freeIntervals[0].start == TestSupport.date(2026, 6, 15, 10, 0))
        #expect(day.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 17, 0))
    }

    @Test func midnightSpanningEventBlocksBothDays() {
        // 営業時間を 8:00〜23:00 に広げて深夜跨ぎを検証。
        let hours = WorkingHours(start: TimeOfDay(hour: 8, minute: 0),
                                 end: TimeOfDay(hour: 23, minute: 0))
        let settings = TestSupport.settings(start: TestSupport.date(2026, 6, 15),
                                            end: TestSupport.date(2026, 6, 16),
                                            hours: hours)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 22, 0),
                                 end: TestSupport.date(2026, 6, 16, 9, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: settings,
                                                    calendar: calendar)
        #expect(result.count == 2)
        // 15日: 8:00〜22:00 が空き。
        #expect(result[0].freeIntervals.count == 1)
        #expect(result[0].freeIntervals[0].end == TestSupport.date(2026, 6, 15, 22, 0))
        // 16日: 9:00〜23:00 が空き。
        #expect(result[1].freeIntervals.count == 1)
        #expect(result[1].freeIntervals[0].start == TestSupport.date(2026, 6, 16, 9, 0))
    }

    @Test func allDayEventBlocksEntireDay() {
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 0, 0),
                                 end: TestSupport.date(2026, 6, 16, 0, 0),
                                 isAllDay: true)]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(!day.isFullyFree)
        #expect(day.freeIntervals.isEmpty)
    }

    @Test func slotShorterThanMinimumIsDropped() {
        // 10:00〜17:40 の予定 → 残り 17:40〜18:00（20分）は最小30分未満で除外。
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 10, 0),
                                 end: TestSupport.date(2026, 6, 15, 17, 40))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(minimumSlotMinutes: 30),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.isEmpty)
    }

    @Test func slotEqualToMinimumIsKept() {
        // 10:00〜17:30 の予定 → 残り 17:30〜18:00（ちょうど30分）は採用（境界は >=）。
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 10, 0),
                                 end: TestSupport.date(2026, 6, 15, 17, 30))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: singleDaySettings(minimumSlotMinutes: 30),
                                                    calendar: calendar)
        let day = try! #require(result.first)
        #expect(day.freeIntervals.count == 1)
        #expect(day.freeIntervals[0].start == TestSupport.date(2026, 6, 15, 17, 30))
    }

    @Test func weekendDaysAreOmittedForWeekdayOnlyHours() {
        // 2026-06-13(土) 〜 2026-06-14(日) は平日のみ設定では出力対象外。
        let settings = TestSupport.settings(start: TestSupport.date(2026, 6, 13),
                                            end: TestSupport.date(2026, 6, 14))
        let result = calculator.computeAvailability(busyIntervals: [],
                                                    settings: settings,
                                                    calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test func singleDayRangeProducesSingleDay() {
        let result = calculator.computeAvailability(busyIntervals: [],
                                                    settings: singleDaySettings(),
                                                    calendar: calendar)
        #expect(result.count == 1)
    }

    // MARK: - 予定前後のバッファ

    @Test func bufferShrinksFreeIntervalsAroundEvent() {
        // 12:00〜13:00 の予定 + 前後30分バッファ → 空きは 10:00〜11:30 と 13:30〜18:00。
        let day = TestSupport.date(2026, 6, 15)
        let settings = TestSupport.settings(start: day, end: day, bufferMinutes: 30)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0),
                                 end: TestSupport.date(2026, 6, 15, 13, 0))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: settings,
                                                    calendar: calendar)
        let dayResult = try! #require(result.first)
        #expect(dayResult.freeIntervals.count == 2)
        #expect(dayResult.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 11, 30))
        #expect(dayResult.freeIntervals[1].start == TestSupport.date(2026, 6, 15, 13, 30))
    }

    @Test func bufferMergesEventsWithSmallGap() {
        // 12:00〜13:00 と 13:40〜14:00 の間は40分。前後20分バッファで重なり1ブロックに統合。
        let day = TestSupport.date(2026, 6, 15)
        let settings = TestSupport.settings(start: day, end: day, bufferMinutes: 20)
        let busy = [
            BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0), end: TestSupport.date(2026, 6, 15, 13, 0)),
            BusyInterval(start: TestSupport.date(2026, 6, 15, 13, 40), end: TestSupport.date(2026, 6, 15, 14, 0)),
        ]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: settings,
                                                    calendar: calendar)
        let dayResult = try! #require(result.first)
        // 11:40〜13:20 と 13:20〜14:20 が隣接して統合 → 空きは 10:00〜11:40 と 14:20〜18:00。
        #expect(dayResult.freeIntervals.count == 2)
        #expect(dayResult.freeIntervals[0].end == TestSupport.date(2026, 6, 15, 11, 40))
        #expect(dayResult.freeIntervals[1].start == TestSupport.date(2026, 6, 15, 14, 20))
    }

    @Test func bufferFromEventBeforeWindowEatsIntoWindowStart() {
        // 9:00〜9:50 の予定 + 30分バッファ → 終端 10:20 まで延びて営業開始 10:00 を侵食。
        let day = TestSupport.date(2026, 6, 15)
        let settings = TestSupport.settings(start: day, end: day, bufferMinutes: 30)
        let busy = [BusyInterval(start: TestSupport.date(2026, 6, 15, 9, 0),
                                 end: TestSupport.date(2026, 6, 15, 9, 50))]
        let result = calculator.computeAvailability(busyIntervals: busy,
                                                    settings: settings,
                                                    calendar: calendar)
        let dayResult = try! #require(result.first)
        #expect(dayResult.freeIntervals.count == 1)
        #expect(dayResult.freeIntervals[0].start == TestSupport.date(2026, 6, 15, 10, 20))
        #expect(!dayResult.isFullyFree)
    }
}
