//
//  ContentView.swift
//  ExportSchedule
//
//  ルート画面。設定の編集・空き時間の生成・出力表示をまとめる。
//

import SwiftUI

struct ContentView: View {
    /// 画面上部の segmented Picker で切り替える表示モード。
    private enum Mode: String, CaseIterable {
        case freeTime
        case freeDays

        var label: LocalizedStringKey {
            switch self {
            case .freeTime: "content.mode.freeTime"
            case .freeDays: "content.mode.freeDays"
            }
        }
    }

    @State private var selectedMode: Mode = .freeTime
    @State private var viewModel = ScheduleViewModel()
    /// プログラムによるスクロール制御用の位置。
    @State private var scrollPosition = ScrollPosition()
    /// 現在の縦スクロールオフセット（相対スクロールの基準に使う）。
    @State private var scrollOffsetY: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("content.mode.picker", selection: $selectedMode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                switch selectedMode {
                case .freeTime:
                    freeTimeContent
                case .freeDays:
                    FreeDaysExportView()
                }
            }
            .background(.base)
            .navigationTitle(selectedMode.label)
        }
    }

    /// 「空き時間」モードの表示内容（既存の設定・生成・プレビュー・出力）。
    private var freeTimeContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSectionView(viewModel: viewModel)

                //            Section {
                Button {
                    Task {
                        await viewModel.generate()
                        // 出力に成功したら現在位置から 400pt 下へスクロールする。
                        if viewModel.errorMessage == nil {
                            withAnimation {
                                scrollPosition.scrollTo(y: scrollOffsetY + 400)
                            }
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("action.exportFreeTime")
                            .padding()
                            .bold()
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                            .glassEffect(.regular.tint(.appBlue).interactive())
                    }
                }
                .disabled(viewModel.isLoading)
                Text("content.calendarSyncNotice")
                    .foregroundStyle(.secondary)
                    .font(.footnote)

                SchedulePreviewView(viewModel: viewModel)

                OutputSectionView(viewModel: viewModel)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
            // キーボード外をタップしたらキーボードを閉じる。
            // ウィンドウへ cancelsTouchesInView = false のタップ認識を載せることで、
            // ボタンやスクロールなどのタップを妨げずに編集を終了できる。
            .onAppear { KeyboardDismisser.install() }
#endif
#if os(macOS)
            .frame(minWidth: 420, minHeight: 560)
#endif
        }
        .background(.base)
        .scrollPosition($scrollPosition)
        // スクロール位置の変化を追跡し、相対スクロールの基準値を更新する。
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollOffsetY = newValue
        }
    }
}

#Preview {
    ContentView()
}
