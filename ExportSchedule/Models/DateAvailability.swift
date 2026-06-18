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

    var id: Date { day }

    init(day: Date, freeIntervals: [DateRange]) {
        self.day = day
        self.freeIntervals = freeIntervals
    }

    /// 出力に表示すべき内容がある日か（終日OK もしくは空き区間が存在）。
    var hasOutput: Bool {
        !freeIntervals.isEmpty
    }
}
