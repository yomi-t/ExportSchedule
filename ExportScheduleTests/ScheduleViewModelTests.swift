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

    /// テスト間で状態が混ざらないよう、テストごとに独立した `UserDefaults` を生成する。
    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "ScheduleViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func initialCalendarSourceIsAppleAndUsesEventKitAuthorizationStatus() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())

        #expect(viewModel.calendarSource == .apple)
        #expect(viewModel.authorizationState == .fullAccess)
    }

    @Test func switchingToGoogleRefreshesAuthorizationStateFromGoogleService() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())

        viewModel.calendarSource = .google

        #expect(viewModel.authorizationState == .notDetermined)
    }

    @Test func switchingBackToAppleRefreshesAuthorizationStateFromEventKitService() {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .denied)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())

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

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults(), referenceDate: day)
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

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())
        viewModel.calendarSource = .google

        await viewModel.generate()

        #expect(viewModel.errorMessage == String(localized: "error.accessRequired.google"))
    }

    @Test func needsInitialCalendarSourceSelectionIsTrueByDefault() {
        let viewModel = ScheduleViewModel(
            eventKitService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            googleService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            userDefaults: makeIsolatedUserDefaults()
        )

        #expect(viewModel.needsInitialCalendarSourceSelection == true)
    }

    @Test func completingInitialCalendarSourceSelectionPersistsAcrossInstances() {
        let userDefaults = makeIsolatedUserDefaults()
        let firstViewModel = ScheduleViewModel(
            eventKitService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            googleService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            userDefaults: userDefaults
        )

        firstViewModel.completeInitialCalendarSourceSelection()
        #expect(firstViewModel.needsInitialCalendarSourceSelection == false)

        let secondViewModel = ScheduleViewModel(
            eventKitService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            googleService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            userDefaults: userDefaults
        )
        #expect(secondViewModel.needsInitialCalendarSourceSelection == false)
    }

    @Test func requestInitialCalendarAccessCallsAppleServiceWhenSourceIsApple() async {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        eventKitMock.stubRequestAccessResult = .success(true)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())

        let granted = await viewModel.requestInitialCalendarAccess()

        #expect(granted == true)
        #expect(eventKitMock.requestAccessCallCount == 1)
        #expect(googleMock.requestAccessCallCount == 0)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func requestInitialCalendarAccessCallsGoogleServiceWhenSourceIsGoogleAndSetsErrorOnDenial() async {
        let eventKitMock = MockCalendarEventProviding(authorizationStatus: .fullAccess)
        let googleMock = MockCalendarEventProviding(authorizationStatus: .notDetermined)
        googleMock.stubRequestAccessResult = .success(false)

        let viewModel = ScheduleViewModel(eventKitService: eventKitMock, googleService: googleMock, userDefaults: makeIsolatedUserDefaults())
        viewModel.calendarSource = .google

        let granted = await viewModel.requestInitialCalendarAccess()

        #expect(granted == false)
        #expect(googleMock.requestAccessCallCount == 1)
        #expect(eventKitMock.requestAccessCallCount == 0)
        #expect(viewModel.errorMessage == String(localized: "error.accessRequired.google"))
    }

    @Test func calendarSourceSelectionPersistsAcrossInstances() {
        let userDefaults = makeIsolatedUserDefaults()
        let firstViewModel = ScheduleViewModel(
            eventKitService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            googleService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            userDefaults: userDefaults
        )

        firstViewModel.calendarSource = .google

        let secondViewModel = ScheduleViewModel(
            eventKitService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            googleService: MockCalendarEventProviding(authorizationStatus: .fullAccess),
            userDefaults: userDefaults
        )
        #expect(secondViewModel.calendarSource == .google)
    }
}
