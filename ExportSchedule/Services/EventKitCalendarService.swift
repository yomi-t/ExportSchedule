//
//  EventKitCalendarService.swift
//  ExportSchedule
//
//  EventKit を用いた CalendarEventProviding の具象実装。
//  EventKit を import する唯一のファイル。
//

import Foundation
import EventKit

/// 端末のローカルカレンダー（Google アカウント同期分を含む）から予定を読み取るサービス。
final class EventKitCalendarService: CalendarEventProviding, @unchecked Sendable {

    /// EKEventStore は生成コストが高いため単一インスタンスを保持する。
    private let store = EKEventStore()

    func authorizationStatus() -> CalendarAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            // 読み取りには full access が必要。書き込み専用は実質未許可として扱う。
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        // 予定の読み取りには full access が必要（read-only のアクセスレベルは存在しない）。
        try await store.requestFullAccessToEvents()
    }

    func busyIntervals(from start: Date, to end: Date) async throws -> [BusyInterval] {
        let store = self.store
        // events(matching:) は同期かつ重い処理のためメインアクター外で実行する。
        return try await Task.detached(priority: .userInitiated) {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            let events = store.events(matching: predicate)
            return events
                // 空き時間として扱う（.free）予定は除外する。
                .filter { $0.availability != .free }
                .map { event in
                    BusyInterval(start: event.startDate,
                                 end: event.endDate,
                                 isAllDay: event.isAllDay)
                }
                .sorted()
        }.value
    }
}
