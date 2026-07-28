//
//  TextOutputFormat.swift
//  ExportSchedule
//
//  出力テキストの表記形式を管理する設定。
//

import Foundation

enum DateOutputStyle: String, CaseIterable, Codable, Sendable {
    case slash = "slash"
    case kanji = "kanji"

    var label: String {
        switch self {
        case .slash: "7/6"
        case .kanji: "7月6日"
        }
    }
}

enum TimeOutputStyle: String, CaseIterable, Codable, Sendable {
    case colon = "colon"
    case kanji = "kanji"

    var label: String {
        switch self {
        case .colon: "9:05"
        case .kanji: "9時05分"
        }
    }
}

struct TextOutputFormat: Codable, Sendable, Hashable {
    var dateStyle: DateOutputStyle = .slash
    var timeStyle: TimeOutputStyle = .colon
    var zeroPadded: Bool = false
}
