//
//  Clipboard.swift
//  ExportSchedule
//
//  プラットフォーム差異を吸収したクリップボードコピーのユーティリティ。
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum Clipboard {
    /// 文字列をシステムのクリップボードへコピーする。
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
    }
}
