//
//  MockCalendarEventProviding.swift
//  ExportScheduleTests
//
//  CalendarEventProviding のテスト用ダブル。
//

import Foundation
@testable import ExportSchedule

final class MockCalendarEventProviding: CalendarEventProviding, @unchecked Sendable {
    var stubAuthorizationStatus: CalendarAuthorizationStatus
    var stubRequestAccessResult: Result<Bool, Error> = .success(true)
    var stubBusyIntervals: Result<[BusyInterval], Error> = .success([])

    private(set) var authorizationStatusCallCount = 0
    private(set) var requestAccessCallCount = 0
    private(set) var busyIntervalsCallCount = 0
    private(set) var lastTimeZone: TimeZone?

    init(authorizationStatus: CalendarAuthorizationStatus = .notDetermined) {
        self.stubAuthorizationStatus = authorizationStatus
    }

    func authorizationStatus() -> CalendarAuthorizationStatus {
        authorizationStatusCallCount += 1
        return stubAuthorizationStatus
    }

    func requestAccess() async throws -> Bool {
        requestAccessCallCount += 1
        return try stubRequestAccessResult.get()
    }

    func busyIntervals(from start: Date, to end: Date, timeZone: TimeZone) async throws -> [BusyInterval] {
        busyIntervalsCallCount += 1
        lastTimeZone = timeZone
        return try stubBusyIntervals.get()
    }
}
