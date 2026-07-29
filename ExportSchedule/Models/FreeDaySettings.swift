//
//  FreeDaySettings.swift
//  ExportSchedule
//
//  「空いてる日」判定のためのユーザー設定。
//

import Foundation

/// 「空いてる日」を判定する際のユーザー設定。`Codable` で UserDefaults などに永続化可能。
struct FreeDaySettings: Codable, Sendable, Hashable {
    /// 期間の開始日（この日を含む）。
    var rangeStart: Date
    /// 期間の終了日（この日を含む）。
    var rangeEnd: Date
    /// 「空いている」と判定する時間帯（曜日を問わず共通）。
    var timeWindow: WorkingHours
    /// 計算に用いるタイムゾーンの識別子（例: "Asia/Tokyo"）。
    var timeZoneIdentifier: String

    init(rangeStart: Date,
         rangeEnd: Date,
         timeWindow: WorkingHours,
         timeZoneIdentifier: String) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.timeWindow = timeWindow
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// 設定から構成した `Calendar`（グレゴリオ暦 + 指定タイムゾーン）。
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    /// 標準的な初期設定：本日から2週間、時間帯10:00〜18:00、現在のタイムゾーン。
    static func makeDefault(referenceDate: Date, calendar: Calendar = .current) -> FreeDaySettings {
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        let window = WorkingHours(start: TimeOfDay(hour: 10, minute: 0),
                                  end: TimeOfDay(hour: 18, minute: 0))
        return FreeDaySettings(
            rangeStart: start,
            rangeEnd: end,
            timeWindow: window,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }
}
