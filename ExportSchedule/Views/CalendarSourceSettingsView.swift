//
//  CalendarSourceSettingsView.swift
//  ExportSchedule
//
//  「設定」タブの画面。予定の取得元（Apple カレンダー / Google カレンダー）を切り替える。
//

import SwiftUI

struct CalendarSourceSettingsView: View {
    @Bindable var viewModel: ScheduleViewModel

    /// カレンダーソース表示用のラベル。
    private func calendarSourceLabel(_ source: CalendarSource) -> LocalizedStringKey {
        switch source {
        case .apple: "settings.calendarSource.apple"
        case .google: "settings.calendarSource.google"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AppSection("settings.calendarSource.title") {
                        Picker("settings.calendarSource.title", selection: $viewModel.calendarSource) {
                            ForEach(CalendarSource.allCases, id: \.self) { source in
                                Text(calendarSourceLabel(source)).tag(source)
                            }
                        }
                        .pickerStyle(.automatic)
                        .tint(.primary)
                        .labelsHidden()
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(.base)
            .navigationTitle("content.tab.settings")
        }
    }
}

#Preview {
    CalendarSourceSettingsView(viewModel: ScheduleViewModel())
}
