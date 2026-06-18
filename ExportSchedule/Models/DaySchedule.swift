//
//  DaySchedule.swift
//  ExportSchedule
//
//  1稼働日あたりの「時間帯枠・候補（空き）区間・既存の予定」をまとめた UI 表示用モデル。
//  候補日タイムラインのプレビュー描画に用いる。
//

import Foundation

/// 1稼働日の表示用スケジュール。候補ウィンドウ上に候補（空き）と既存予定を重ねて描画するために使う。
struct DaySchedule: Identifiable, Hashable, Sendable {
    /// その日の 0:00（startOfDay）。
    let day: Date
    /// 時間帯の絶対時刻区間（タイムラインの全幅に相当）。
    let window: DateRange
    /// 候補として提示する空き区間（最小スロット条件を満たすもの・時系列順）。
    /// プレビュー上でドラッグ編集できるよう可変にしている。
    var freeIntervals: [DateRange]
    /// この日に交差する既存の予定（元の時刻のまま・時系列順）。終日予定を含む。
    let events: [BusyInterval]

    var id: Date { day }

    init(day: Date, window: DateRange, freeIntervals: [DateRange], events: [BusyInterval]) {
        self.day = day
        self.window = window
        self.freeIntervals = freeIntervals
        self.events = events
    }
}
