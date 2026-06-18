//
//  WorkingHours.swift
//  ExportSchedule
//
//  時間帯（1日の稼働時間帯）と、曜日ごとの時間帯設定。
//

import Foundation

/// 1日の時間帯帯。`start` から `end` までを稼働時間とみなす。
struct WorkingHours: Codable, Sendable, Hashable {
    var start: TimeOfDay
    var end: TimeOfDay

    init(start: TimeOfDay, end: TimeOfDay) {
        self.start = start
        self.end = end
    }
}

/// 曜日ごとの時間帯。キーは `Calendar` の weekday（1=日曜 … 7=土曜）。
/// キーが存在しない曜日は「非稼働日」として空き時間計算の対象外（出力に含めない）。
struct WeeklyWorkingHours: Codable, Sendable, Hashable {
    /// weekday(1...7) → 時間帯。
    var hoursByWeekday: [Int: WorkingHours]

    init(hoursByWeekday: [Int: WorkingHours]) {
        self.hoursByWeekday = hoursByWeekday
    }

    /// 指定曜日の時間帯を返す（非稼働日は nil）。
    func workingHours(forWeekday weekday: Int) -> WorkingHours? {
        hoursByWeekday[weekday]
    }

    /// 平日(月〜金)を共通の時間帯、土日を非稼働とするデフォルト設定。
    static func weekdays(_ hours: WorkingHours) -> WeeklyWorkingHours {
        // Calendar weekday: 1=日, 2=月, 3=火, 4=水, 5=木, 6=金, 7=土
        var map: [Int: WorkingHours] = [:]
        for weekday in 2...6 {
            map[weekday] = hours
        }
        return WeeklyWorkingHours(hoursByWeekday: map)
    }
}
