//
//  ContentView.swift
//  ExportSchedule
//
//  ルート画面。設定の編集・空き時間の生成・出力表示をまとめる。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            } footer: {
                Text("カレンダーの変更の反映には時間がかかることがあります。生成前にカレンダーアプリを開いておくと、最新の予定が反映されやすくなります。")
            }

            SchedulePreviewView(viewModel: viewModel)

            OutputSectionView(viewModel: viewModel)
        }
        .formStyle(.grouped)
        .navigationTitle("空き時間の書き出し")
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
}

#if os(iOS)
/// キーウィンドウに「タップで編集終了」のジェスチャを一度だけ取り付けるヘルパー。
private final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    private static let shared = KeyboardDismisser()
    private static let recognizerName = "hideKeyboardTap"

    static func install() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        // 二重登録を避ける。
        if window.gestureRecognizers?.contains(where: { $0.name == recognizerName }) == true { return }

        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.name = recognizerName
        tap.cancelsTouchesInView = false   // ボタン等のタップを妨げない
        tap.delegate = shared
        window.addGestureRecognizer(tap)
    }

    // ボタン・スクロールなど他のジェスチャと同時に認識させる。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // TextEditor（UITextView）などのテキスト入力上のタップでは閉じない。
    // それ以外（キーボード外かつ TextEditor 外）のタップのときだけジェスチャを受け取る。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextView || current is UITextField { return false }
            view = current.superview
        }
        return true
    }
}
#endif

#Preview {
    ContentView()
}
