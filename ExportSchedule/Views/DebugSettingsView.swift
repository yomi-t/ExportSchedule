//
//  DebugSettingsView.swift
//  ExportSchedule
//
//  DEBUG ビルド専用の開発者向け設定画面。
//

#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AppSection {
                        Toggle("debug.calendarSourceOnboarding.toggle", isOn: $viewModel.hasCompletedInitialCalendarSourceSelection)
                    } header: {
                        Text("debug.calendarSourceOnboarding.title")
                    } footer: {
                        Text("debug.calendarSourceOnboarding.footer")
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(.base)
            .navigationTitle("content.tab.debug")
        }
    }
}

#Preview {
    DebugSettingsView(viewModel: ScheduleViewModel())
}
#endif
