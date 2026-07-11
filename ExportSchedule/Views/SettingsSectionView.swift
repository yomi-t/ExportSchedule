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
    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        AppSection("期間") {
            DatePicker("開始", selection: $viewModel.settings.rangeStart, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            DatePicker("終了", selection: $viewModel.settings.rangeEnd, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
        AppSection("曜日") {
            HStack {
                ForEach(1...7, id: \.self) { weekday in
                    weekdayToggle(weekday)
                }
            }
        }
        
        AppSection("時間帯") {
            DatePicker("開始", selection: workingStartBinding, displayedComponents: .hourAndMinute)
            DatePicker("終了", selection: workingEndBinding, displayedComponents: .hourAndMinute)
        }
        
        AppSection("最小予定時間") {
            Stepper(value: $viewModel.settings.minimumSlotMinutes, in: 5...480, step: 5) {
                Text("\(viewModel.settings.minimumSlotMinutes) 分以上")
            }
        }
        
        AppSection("予定の前後の空け時間") {
            Stepper(value: $viewModel.settings.bufferMinutes, in: 0...240, step: 5) {
                Text(bufferLabel)
            }
        } footer: {
            Text("各予定の前後にこの時間を確保し、予定の直後・直前に空きが入らないようにします。")
        }
        
        
    }
    
    /// 例: "前後 30 分" / "前後 1 時間 30 分" / "0 分（なし）"。
    private var bufferLabel: String {
        let minutes = viewModel.settings.bufferMinutes
        if minutes == 0 {
            return "0 分（なし）"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        var parts = "前後 "
        if hours > 0 { parts += "\(hours) 時間" }
        if mins > 0 { parts += "\(mins) 分" }
        return parts
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
