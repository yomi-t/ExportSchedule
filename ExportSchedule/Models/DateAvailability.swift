//
//  DateAvailability.swift
//  ExportSchedule
//
//  1日あたりの空き状況（計算結果）。
//

import Foundation

/// 1稼働日における空き時間の計算結果。
struct DateAvailability: Sendable, Hashable, Identifiable {
    /// その日の 0:00（startOfDay）。
    let day: Date
    /// 最小スロット条件を満たす空き区間の一覧（時系列順）。
    let freeIntervals: [DateRange]
    /// 営業時間全体が空いている（予定が一切交差していない）か。出力の「終日OK」判定に使う。
    let isFullyFree: Bool

    var id: Date { day }

    init(day: Date, freeIntervals: [DateRange], isFullyFree: Bool) {
        self.day = day
        self.freeIntervals = freeIntervals
        self.isFullyFree = isFullyFree
    }

    /// 出力に表示すべき内容がある日か（終日OK もしくは空き区間が存在）。
    var hasOutput: Bool {
        isFullyFree || !freeIntervals.isEmpty
    }
}
