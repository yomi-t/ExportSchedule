//
//  ScheduleViewModel.swift
//  ExportSchedule
//
//  設定 → サービス → 計算 → 整形 をつなぐ ViewModel（MVVM）。
//

import Foundation
import Observation

@MainActor
@Observable
final class ScheduleViewModel {

    // MARK: - 公開状態

    /// ユーザー設定。View からバインドして編集する。
    var settings: FreeSlotSettings

    /// コピー用に整形された出力テキスト。
    private(set) var outputText: String = ""

    /// 候補日プレビュー用の日別スケジュール（候補枠・候補区間・既存予定）。
    private(set) var daySchedules: [DaySchedule] = []

    /// 直近の生成に用いたカレンダー（プレビューの日付・時刻表示に使う）。
    private(set) var displayCalendar = Calendar(identifier: .gregorian)

    /// 現在のカレンダー認可状態。
    private(set) var authorizationState: CalendarAuthorizationStatus

    /// 計算・取得中フラグ。
    private(set) var isLoading: Bool = false

    /// 直近のエラーメッセージ（あれば）。
    private(set) var errorMessage: String?

    /// 空き時間が一つもないときに表示する文言。
    private static let emptyOutputMessage = "指定期間に空き時間が見つかりませんでした。"

    // MARK: - 依存

    private let service: any CalendarEventProviding
    private let calculator = FreeSlotCalculator()
    private let formatter = ScheduleTextFormatter()

    // MARK: - 初期化

    init(service: any CalendarEventProviding = EventKitCalendarService(),
         referenceDate: Date = Date()) {
        self.service = service
        self.settings = FreeSlotSettings.makeDefault(referenceDate: referenceDate)
        self.authorizationState = service.authorizationStatus()
    }

    // MARK: - アクション

    /// 認可確認 → 予定取得 → 空き時間計算 → 整形 を行い `outputText`・`daySchedules` を更新する。
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
                    errorMessage = "カレンダーへのアクセスが許可されませんでした。"
                    return
                }
            }
            guard authorizationState == .fullAccess else {
                errorMessage = "カレンダーへのアクセスが必要です。設定アプリから許可してください。"
                return
            }

            // 2. 予定取得（期間は終了日の終わりまで含める）。
            let calendar = settings.calendar
            let fetchStart = calendar.startOfDay(for: settings.rangeStart)
            let endDay = calendar.startOfDay(for: settings.rangeEnd)
            let fetchEnd = calendar.date(byAdding: .day, value: 1, to: endDay) ?? settings.rangeEnd
            let busy = try await service.busyIntervals(from: fetchStart, to: fetchEnd)

            // 3. 日別スケジュールを計算 → 空き状況を導出 → 整形。
            let schedules = calculator.computeDaySchedules(busyIntervals: busy,
                                                           settings: settings,
                                                           calendar: calendar)

            daySchedules = schedules
            displayCalendar = calendar
            refreshOutputText()
        } catch {
            errorMessage = "予定の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    /// プレビュー上でドラッグ編集された候補区間を反映し、出力テキストを再生成する。
    /// - Parameters:
    ///   - dayID: 対象の日（`DaySchedule.id`）。
    ///   - index: その日の `freeIntervals` 内インデックス。
    ///   - newRange: 編集後の区間。
    func updateFreeInterval(dayID: Date, at index: Int, to newRange: DateRange) {
        guard let dayIndex = daySchedules.firstIndex(where: { $0.id == dayID }) else { return }
        guard daySchedules[dayIndex].freeIntervals.indices.contains(index) else { return }
        guard daySchedules[dayIndex].freeIntervals[index] != newRange else { return }
        daySchedules[dayIndex].freeIntervals[index] = newRange
        refreshOutputText()
    }

    /// 出力テキストをクリップボードへコピーする。
    func copyToClipboard() {
        guard !outputText.isEmpty else { return }
        Clipboard.copy(outputText)
    }

    // MARK: - 内部

    /// 現在の `daySchedules` から出力テキストを再生成する。
    private func refreshOutputText() {
        let availability = daySchedules.map {
            DateAvailability(day: $0.day, freeIntervals: $0.freeIntervals)
        }
        let text = formatter.format(availability, calendar: displayCalendar)
        outputText = text.isEmpty ? Self.emptyOutputMessage : text
    }
}
