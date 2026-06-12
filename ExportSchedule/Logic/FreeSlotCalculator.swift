//
//  FreeSlotCalculator.swift
//  ExportSchedule
//
//  予定（BusyInterval）・期間・営業時間・最小スロットから、日ごとの空き時間を計算する純粋ロジック。
//  EventKit には一切依存せず、Foundation のみで完結するためテスト可能。
//

import Foundation

struct FreeSlotCalculator {

    /// 日ごとの空き状況を計算する。
    /// - Parameters:
    ///   - busyIntervals: 予定の一覧（`.free` 扱いの予定は除外済みであること）。
    ///   - settings: ユーザー設定（期間・営業時間・最小分など）。
    ///   - calendar: 日付計算に用いるカレンダー（`timeZone` は settings と一致させること）。
    /// - Returns: 稼働日ごとの空き状況（非稼働日・表示すべき内容のない日は含まない）。
    func computeAvailability(busyIntervals: [BusyInterval],
                            settings: FreeSlotSettings,
                            calendar: Calendar) -> [DateAvailability] {
        // 1. 正規化：終日予定はそのまま保持し、それ以外は正の長さのものだけ残す。
        let normalized = busyIntervals.filter { $0.isAllDay || $0.range.isValid }

        // 2. 通常予定の絶対時刻区間を、前後バッファ分だけ広げてからマージ（終日予定は別途扱う）。
        //    バッファにより、予定の直前・直後に空きが生じないようにする。
        let buffer = TimeInterval(max(0, settings.bufferMinutes) * 60)
        let timedRanges = normalized.filter { !$0.isAllDay }.map { interval -> DateRange in
            DateRange(start: interval.start.addingTimeInterval(-buffer),
                      end: interval.end.addingTimeInterval(buffer))
        }
        let mergedBusy = Self.mergeRanges(timedRanges)

        // 終日予定が占有する日（startOfDay）の集合。
        let allDayDays: Set<Date> = Set(
            normalized.filter { $0.isAllDay }.flatMap { interval -> [Date] in
                daysCovered(by: interval, calendar: calendar)
            }
        )

        // 3. 期間内の各日を列挙。
        var result: [DateAvailability] = []
        let firstDay = calendar.startOfDay(for: settings.rangeStart)
        let lastDay = calendar.startOfDay(for: settings.rangeEnd)
        guard firstDay <= lastDay else { return result }

        var day = firstDay
        while day <= lastDay {
            defer {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? lastDay.addingTimeInterval(86_400 * 2)
            }

            // 4. 営業ウィンドウを構築（非稼働日はスキップ）。
            let weekday = calendar.component(.weekday, from: day)
            guard let workingHours = settings.weeklyWorkingHours.workingHours(forWeekday: weekday),
                  let window = workingWindow(for: day, hours: workingHours, calendar: calendar),
                  window.isValid else {
                continue
            }

            // 終日予定がある日は営業ウィンドウ全体が埋まる扱い。
            if allDayDays.contains(day) {
                result.append(DateAvailability(day: day, freeIntervals: [], isFullyFree: false))
                continue
            }

            // 5. ウィンドウからマージ済み予定を差し引く。
            let intersecting = mergedBusy.filter { $0.overlaps(window) }
            let rawFree = Self.subtract(busy: intersecting, from: window)
            let isFullyFree = intersecting.isEmpty

            // 6. 最小スロットでフィルタ。
            let minimumSeconds = TimeInterval(settings.minimumSlotMinutes * 60)
            let filtered = rawFree.filter { $0.duration >= minimumSeconds }

            result.append(DateAvailability(day: day, freeIntervals: filtered, isFullyFree: isFullyFree))
        }

        return result
    }

    // MARK: - 営業ウィンドウ

    /// 指定日の営業時間を絶対時刻区間に変換する。`end <= start` の場合は翌日にまたぐ夜間シフトとして扱う。
    private func workingWindow(for day: Date, hours: WorkingHours, calendar: Calendar) -> DateRange? {
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
