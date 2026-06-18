//
//  FreeSlotSettings.swift
//  ExportSchedule
//
//  空き時間計算のためのユーザー設定。
//

import Foundation

/// 空き時間を計算する際のユーザー設定。`Codable` で UserDefaults などに永続化可能。
struct FreeSlotSettings: Codable, Sendable, Hashable {
    /// 期間の開始日（この日を含む）。
    var rangeStart: Date
    /// 期間の終了日（この日を含む）。
    var rangeEnd: Date
    /// 曜日ごとの時間帯。
    var weeklyWorkingHours: WeeklyWorkingHours
    /// 抽出する空きスロットの最小分数（これ未満の空きは除外）。
    var minimumSlotMinutes: Int
    /// 各予定の前後に確保する空け時間（分）。予定の直後・直前に空きが入らないようにする。
    var bufferMinutes: Int
    /// 計算に用いるタイムゾーンの識別子（例: "Asia/Tokyo"）。
    var timeZoneIdentifier: String

    init(rangeStart: Date,
         rangeEnd: Date,
         weeklyWorkingHours: WeeklyWorkingHours,
         minimumSlotMinutes: Int,
         bufferMinutes: Int = 0,
         timeZoneIdentifier: String) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.weeklyWorkingHours = weeklyWorkingHours
        self.minimumSlotMinutes = minimumSlotMinutes
        self.bufferMinutes = bufferMinutes
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    // 既存の永続データに bufferMinutes が無くても読み込めるようにする。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rangeStart = try container.decode(Date.self, forKey: .rangeStart)
        rangeEnd = try container.decode(Date.self, forKey: .rangeEnd)
        weeklyWorkingHours = try container.decode(WeeklyWorkingHours.self, forKey: .weeklyWorkingHours)
        minimumSlotMinutes = try container.decode(Int.self, forKey: .minimumSlotMinutes)
        bufferMinutes = try container.decodeIfPresent(Int.self, forKey: .bufferMinutes) ?? 0
        timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
    }

    /// 設定から構成した `Calendar`（グレゴリオ暦 + 指定タイムゾーン）。
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    /// 標準的な初期設定：本日から2週間、平日10:00〜18:00、最小30分、前後バッファ0分、現在のタイムゾーン。
    static func makeDefault(referenceDate: Date, calendar: Calendar = .current) -> FreeSlotSettings {
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        let hours = WorkingHours(start: TimeOfDay(hour: 10, minute: 0),
                                 end: TimeOfDay(hour: 18, minute: 0))
        return FreeSlotSettings(
            rangeStart: start,
            rangeEnd: end,
            weeklyWorkingHours: .weekdays(hours),
            minimumSlotMinutes: 30,
            bufferMinutes: 0,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }
}
