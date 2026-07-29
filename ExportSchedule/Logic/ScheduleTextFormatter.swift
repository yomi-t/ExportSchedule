//
//  ScheduleTextFormatter.swift
//  ExportSchedule
//
//  空き状況（DateAvailability）を日本語の読みやすいテキストへ整形する純粋ロジック。
//

import Foundation

struct ScheduleTextFormatter {

    private static var weekdaySymbols: [String] {
        [
            String(localized: "weekday.sunday"),
            String(localized: "weekday.monday"),
            String(localized: "weekday.tuesday"),
            String(localized: "weekday.wednesday"),
            String(localized: "weekday.thursday"),
            String(localized: "weekday.friday"),
            String(localized: "weekday.saturday"),
        ]
    }

    func format(_ availability: [DateAvailability],
                calendar: Calendar,
                outputFormat: TextOutputFormat = TextOutputFormat()) -> String {
        availability
            .filter { $0.hasOutput }
            .map { line(for: $0, calendar: calendar, outputFormat: outputFormat) }
            .joined(separator: "\n")
    }

    // MARK: - 1日分の整形

    private func line(for availability: DateAvailability,
                      calendar: Calendar,
                      outputFormat: TextOutputFormat) -> String {
        let prefix = dateText(for: availability.day, calendar: calendar, outputFormat: outputFormat)
        let ranges = availability.freeIntervals
            .map { timeRangeText(for: $0, calendar: calendar, outputFormat: outputFormat) }
            .joined(separator: ", ")
        return "\(prefix) \(ranges)"
    }

    func dateText(for day: Date,
                  calendar: Calendar,
                  outputFormat: TextOutputFormat = TextOutputFormat()) -> String {
        let month = calendar.component(.month, from: day)
        let dayOfMonth = calendar.component(.day, from: day)
        let weekday = calendar.component(.weekday, from: day)
        let symbol = Self.weekdaySymbols[(weekday - 1) % 7]

        let monthStr = outputFormat.zeroPadded ? String(format: "%02d", month) : "\(month)"
        let dayStr = outputFormat.zeroPadded ? String(format: "%02d", dayOfMonth) : "\(dayOfMonth)"

        switch outputFormat.dateStyle {
        case .slash:
            return "\(monthStr)/\(dayStr)(\(symbol))"
        case .kanji:
            return "\(monthStr)月\(dayStr)日(\(symbol))"
        }
    }

    private func timeRangeText(for range: DateRange,
                               calendar: Calendar,
                               outputFormat: TextOutputFormat) -> String {
        "\(timeText(for: range.start, calendar: calendar, outputFormat: outputFormat))〜\(timeText(for: range.end, calendar: calendar, outputFormat: outputFormat))"
    }

    func timeText(for date: Date,
                  calendar: Calendar,
                  outputFormat: TextOutputFormat = TextOutputFormat()) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let hourStr = outputFormat.zeroPadded ? String(format: "%02d", hour) : "\(hour)"
        let minuteStr = String(format: "%02d", minute)

        switch outputFormat.timeStyle {
        case .colon:
            return "\(hourStr):\(minuteStr)"
        case .kanji:
            return "\(hourStr)時\(minuteStr)分"
        }
    }
}
