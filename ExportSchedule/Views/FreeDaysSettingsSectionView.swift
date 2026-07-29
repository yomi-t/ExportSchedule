//
//  FreeDaysSettingsSectionView.swift
//  ExportSchedule
//
//  「空いてる日」モードの期間・時間帯・出力形式を編集する設定セクション。
//

import SwiftUI

struct FreeDaysSettingsSectionView: View {
    @Bindable var viewModel: FreeDaysViewModel

    /// アプリの表示言語が日本語かどうか（日付の「漢字スタイル」を選択肢に含めるかの判定に使う）。
    private var isJapaneseLocale: Bool {
        Bundle.main.preferredLocalizations.first == "ja"
    }

    /// 日本語ロケールのときだけ「漢字スタイル」を選択肢に含める。
    private var availableDateStyles: [DateOutputStyle] {
        isJapaneseLocale ? DateOutputStyle.allCases : DateOutputStyle.allCases.filter { $0 != .kanji }
    }

    var body: some View {
        AppSection("freeDays.settings.dateRange.title") {
            // ラベルはあらかじめ現在の表示言語で解決した String を渡す（DatePickerのString版initはLocalizedStringKeyとして
            // 再解決されないため、直後の .environment(\.locale:) が日付書式にのみ作用しラベルには影響しない）。
            DatePicker(String(localized: "freeDays.settings.dateRange.start"), selection: $viewModel.settings.rangeStart, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            DatePicker(String(localized: "freeDays.settings.dateRange.end"), selection: $viewModel.settings.rangeEnd, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }

        AppSection("freeDays.settings.timeWindow.title") {
            DatePicker("freeDays.settings.timeWindow.start", selection: timeWindowStartBinding, displayedComponents: .hourAndMinute)
            DatePicker("freeDays.settings.timeWindow.end", selection: timeWindowEndBinding, displayedComponents: .hourAndMinute)
        }

        AppSection("freeDays.settings.outputFormat.title") {
            HStack {
                Text("freeDays.settings.outputFormat.dateLabel")
                Spacer()
                Picker("freeDays.settings.outputFormat.dateLabel", selection: $viewModel.outputFormat.dateStyle) {
                    ForEach(availableDateStyles, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            Toggle("freeDays.settings.outputFormat.zeroPadded", isOn: $viewModel.outputFormat.zeroPadded)
        }
    }

    // MARK: - 時間帯バインディング

    private var timeWindowStartBinding: Binding<Date> {
        timeBinding(keyPath: \.start)
    }

    private var timeWindowEndBinding: Binding<Date> {
        timeBinding(keyPath: \.end)
    }

    private func timeBinding(keyPath: WritableKeyPath<WorkingHours, TimeOfDay>) -> Binding<Date> {
        Binding<Date>(
            get: {
                dateFrom(time: viewModel.settings.timeWindow[keyPath: keyPath])
            },
            set: { newDate in
                let calendar = viewModel.settings.calendar
                let comps = calendar.dateComponents([.hour, .minute], from: newDate)
                let newTime = TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
                viewModel.settings.timeWindow[keyPath: keyPath] = newTime
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
    FreeDaysExportView()
}
