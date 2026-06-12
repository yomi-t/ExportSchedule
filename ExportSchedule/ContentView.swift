//
//  ContentView.swift
//  ExportSchedule
//
//  ルート画面。設定の編集・空き時間の生成・出力表示をまとめる。
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        Form {
            SettingsSectionView(viewModel: viewModel)

            Section {
                Button {
                    Task { await viewModel.generate() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("空き時間を生成")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            } footer: {
                Text("カレンダーの変更の反映には時間がかかることがあります。生成前にカレンダーアプリを開いておくと、最新の予定が反映されやすくなります。")
            }

            OutputSectionView(viewModel: viewModel)
        }
        .formStyle(.grouped)
        .navigationTitle("空き時間の書き出し")
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }
}

#Preview {
    ContentView()
}
