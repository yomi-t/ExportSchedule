//
//  ScheduleViewModelTests.swift
//  ExportScheduleTests
//
//  calendarSource の切り替えに関する ScheduleViewModel の単体テスト。
//

import Testing
import Foundation
@testable import ExportSchedule

@MainActor
struct ScheduleViewModelTests {

    @Test func initialCalendarSourceIsAppleAndUsesEventKitAuthorizationStatus() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock)

        #expect(viewModel.calendarSource == .apple)
        #expect(viewModel.authorizationState == .fullAccess)
    }

    @Test func switchingToGoogleRefreshesAuthorizationStateFromGoogleService() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock)

        viewModel.calendarSource = .google

        #expect(viewModel.authorizationState == .notDetermined)
    }

    @Test func switchingBackToAppleRefreshesAuthorizationStateFromEventKitService() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .denied)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock)

        viewModel.calendarSource = .google
        #expect(viewModel.authorizationState == .fullAccess)

        viewModel.calendarSource = .apple
        #expect(viewModel.authorizationState == .denied)
    }

    @Test func generateUsesGoogleServiceWhenCalendarSourceIsGoogle() async {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let day = TestSupport.date(2026, 6, 15)
        googleMock.stubBusyIntervals = .success([
            BusyInterval(start: TestSupport.date(2026, 6, 15, 12, 0), end: TestSupport.date(2026, 6, 15, 13, 0)),
        ])

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, referenceDate: day)
        viewModel.calendarSource = .google
        viewModel.settings = TestSupport.settings(start: day, end: day)

        await viewModel.generate()

        #expect(googleMock.busyIntervalsCallCount == 1)
        #expect(eventKitMock.busyIntervalsCallCount == 0)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func generateShowsGoogleSpecificMessageWhenAccessNotGranted() async {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .denied)

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock)
        viewModel.calendarSource = .google

        await viewModel.generate()

        #expect(viewModel.errorMessage == String(localized: "error.accessRequired.google"))
    }
}
