//
//  DateRange.swift
//  ExportSchedule
//
//  絶対時刻の半開区間 [start, end) を表す共通の値型。
//  busy（予定）／free（空き）どちらの区間にも使う。
//

import Foundation

/// 絶対時刻の区間。`start` 以上 `end` 未満（半開区間）として扱う。
struct DateRange: Comparable, Sendable, Hashable {
    var start: Date
    var end: Date

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// 区間長（秒）。
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    /// 正の長さを持つか（start < end）。
    var isValid: Bool {
        end > start
    }

    /// 他の区間と時間的に重なるか（端点だけの接触は重なりとみなさない）。
    func overlaps(_ other: DateRange) -> Bool {
        start < other.end && other.start < end
    }

    static func < (lhs: DateRange, rhs: DateRange) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        return lhs.end < rhs.end
    }
}
