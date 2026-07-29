//
//  FreeDaysCalendarView.swift
//  ExportSchedule
//
//  「空いてる日」の判定結果を月表示のカレンダーでプレビューし、
//  日付をタップして出力対象を修正できるセクション。
//

import SwiftUI

struct FreeDaysCalendarView: View {
    @Bindable var viewModel: FreeDaysViewModel

    private var calendar: Calendar { viewModel.settings.calendar }

    private var weekdaySymbols: [String] {
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

    var body: some View {
        AppSection {
            ForEach(monthsInRange, id: \.self) { month in
                monthBlock(for: month)
            }
        } header: {
            Text("freeDays.calendar.title")
        } footer: {
            Text("freeDays.calendar.hint")
        }
    }

    private func monthBlock(for month: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel(for: month))
                .font(.headline)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(days(in: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day,
                               isSelected: viewModel.selectedFreeDays.contains(calendar.startOfDay(for: day)),
                               events: viewModel.eventsByDay[calendar.startOfDay(for: day)] ?? [],
                               calendar: calendar) {
                            viewModel.toggleDay(day)
                        }
                    } else {
                        Color.clear.frame(minHeight: 36)
                    }
                }
            }
        }
    }

    // MARK: - 対象期間内の月グリッド

    /// 対象期間（`rangeStart`〜`rangeEnd`）が含む月の一覧（各月の1日）。月が変わるごとに下へ続けて表示する。
    private var monthsInRange: [Date] {
        guard let startMonth = calendar.dateInterval(of: .month, for: viewModel.settings.rangeStart)?.start,
              let endMonth = calendar.dateInterval(of: .month, for: viewModel.settings.rangeEnd)?.start,
              startMonth <= endMonth else {
            return []
        }
        var months: [Date] = []
        var current = startMonth
        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months
    }

    /// 指定した月の日付一覧。月初のオフセット分と対象期間外の日は `nil` で埋め、対象期間内の日だけを表示する。
    private func days(in month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }
        let firstOfMonth = monthInterval.start
        let leadingEmptyCount = calendar.component(.weekday, from: firstOfMonth) - 1
        let rangeStart = calendar.startOfDay(for: viewModel.settings.rangeStart)
        let rangeEnd = calendar.startOfDay(for: viewModel.settings.rangeEnd)
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        for offset in range {
            guard let date = calendar.date(byAdding: .day, value: offset - 1, to: firstOfMonth) else { continue }
            days.append(date >= rangeStart && date <= rangeEnd ? date : nil)
        }
        // 対象期間の日を1つも含まない週（行）は、余白として残らないよう取り除く。
        return stride(from: 0, to: days.count, by: 7)
            .map { Array(days[$0..<min($0 + 7, days.count)]) }
            .filter { week in week.contains { $0 != nil } }
            .flatMap { $0 }
    }

    private func monthLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: month)
    }
}

// MARK: - 日付セル（タップで選択切替、長押しで予定をポップオーバー表示）

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let events: [BusyInterval]
    let calendar: Calendar
    let onTap: () -> Void

    @State private var isShowingDetail = false

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: day))")
                .frame(maxWidth: .infinity)
            Circle()
                .frame(width: 4, height: 4)
                .foregroundStyle(events.isEmpty ? .clear : (isSelected ? Color.white : Color.appBlue))
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 36)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .glassEffect(.regular.tint(isSelected ? .appBlue : .clear), in: .rect(cornerRadius: 8))
        .onTapGesture { onTap() }
        .onLongPressGesture {
            guard !events.isEmpty else { return }
            isShowingDetail = true
        }
        .popover(isPresented: $isShowingDetail) {
            detail
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(trigger: isShowingDetail) { _, isShowing in
            isShowing ? .impact : nil
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title.isEmpty ? String(localized: "event.untitled") : event.title)
                        .font(.headline)
                    Label(timeRangeText(for: event), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if index < events.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .frame(minWidth: 180, alignment: .leading)
    }

    private func timeRangeText(for event: BusyInterval) -> String {
        if event.isAllDay {
            return String(localized: "event.allDay")
        }
        let formatter = ScheduleTextFormatter()
        return "\(formatter.timeText(for: event.start, calendar: calendar))〜\(formatter.timeText(for: event.end, calendar: calendar))"
    }
}

#Preview {
    FreeDaysExportView()
}
