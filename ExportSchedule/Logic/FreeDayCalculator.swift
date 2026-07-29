//
//  FreeDayCalculator.swift
//  ExportSchedule
//
//  期間・時間帯・予定から、その時間帯がまるごと空いている「日」を抽出する純粋ロジック。
//  EventKit には一切依存せず、Foundation のみで完結するためテスト可能。
//

import Foundation

struct FreeDayCalculator {

    private let calculator = FreeSlotCalculator()

    /// 日ごとの表示用スケジュール（候補ウィンドウ・既存予定を含む）を計算する。
    /// カレンダーUIでの予定表示（ドット・ポップオーバー）に用いる。
    /// - Parameters:
    ///   - busyIntervals: 予定の一覧（`.free` 扱いの予定は除外済みであること）。
    ///   - settings: ユーザー設定（期間・時間帯など）。
    ///   - calendar: 日付計算に用いるカレンダー（`timeZone` は settings と一致させること）。
    func computeDaySchedules(busyIntervals: [BusyInterval],
                            settings: FreeDaySettings,
                            calendar: Calendar) -> [DaySchedule] {
        let slotSettings = FreeSlotSettings(
            rangeStart: settings.rangeStart,
            rangeEnd: settings.rangeEnd,
            weeklyWorkingHours: .everyDay(settings.timeWindow),
            minimumSlotMinutes: 1,
            bufferMinutes: 0,
            timeZoneIdentifier: settings.timeZoneIdentifier
        )
        return calculator.computeDaySchedules(busyIntervals: busyIntervals,
                                              settings: slotSettings,
                                              calendar: calendar)
    }

    /// 指定した時間帯がまるごと空いている日の一覧（startOfDay）を計算する。
    func computeFreeDays(busyIntervals: [BusyInterval],
                        settings: FreeDaySettings,
                        calendar: Calendar) -> [Date] {
        computeDaySchedules(busyIntervals: busyIntervals, settings: settings, calendar: calendar)
            .filter { schedule in
                schedule.freeIntervals.count == 1
                    && schedule.freeIntervals[0].start == schedule.window.start
                    && schedule.freeIntervals[0].end == schedule.window.end
            }
            .map { $0.day }
    }

    /// 予定を日付（startOfDay）ごとにグルーピングする。判定用の時間帯とは無関係に、
    /// その日に重なる予定をすべて含める（カレンダーUIのドット・ポップオーバー表示に使う）。
    func eventsByDay(busyIntervals: [BusyInterval], calendar: Calendar) -> [Date: [BusyInterval]] {
        var result: [Date: [BusyInterval]] = [:]
        for event in busyIntervals {
            for day in calculator.daysCovered(by: event, calendar: calendar) {
                result[day, default: []].append(event)
            }
        }
        for day in result.keys {
            result[day]?.sort()
        }
        return result
    }
}
