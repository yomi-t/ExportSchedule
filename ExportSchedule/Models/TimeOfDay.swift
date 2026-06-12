//
//  TimeOfDay.swift
//  ExportSchedule
//
//  時刻（時:分）を表すカレンダー非依存の値型。
//

import Foundation

/// 1日の中の時刻（時・分）。日付を持たず、営業時間の境界などに使う。
struct TimeOfDay: Comparable, Codable, Sendable, Hashable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// 0:00 からの経過分。
    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
