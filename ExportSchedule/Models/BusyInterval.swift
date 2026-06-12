//
//  BusyInterval.swift
//  ExportSchedule
//
//  予定（埋まっている時間）を表す EventKit 非依存の値型。
//  サービス層が EKEvent からこの型へ変換し、計算ロジックへ渡す。
//

import Foundation

/// 1件の予定が占有する時間。`.free` 扱いの予定はサービス層で除外済みであることを前提とする。
struct BusyInterval: Comparable, Sendable, Hashable {
    var start: Date
    var end: Date
    /// 終日予定かどうか。終日予定はその日の営業時間全体を埋める扱いにする。
    var isAllDay: Bool

    init(start: Date, end: Date, isAllDay: Bool = false) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    /// 絶対時刻区間としての表現。
    var range: DateRange {
        DateRange(start: start, end: end)
    }

    static func < (lhs: BusyInterval, rhs: BusyInterval) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        return lhs.end < rhs.end
    }
}
