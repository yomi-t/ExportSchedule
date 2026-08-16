//
//  CalendarSourceOnboardingView.swift
//  ExportSchedule
//
//  初回起動時に予定の取得元（Apple カレンダー / Google カレンダー）を選ばせる必須の画面。
//

import SwiftUI

struct CalendarSourceOnboardingView: View {
    @Bindable var viewModel: ScheduleViewModel
    let onComplete: () -> Void

    /// アクセス権限要求／アカウント連携の実行中かどうか。
    @State private var isRequestingAccess = false

    /// カレンダーソース表示用のラベル。
    private func calendarSourceLabel(_ source: CalendarSource) -> LocalizedStringKey {
        switch source {
        case .apple: "settings.calendarSource.apple"
        case .google: "settings.calendarSource.google"
        }
    }
    
    var body: some View {
        VStack(spacing: 48) {
            Text("onboarding.calendarSource.title")
                .font(.title2)
                .bold()
            
            HStack(spacing: 16) {
                Button {
                    viewModel.calendarSource = .apple
                } label:  {
                    VStack {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .padding(20)
                            .background(.section)
                            .cornerRadius(24)
                            .overlay(
                                viewModel.calendarSource == .apple ?
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.appGreen, lineWidth: 5) : nil
                            )
                        Text("settings.calendarSource.apple")
                            .bold()
                    }
                    .tint(.primary)
                }
                
                Button {
                    viewModel.calendarSource = .google
                } label: {
                    VStack {
                        Image("GoogleImage")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .padding(20)
                            .background(.section)
                            .cornerRadius(24)
                            .overlay(
                                viewModel.calendarSource == .google ?
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.appGreen, lineWidth: 5) : nil
                            )
                        Text("settings.calendarSource.google")
                            .bold()
                    }
                    .tint(.primary)
                }
            }
            
            Button {
                Task {
                    isRequestingAccess = true
                    await viewModel.requestInitialCalendarAccess()
                    isRequestingAccess = false
                    viewModel.completeInitialCalendarSourceSelection()
                    onComplete()
                }
            } label: {
                if isRequestingAccess {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("onboarding.calendarSource.confirm")
                        .padding()
                        .bold()
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .glassEffect(.regular.tint(.appBlue).interactive())
                }
            }
            .disabled(isRequestingAccess)

            Text("onboarding.calendarSource.description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.base)
    }
}

#Preview {
    CalendarSourceOnboardingView(viewModel: ScheduleViewModel()) {}
}
