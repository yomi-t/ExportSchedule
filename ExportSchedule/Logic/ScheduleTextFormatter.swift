//
//  ScheduleTextFormatter.swift
//  ExportSchedule
//
//  空き状況（DateAvailability）を日本語の読みやすいテキストへ整形する純粋ロジック。
//

import Foundation

struct ScheduleTextFormatter {

    /// Calendar weekday(1...7) に対応する日本語の曜日記号。
    private static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    /// 空き状況一覧を1つのテキストへ整形する。
    /// 出力例:
    /// ```
    /// 6/15(月) 10:00〜12:00, 14:00〜18:00
    /// 6/16(火) 終日OK
    /// ```
    /// 表示すべき内容のない日（空きなし）は出力に含めない。
    func format(_ availability: [DateAvailability], calendar: Calendar) -> String {
        availability
            .filter { $0.hasOutput }
            .map { line(for: $0, calendar: calendar) }
            .joined(separator: "\n")
    }

    // MARK: - 1日分の整形

    private func line(for availability: DateAvailability, calendar: Calendar) -> String {
        let prefix = datePrefix(for: availability.day, calendar: calendar)
        let ranges = availability.freeIntervals
            .map { timeRangeText(for: $0, calendar: calendar) }
            .joined(separator: ", ")
        return "\(prefix) \(ranges)"
    }

    /// 例: "6/15(月)"
    private func datePrefix(for day: Date, calendar: Calendar) -> String {
        let month = calendar.component(.month, from: day)
        let dayOfMonth = calendar.component(.day, from: day)
        let weekday = calendar.component(.weekday, from: day) // 1...7
        let symbol = Self.weekdaySymbols[(weekday - 1) % 7]
        return "\(month)/\(dayOfMonth)(\(symbol))"
    }

    /// 例: "10:00〜12:00"（時は非ゼロ埋め、分はゼロ埋め、区切りは U+301C）。
    private func timeRangeText(for range: DateRange, calendar: Calendar) -> String {
        "\(timeText(for: range.start, calendar: calendar))〜\(timeText(for: range.end, calendar: calendar))"
    }

    private func timeText(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%d:%02d", hour, minute)
    }
}
