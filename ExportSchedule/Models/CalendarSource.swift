//
//  CalendarSource.swift
//  ExportSchedule
//
//  予定の取得元（Apple カレンダー / Google カレンダー）。
//

import Foundation

/// 予定を取得するカレンダーの種類。
enum CalendarSource: String, CaseIterable, Codable, Sendable {
    case apple
    case google
}
