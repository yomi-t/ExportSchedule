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

    /// 現在のカレンダー認可状態。
    private(set) var authorizationState: CalendarAuthorizationStatus

    /// 計算・取得中フラグ。
    private(set) var isLoading: Bool = false

    /// 直近のエラーメッセージ（あれば）。
    private(set) var errorMessage: String?

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

    /// 認可確認 → 予定取得 → 空き時間計算 → 整形 を行い `outputText` を更新する。
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

            // 3. 空き時間計算 → 整形。
            let availability = calculator.computeAvailability(busyIntervals: busy,
                                                              settings: settings,
                                                              calendar: calendar)
            let text = formatter.format(availability, calendar: calendar)
            outputText = text.isEmpty ? "指定期間に空き時間が見つかりませんでした。" : text
        } catch {
            errorMessage = "予定の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 出力テキストをクリップボードへコピーする。
    func copyToClipboard() {
        guard !outputText.isEmpty else { return }
        Clipboard.copy(outputText)
    }
}
