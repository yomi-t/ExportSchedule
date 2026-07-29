//
//  SettingsSectionView.swift
//  ExportSchedule
//
//  期間・時間帯・最小スロットを編集する設定セクション。
//

import SwiftUI

struct SettingsSectionView: View {
    @Bindable var viewModel: ScheduleViewModel
    
    /// 曜日表示用（weekday 1...7 = 日〜土）。
    private var weekdayLabels: [String] {
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

    /// アプリの表示言語が日本語かどうか（日付・時刻の「漢字スタイル」を選択肢に含めるかの判定に使う）。
    private var isJapaneseLocale: Bool {
        Bundle.main.preferredLocalizations.first == "ja"
    }

    /// 日本語ロケールのときだけ「漢字スタイル」を選択肢に含める。
    private var availableDateStyles: [DateOutputStyle] {
        isJapaneseLocale ? DateOutputStyle.allCases : DateOutputStyle.allCases.filter { $0 != .kanji }
    }

    /// 日本語ロケールのときだけ「漢字スタイル」を選択肢に含める。
    private var availableTimeStyles: [TimeOutputStyle] {
        isJapaneseLocale ? TimeOutputStyle.allCases : TimeOutputStyle.allCases.filter { $0 != .kanji }
    }

    var body: some View {
        AppSection("settings.dateRange.title") {
            // ラベルはあらかじめ現在の表示言語で解決した String を渡す（DatePickerのString版initはLocalizedStringKeyとして
            // 再解決されないため、直後の .environment(\.locale:) が日付書式にのみ作用しラベルには影響しない）。
            DatePicker(String(localized: "settings.dateRange.start"), selection: $viewModel.settings.rangeStart, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            DatePicker(String(localized: "settings.dateRange.end"), selection: $viewModel.settings.rangeEnd, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
        AppSection("settings.weekdays.title") {
            HStack {
                ForEach(1...7, id: \.self) { weekday in
                    weekdayToggle(weekday)
                }
            }
        }

        AppSection("settings.timeRange.title") {
            DatePicker("settings.timeRange.start", selection: workingStartBinding, displayedComponents: .hourAndMinute)
            DatePicker("settings.timeRange.end", selection: workingEndBinding, displayedComponents: .hourAndMinute)
        }

        AppSection("settings.minimumSlot.title") {
            Stepper(value: $viewModel.settings.minimumSlotMinutes, in: 5...480, step: 5) {
                Text(String(format: String(localized: "settings.minimumSlot.label"), viewModel.settings.minimumSlotMinutes))
            }
        }

        AppSection("settings.buffer.title") {
            Stepper(value: $viewModel.settings.bufferMinutes, in: 0...240, step: 5) {
                Text(bufferLabel)
            }
        } footer: {
            Text("settings.buffer.footer")
        }

        AppSection("settings.outputFormat.title") {
            HStack {
                Text("settings.outputFormat.dateLabel")
                Spacer()
                Picker("settings.outputFormat.dateLabel", selection: $viewModel.outputFormat.dateStyle) {
                    ForEach(availableDateStyles, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.automatic)
                .tint(.primary)
                .backgroundStyle(.gray)
                .clipShape(.capsule)
            }
            HStack {
                Text("settings.outputFormat.timeLabel")
                Spacer()
                Picker("settings.outputFormat.timeLabel", selection: $viewModel.outputFormat.timeStyle) {
                    ForEach(availableTimeStyles, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            Toggle("settings.outputFormat.zeroPadded", isOn: $viewModel.outputFormat.zeroPadded)
        } footer: {
            Text(String(format: String(localized: "settings.outputFormat.exampleLabel"), previewSample))
        }
        
        
    }
    
    /// 例: "前後 30 分" / "前後 1 時間 30 分" / "0 分（なし）"。
    private var bufferLabel: String {
        let minutes = viewModel.settings.bufferMinutes
        if minutes == 0 {
            return String(localized: "settings.buffer.none")
        }
        let hours = minutes / 60
        let mins = minutes % 60
        switch (hours > 0, mins > 0) {
        case (true, true):
            return String(format: String(localized: "settings.buffer.hoursAndMinutes"), hours, mins)
        case (true, false):
            return String(format: String(localized: "settings.buffer.hoursOnly"), hours)
        default:
            return String(format: String(localized: "settings.buffer.minutesOnly"), mins)
        }
    }
    
    /// 出力形式のプレビュー（固定のサンプル日時：7月6日9時5分〜18時0分）。
    private var previewSample: String {
        let formatter = ScheduleTextFormatter()
        let calendar = viewModel.settings.calendar
        let sampleDate = calendar.date(bySettingHour: 9, minute: 5, second: 0, of: calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: DateComponents(year: 2024, month: 7, day: 6)) ?? Date()) ?? Date()) ?? Date()
        let sampleEndDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: DateComponents(year: 2024, month: 7, day: 6)) ?? Date()) ?? Date()) ?? Date()
        let dateStr = formatter.dateText(for: sampleDate, calendar: calendar, outputFormat: viewModel.outputFormat)
        let timeStartStr = formatter.timeText(for: sampleDate, calendar: calendar, outputFormat: viewModel.outputFormat)
        let timeEndStr = formatter.timeText(for: sampleEndDate, calendar: calendar, outputFormat: viewModel.outputFormat)
        return "\(dateStr) \(timeStartStr)〜\(timeEndStr)"
    }
    
    // MARK: - 曜日トグル
    
    private func weekdayToggle(_ weekday: Int) -> some View {
        let isOn = viewModel.settings.weeklyWorkingHours.hoursByWeekday[weekday] != nil
        return Button {
            toggleWeekday(weekday)
        } label: {
            Text(weekdayLabels[weekday - 1])
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .glassEffect(.regular.tint(isOn ? .appBlue : .clear), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func toggleWeekday(_ weekday: Int) {
        var map = viewModel.settings.weeklyWorkingHours.hoursByWeekday
        if map[weekday] != nil {
            map[weekday] = nil
        } else {
            map[weekday] = representativeHours
        }
        viewModel.settings.weeklyWorkingHours.hoursByWeekday = map
    }
    
    // MARK: - 時間帯バインディング
    
    /// 現在の代表的な時間帯（有効曜日のうち最小 weekday のもの、なければデフォルト）。
    private var representativeHours: WorkingHours {
        let map = viewModel.settings.weeklyWorkingHours.hoursByWeekday
        if let key = map.keys.sorted().first, let hours = map[key] {
            return hours
        }
        return WorkingHours(start: TimeOfDay(hour: 10, minute: 0),
                            end: TimeOfDay(hour: 18, minute: 0))
    }
    
    private var workingStartBinding: Binding<Date> {
        timeBinding(keyPath: \.start)
    }
    
    private var workingEndBinding: Binding<Date> {
        timeBinding(keyPath: \.end)
    }
    
    /// すべての有効曜日に共通の開始/終了時刻を読み書きするバインディング。
    private func timeBinding(keyPath: WritableKeyPath<WorkingHours, TimeOfDay>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let time = representativeHours[keyPath: keyPath]
                return dateFrom(time: time)
            },
            set: { newDate in
                let calendar = viewModel.settings.calendar
                let comps = calendar.dateComponents([.hour, .minute], from: newDate)
                let newTime = TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
                var map = viewModel.settings.weeklyWorkingHours.hoursByWeekday
                for key in map.keys {
                    map[key]?[keyPath: keyPath] = newTime
                }
                viewModel.settings.weeklyWorkingHours.hoursByWeekday = map
            }
        )
    }
    
    /// TimeOfDay を本日基準の Date へ変換（DatePicker 表示用）。
    private func dateFrom(time: TimeOfDay) -> Date {
        let calendar = viewModel.settings.calendar
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
    }
}

#Preview {
    ContentView()
}
