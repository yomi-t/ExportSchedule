//
//  FreeSlotCalculator.swift
//  ExportSchedule
//
//  予定（BusyInterval）・期間・時間帯・最小スロットから、日ごとの空き時間を計算する純粋ロジック。
//  EventKit には一切依存せず、Foundation のみで完結するためテスト可能。
//

import Foundation

struct FreeSlotCalculator {

    /// 日ごとの空き状況を計算する。
    /// - Parameters:
    ///   - busyIntervals: 予定の一覧（`.free` 扱いの予定は除外済みであること）。
    ///   - settings: ユーザー設定（期間・時間帯・最小分など）。
    ///   - calendar: 日付計算に用いるカレンダー（`timeZone` は settings と一致させること）。
    /// - Returns: 稼働日ごとの空き状況（非稼働日は含まない）。
    func computeAvailability(busyIntervals: [BusyInterval],
                            settings: FreeSlotSettings,
                            calendar: Calendar) -> [DateAvailability] {
        computeDaySchedules(busyIntervals: busyIntervals, settings: settings, calendar: calendar)
            .map { DateAvailability(day: $0.day, freeIntervals: $0.freeIntervals) }
    }

    /// 日ごとの表示用スケジュール（候補ウィンドウ・候補区間・既存予定）を計算する。
    /// 空き時間の算出ロジックは `computeAvailability` と共通で、加えて UI 描画に必要な
    /// 候補ウィンドウと（バッファ適用前の）既存予定を保持する。
    func computeDaySchedules(busyIntervals: [BusyInterval],
                             settings: FreeSlotSettings,
                             calendar: Calendar) -> [DaySchedule] {
        // 1. 正規化：終日予定はそのまま保持し、それ以外は正の長さのものだけ残す。
        let normalized = busyIntervals.filter { $0.isAllDay || $0.range.isValid }
        let timedEvents = normalized.filter { !$0.isAllDay }
        let allDayEvents = normalized.filter { $0.isAllDay }

        // 2. 通常予定の絶対時刻区間を、前後バッファ分だけ広げてからマージ（終日予定は別途扱う）。
        //    バッファにより、予定の直前・直後に空きが生じないようにする。
        let buffer = TimeInterval(max(0, settings.bufferMinutes) * 60)
        let timedRanges = timedEvents.map { interval -> DateRange in
            DateRange(start: interval.start.addingTimeInterval(-buffer),
                      end: interval.end.addingTimeInterval(buffer))
        }
        let mergedBusy = Self.mergeRanges(timedRanges)

        // 3. 期間内の各日を列挙。
        var result: [DaySchedule] = []
        let firstDay = calendar.startOfDay(for: settings.rangeStart)
        let lastDay = calendar.startOfDay(for: settings.rangeEnd)
        guard firstDay <= lastDay else { return result }

        var day = firstDay
        while day <= lastDay {
            defer {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? lastDay.addingTimeInterval(86_400 * 2)
            }

            // 4. 候補ウィンドウを構築（非稼働日はスキップ）。
            let weekday = calendar.component(.weekday, from: day)
            guard let workingHours = settings.weeklyWorkingHours.workingHours(forWeekday: weekday),
                  let window = Self.workingWindow(for: day, hours: workingHours, calendar: calendar),
                  window.isValid else {
                continue
            }

            // この日を覆う終日予定。
            let allDayForDay = allDayEvents.filter { daysCovered(by: $0, calendar: calendar).contains(day) }
            // 候補ウィンドウと交差する時間指定予定（表示用に元の時刻のまま保持）。
            let timedForDay = timedEvents.filter { $0.range.overlaps(window) }.sorted()
            let events = (allDayForDay + timedForDay).sorted()

            // 終日予定がある日は候補ウィンドウ全体が埋まる扱い。
            if !allDayForDay.isEmpty {
                result.append(DaySchedule(day: day, window: window, freeIntervals: [], events: events))
                continue
            }

            // 5. ウィンドウからマージ済み予定を差し引く。
            let intersecting = mergedBusy.filter { $0.overlaps(window) }
            let rawFree = Self.subtract(busy: intersecting, from: window)

            // 6. 最小スロットでフィルタ。
            let minimumSeconds = TimeInterval(settings.minimumSlotMinutes * 60)
            let filtered = rawFree.filter { $0.duration >= minimumSeconds }

            result.append(DaySchedule(day: day, window: window, freeIntervals: filtered, events: events))
        }

        return result
    }

    // MARK: - 候補ウィンドウ

    /// 指定日の時間帯を絶対時刻区間に変換する。`end <= start` の場合は翌日にまたぐ夜間シフトとして扱う。
    static func workingWindow(for day: Date, hours: WorkingHours, calendar: Calendar) -> DateRange? {
        guard let start = calendar.date(bySettingHour: hours.start.hour,
                                        minute: hours.start.minute,
                                        second: 0,
                                        of: day) else {
            return nil
        }
        guard var end = calendar.date(bySettingHour: hours.end.hour,
                                      minute: hours.end.minute,
                                      second: 0,
                                      of: day) else {
            return nil
        }
        if end <= start {
            // 夜間シフト（例: 22:00〜06:00）。終端を翌日へ。
            guard let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: end) else { return nil }
            end = nextDayEnd
        }
        return DateRange(start: start, end: end)
    }

    /// 終日予定が覆う日（startOfDay）の一覧を返す。
    private func daysCovered(by interval: BusyInterval, calendar: Calendar) -> [Date] {
        let firstDay = calendar.startOfDay(for: interval.start)
        // 終日予定は end が排他的（翌日0:00）であることが多いので、end ちょうどの日は含めない。
        let lastInstant = interval.end > interval.start ? interval.end.addingTimeInterval(-1) : interval.start
        let lastDay = calendar.startOfDay(for: lastInstant)
        guard firstDay <= lastDay else { return [firstDay] }
        var days: [Date] = []
        var d = firstDay
        while d <= lastDay {
            days.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return days
    }

    // MARK: - 区間演算（static・純粋）

    /// 重なり・隣接する区間を統合する。
    static func mergeRanges(_ ranges: [DateRange]) -> [DateRange] {
        let sorted = ranges.filter { $0.isValid }.sorted()
        guard !sorted.isEmpty else { return [] }

        var merged: [DateRange] = [sorted[0]]
        for current in sorted.dropFirst() {
            let lastIndex = merged.count - 1
            if current.start <= merged[lastIndex].end {
                // 重なり or 隣接 → 終端を延長。
                merged[lastIndex].end = max(merged[lastIndex].end, current.end)
            } else {
                merged.append(current)
            }
        }
        return merged
    }

    /// ウィンドウから複数の予定区間を差し引いた空き区間を返す。
    /// `busy` はウィンドウと交差するもののみを渡す前提（マージ済みでなくても可）。
    static func subtract(busy: [DateRange], from window: DateRange) -> [DateRange] {
        let mergedBusy = mergeRanges(busy)
        var free: [DateRange] = []
        var cursor = window.start

        for block in mergedBusy {
            let blockStart = max(block.start, window.start)
            let blockEnd = min(block.end, window.end)
            guard blockStart < blockEnd else { continue } // ウィンドウ外
            if blockStart > cursor {
                free.append(DateRange(start: cursor, end: blockStart))
            }
            cursor = max(cursor, blockEnd)
        }

        if cursor < window.end {
            free.append(DateRange(start: cursor, end: window.end))
        }

        return free
    }
}
