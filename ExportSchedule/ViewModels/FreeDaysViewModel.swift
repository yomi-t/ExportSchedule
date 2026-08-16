//
//  FreeDaysViewModel.swift
//  ExportSchedule
//
//  設定 → サービス → 判定 → 整形 をつなぐ「空いてる日」モード用 ViewModel（MVVM）。
//

import Foundation
import Observation

@MainActor
@Observable
final class FreeDaysViewModel {

    // MARK: - 公開状態

    /// ユーザー設定。View からバインドして編集する。
    var settings: FreeDaySettings

    /// 出力テキストの表記形式（日付のみ使用。時刻の書式は出力に含まれない）。
    var outputFormat: TextOutputFormat = TextOutputFormat() {
        didSet {
            if hasGeneratedOnce {
                refreshOutputText()
            }
        }
    }

    /// 出力対象として選択されている日（startOfDay）。判定結果を初期値とし、カレンダーのタップで増減できる。
    private(set) var selectedFreeDays: Set<Date> = []

    /// 候補日カレンダー用の日別予定一覧（判定用の時間帯とは無関係に、その日の予定をすべて含む）。
    private(set) var eventsByDay: [Date: [BusyInterval]] = [:]

    /// コピー用に整形された出力テキスト。
    private(set) var outputText: String = ""

    /// 一度でも `generate()` に成功したかどうか。候補日カレンダーの表示可否に使う。
    private(set) var hasGeneratedOnce = false

    /// 直近の判定に用いたカレンダー（カレンダーUIの日付表示・タップ判定に使う）。
    private(set) var displayCalendar = Calendar(identifier: .gregorian)

    /// 現在のカレンダー認可状態。
    private(set) var authorizationState: CalendarAuthorizationStatus

    /// 判定中フラグ。
    private(set) var isLoading: Bool = false

    /// 直近のエラーメッセージ（あれば）。
    private(set) var errorMessage: String?

    /// 空いてる日が一つもないときに表示する文言。
    private static var emptyOutputMessage: String { String(localized: "freeDays.output.emptyMessage") }

    // MARK: - 依存

    private let service: any CalendarEventProviding
    private let calculator = FreeDayCalculator()
    private let formatter = ScheduleTextFormatter()

    // MARK: - 初期化

    init(service: any CalendarEventProviding = EventKitCalendarService(),
         referenceDate: Date = Date()) {
        self.service = service
        self.settings = FreeDaySettings.makeDefault(referenceDate: referenceDate)
        self.authorizationState = service.authorizationStatus()
    }

    // MARK: - アクション

    /// 認可確認 → 予定取得 → 空いてる日判定 → 整形 を行い `outputText`・`selectedFreeDays` を更新する。
    func generate() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. 認可確認・要求。
            if authorizationState == .notDetermined {
                let granted = try await service.requestAccess()
                authorizationState = service.authorizationStatus()
                if !granted {
                    errorMessage = String(localized: "error.accessDenied")
                    return
                }
            }
            guard authorizationState == .fullAccess else {
                errorMessage = String(localized: "error.accessRequired")
                return
            }

            // 2. 予定取得（期間は終了日の終わりまで含める）。
            let calendar = settings.calendar
            let fetchStart = calendar.startOfDay(for: settings.rangeStart)
            let endDay = calendar.startOfDay(for: settings.rangeEnd)
            let fetchEnd = calendar.date(byAdding: .day, value: 1, to: endDay) ?? settings.rangeEnd
            let busy = try await service.busyIntervals(from: fetchStart, to: fetchEnd, timeZone: calendar.timeZone)

            // 3. 日別の予定一覧（時間帯とは無関係）と、空いてる日を判定。
            let freeDays = calculator.computeFreeDays(busyIntervals: busy,
                                                      settings: settings,
                                                      calendar: calendar)

            eventsByDay = calculator.eventsByDay(busyIntervals: busy, calendar: calendar)
            selectedFreeDays = Set(freeDays)
            displayCalendar = calendar
            hasGeneratedOnce = true
            refreshOutputText()
        } catch {
            errorMessage = String(format: String(localized: "error.fetchFailed"), error.localizedDescription)
        }
    }

    /// カレンダーUI上でのタップにより、指定日の選択状態を切り替える。
    func toggleDay(_ day: Date) {
        let key = displayCalendar.startOfDay(for: day)
        if selectedFreeDays.contains(key) {
            selectedFreeDays.remove(key)
        } else {
            selectedFreeDays.insert(key)
        }
        hasGeneratedOnce = true
        refreshOutputText()
    }

    // MARK: - 内部

    /// 現在の `selectedFreeDays` から出力テキストを再生成する。
    private func refreshOutputText() {
        let text = selectedFreeDays
            .sorted()
            .map { formatter.dateText(for: $0, calendar: displayCalendar, outputFormat: outputFormat) }
            .joined(separator: "\n")
        outputText = text.isEmpty ? Self.emptyOutputMessage : text
    }
}
