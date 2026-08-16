//
//  FreeDaysExportView.swift
//  ExportSchedule
//
//  「空いてる日」モードの表示内容。設定・判定・カレンダーでの修正・出力をまとめる。
//

import SwiftUI

struct FreeDaysExportView: View {
    @State private var viewModel = FreeDaysViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FreeDaysSettingsSectionView(viewModel: viewModel)

                Button {
                    Task {
                        await viewModel.generate()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("freeDays.action.export")
                            .padding()
                            .bold()
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                            .glassEffect(.regular.tint(.appBlue).interactive())
                    }
                }
                .disabled(viewModel.isLoading)

                if viewModel.hasGeneratedOnce {
                    FreeDaysCalendarView(viewModel: viewModel)
                }

                FreeDaysOutputSectionView(viewModel: viewModel)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
            // キーボード外をタップしたらキーボードを閉じる。
            .onAppear { KeyboardDismisser.install() }
#endif
#if os(macOS)
            .frame(minWidth: 420, minHeight: 560)
#endif
        }
        .background(.base)
    }
}

#Preview {
    FreeDaysExportView()
}
