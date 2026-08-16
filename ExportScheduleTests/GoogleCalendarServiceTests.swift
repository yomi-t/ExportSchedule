//
//  GoogleCalendarServiceTests.swift
//  ExportScheduleTests
//
//  Google カレンダーの終日予定を BusyInterval に変換するロジックのテスト。
//  timeZone を正しく適用しないと、UTC とのオフセット分だけ日境界がずれて
//  隣接する日の空き時間計算が壊れる回帰バグを防ぐ。
//

import Testing
import Foundation
@testable import ExportSchedule

@MainActor
struct GoogleCalendarServiceTests {

    private let isoFormatter = ISO8601DateFormatter()
    private let service = GoogleCalendarService()

    private func allDayEvent(start: String, end: String) -> GoogleCalendarService.EventsResponse.Event {
        GoogleCalendarService.EventsResponse.Event(
            start: .init(date: start, dateTime: nil),
            end: .init(date: end, dateTime: nil),
            summary: "終日予定",
            transparency: nil
        )
    }

    @Test("終日予定の日付境界を Asia/Tokyo の現地0時として解釈する（UTC解釈による9時間のズレが発生しない）")
    func allDayEventInterpretedInLocalTimeZone() {
        let event = allDayEvent(start: "2026-08-20", end: "2026-08-21")
        let interval = service.busyInterval(from: event, isoFormatter: isoFormatter, timeZone: TestSupport.tokyoCalendar.timeZone)

        #expect(interval?.start == TestSupport.date(2026, 8, 20))
        #expect(interval?.end == TestSupport.date(2026, 8, 21))
    }

    @Test("翌日（8/21）の空き時間計算が終日予定の影響を受けない")
    func allDayEventDoesNotLeakIntoNextDay() throws {
        let event = allDayEvent(start: "2026-08-20", end: "2026-08-21")
        let interval = try #require(service.busyInterval(from: event, isoFormatter: isoFormatter, timeZone: TestSupport.tokyoCalendar.timeZone))

        let settings = TestSupport.settings(start: TestSupport.date(2026, 8, 20), end: TestSupport.date(2026, 8, 21))
        let schedules = FreeSlotCalculator().computeDaySchedules(busyIntervals: [interval],
                                                                 settings: settings,
                                                                 calendar: TestSupport.tokyoCalendar)

        let aug21 = try #require(schedules.first { TestSupport.tokyoCalendar.isDate($0.day, inSameDayAs: TestSupport.date(2026, 8, 21)) })
        #expect(!aug21.freeIntervals.isEmpty)
        #expect(aug21.events.isEmpty)
    }
}
