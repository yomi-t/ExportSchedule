//
//  CalendarEventProviding.swift
//  ExportSchedule
//
//  カレンダー予定取得の抽象化。ViewModel はこのプロトコル越しに利用し、
//  テストではモックを注入できるようにする（EventKit 非依存）。
//

import Foundation

/// カレンダーアクセスの認可状態（EventKit から切り離した独自表現）。
enum CalendarAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
}

/// カレンダーの予定を提供するサービスの抽象。
protocol CalendarEventProviding: Sendable {
    /// 現在の認可状態を返す。
    func authorizationStatus() -> CalendarAuthorizationStatus

    /// フルアクセス権限を要求する。許可されたら true。
    func requestAccess() async throws -> Bool

    /// 指定期間の予定を `BusyInterval` として返す。
    /// `.free` 扱いの予定は除外し、終日予定には `isAllDay` を付与すること。
    func busyIntervals(from start: Date, to end: Date) async throws -> [BusyInterval]
}
