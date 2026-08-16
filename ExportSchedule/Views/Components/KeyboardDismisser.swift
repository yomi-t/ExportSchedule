//
//  KeyboardDismisser.swift
//  ExportSchedule
//
//  キーウィンドウに「タップで編集終了」のジェスチャを一度だけ取り付けるヘルパー。
//

#if os(iOS)
import UIKit

final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
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
