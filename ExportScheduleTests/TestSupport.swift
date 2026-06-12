//
//  TestSupport.swift
//  ExportScheduleTests
//
//  テスト共通のヘルパー（固定タイムゾーンの Calendar と Date 生成）。
//

import Foundation
@testable import ExportSchedule

enum TestSupport {
    /// 決定的なテストのための Asia/Tokyo 固定カレンダー。
    static let tokyoCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 指定年月日時分の Date を Asia/Tokyo で生成する。
    static func date(_ year: Int, _ month: Int, _ day: Int,
                     _ hour: Int = 0, _ minute: Int = 0,
                     calendar: Calendar = tokyoCalendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)!
    }

    /// 平日10:00〜18:00・最小30分・Asia/Tokyo の設定を、指定期間で作る。
    static func settings(start: Date, end: Date,
                         minimumSlotMinutes: Int = 30,
                         bufferMinutes: Int = 0,
                         hours: WorkingHours = WorkingHours(start: TimeOfDay(hour: 10, minute: 0),
                                                            end: TimeOfDay(hour: 18, minute: 0)),
                         weekly: WeeklyWorkingHours? = nil) -> FreeSlotSettings {
        FreeSlotSettings(
            rangeStart: start,
            rangeEnd: end,
            weeklyWorkingHours: weekly ?? .weekdays(hours),
            minimumSlotMinutes: minimumSlotMinutes,
            bufferMinutes: bufferMinutes,
            timeZoneIdentifier: "Asia/Tokyo"
        )
    }
}
