//
//  ScheduleTextFormatterTests.swift
//  ExportScheduleTests
//
//  日本語整形ロジックの単体テスト。
//

import Testing
import Foundation
@testable import ExportSchedule

struct ScheduleTextFormatterTests {

    private let formatter = ScheduleTextFormatter()
    private let calendar = TestSupport.tokyoCalendar

    private func range(_ day: (Int, Int, Int), _ from: (Int, Int), _ to: (Int, Int)) -> DateRange {
        DateRange(start: TestSupport.date(day.0, day.1, day.2, from.0, from.1),
                  end: TestSupport.date(day.0, day.1, day.2, to.0, to.1))
    }

    @Test func weekdaySymbolsMapCorrectly() {
        // 2026-06-14(日)〜06-20(土)。
        let expected = ["日", "月", "火", "水", "木", "金", "土"]
        for (offset, symbol) in expected.enumerated() {
            let day = TestSupport.date(2026, 6, 14 + offset)
            let availability = [DateAvailability(day: day,
                                                 freeIntervals: [range((2026, 6, 14 + offset), (10, 0), (18, 0))])]
            let text = formatter.format(availability, calendar: calendar)
            #expect(text == "6/\(14 + offset)(\(symbol)) 10:00〜18:00")
        }
    }

    @Test func singleFreeIntervalIsFormatted() {
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 15),
                                             freeIntervals: [range((2026, 6, 15), (10, 0), (12, 0))]
                                            )]
        let text = formatter.format(availability, calendar: calendar)
        #expect(text == "6/15(月) 10:00〜12:00")
    }

    @Test func multipleIntervalsAreCommaJoined() {
        let availability = [DateAvailability(
            day: TestSupport.date(2026, 6, 15),
            freeIntervals: [range((2026, 6, 15), (10, 0), (12, 0)),
                            range((2026, 6, 15), (14, 0), (18, 0))]
            )]
        let text = formatter.format(availability, calendar: calendar)
        #expect(text == "6/15(月) 10:00〜12:00, 14:00〜18:00")
    }

    @Test func fullyFreeDayUsesExistingRangeFormat() {
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 16),
                                             freeIntervals: [range((2026, 6, 16), (10, 0), (18, 0))]
                                             )]
        let text = formatter.format(availability, calendar: calendar)
        #expect(text == "6/16(火) 10:00〜18:00")
    }

    @Test func minutesAreZeroPaddedAndHoursAreNot() {
        let availability = [DateAvailability(
            day: TestSupport.date(2026, 6, 15),
            freeIntervals: [range((2026, 6, 15), (9, 5), (10, 0))]
            )]
        let text = formatter.format(availability, calendar: calendar)
        #expect(text == "6/15(月) 9:05〜10:00")
    }

    @Test func multiDayOutputMatchesSpecExample() {
        let availability = [
            DateAvailability(day: TestSupport.date(2026, 6, 15),
                             freeIntervals: [range((2026, 6, 15), (10, 0), (12, 0)),
                                             range((2026, 6, 15), (14, 0), (18, 0))]
                             ),
            DateAvailability(day: TestSupport.date(2026, 6, 16),
                             freeIntervals: [range((2026, 6, 16), (10, 0), (18, 0))]
                             ),
        ]
        let text = formatter.format(availability, calendar: calendar)
        #expect(text == "6/15(月) 10:00〜12:00, 14:00〜18:00\n6/16(火) 10:00〜18:00")
    }

    @Test func emptyAvailabilityProducesEmptyString() {
        #expect(formatter.format([], calendar: calendar).isEmpty)
    }

    @Test func dayWithNoOutputIsOmitted() {
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 15),
                                             freeIntervals: []
                                             )]
        #expect(formatter.format(availability, calendar: calendar).isEmpty)
    }

    @Test func kanjiDateStyleIsFormatted() {
        let format = TextOutputFormat(dateStyle: .kanji, timeStyle: .colon, zeroPadded: false)
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 15),
                                             freeIntervals: [range((2026, 6, 15), (10, 0), (12, 0))]
                                            )]
        let text = formatter.format(availability, calendar: calendar, outputFormat: format)
        #expect(text == "6月15日(月) 10:00〜12:00")
    }

    @Test func kanjiTimeStyleIsFormatted() {
        let format = TextOutputFormat(dateStyle: .slash, timeStyle: .kanji, zeroPadded: false)
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 15),
                                             freeIntervals: [range((2026, 6, 15), (10, 0), (12, 0))]
                                            )]
        let text = formatter.format(availability, calendar: calendar, outputFormat: format)
        #expect(text == "6/15(月) 10時00分〜12時00分")
    }

    @Test func zeroPaddedFormatsMonthDayAndHour() {
        let format = TextOutputFormat(dateStyle: .slash, timeStyle: .colon, zeroPadded: true)
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 9),
                                             freeIntervals: [range((2026, 6, 9), (9, 5), (10, 0))]
                                            )]
        let text = formatter.format(availability, calendar: calendar, outputFormat: format)
        #expect(text == "06/09(火) 09:05〜10:00")
    }

    @Test func kanjiStyleWithZeroPadded() {
        let format = TextOutputFormat(dateStyle: .kanji, timeStyle: .kanji, zeroPadded: true)
        let availability = [DateAvailability(day: TestSupport.date(2026, 6, 9),
                                             freeIntervals: [range((2026, 6, 9), (9, 5), (10, 0))]
                                            )]
        let text = formatter.format(availability, calendar: calendar, outputFormat: format)
        #expect(text == "06月09日(火) 09時05分〜10時00分")
    }
}
