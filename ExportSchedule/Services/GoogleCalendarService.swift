//
//  GoogleCalendarService.swift
//  ExportSchedule
//
//  Google Calendar API を用いた CalendarEventProviding の具象実装。
//  GoogleSignIn を import する唯一のファイル。
//

import Foundation
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif

/// Google アカウントのカレンダーから予定を読み取るサービス。
final class GoogleCalendarService: CalendarEventProviding, Sendable {

    /// 予定の読み取りに必要な OAuth スコープ。
    private static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    func authorizationStatus() -> CalendarAuthorizationStatus {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return .notDetermined
        }
        return (user.grantedScopes ?? []).contains(Self.calendarScope) ? .fullAccess : .notDetermined
    }

    /// サインイン（未サインインの場合）・Calendar スコープの許可を要求する。許可されたら true。
    /// UIKit が使えないプラットフォーム（対話的サインイン未サポート）では常に失敗する。
    @MainActor
    func requestAccess() async throws -> Bool {
        if let user = GIDSignIn.sharedInstance.currentUser,
           (user.grantedScopes ?? []).contains(Self.calendarScope) {
            return true
        }

#if os(iOS)
        let presentingViewController = try Self.presentingViewController()

        let grantedUser: GIDGoogleUser
        if let signedInUser = GIDSignIn.sharedInstance.currentUser {
            // サインイン済みだが Calendar スコープ未許可 → 追加スコープを要求。
            grantedUser = try await withCheckedThrowingContinuation { continuation in
                signedInUser.addScopes([Self.calendarScope], presenting: presentingViewController) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let user = result?.user {
                        continuation.resume(returning: user)
                    } else {
                        continuation.resume(throwing: GoogleCalendarServiceError.signInCancelled)
                    }
                }
            }
        } else {
            grantedUser = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController,
                    hint: nil,
                    additionalScopes: [Self.calendarScope]
                ) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let user = result?.user {
                        continuation.resume(returning: user)
                    } else {
                        continuation.resume(throwing: GoogleCalendarServiceError.signInCancelled)
                    }
                }
            }
        }

        return (grantedUser.grantedScopes ?? []).contains(Self.calendarScope)
#else
        throw GoogleCalendarServiceError.noPresentingViewController
#endif
    }

    func busyIntervals(from start: Date, to end: Date) async throws -> [BusyInterval] {
        let accessToken = try await validAccessToken()
        let calendarIDs = try await fetchCalendarIDs(accessToken: accessToken)

        var allIntervals: [BusyInterval] = []
        for calendarID in calendarIDs {
            let intervals = try await fetchBusyIntervals(calendarID: calendarID, accessToken: accessToken, from: start, to: end)
            allIntervals.append(contentsOf: intervals)
        }
        return allIntervals.sorted()
    }

    // MARK: - トークン

    private func validAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleCalendarServiceError.notSignedIn
        }
        let refreshedUser = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
            user.refreshTokensIfNeeded { user, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: GoogleCalendarServiceError.notSignedIn)
                }
            }
        }
        return refreshedUser.accessToken.tokenString
    }

    // MARK: - Calendar API 呼び出し

    private struct CalendarListResponse: Decodable {
        struct Entry: Decodable { let id: String }
        let items: [Entry]
        let nextPageToken: String?
    }

    /// アクセス可能な全カレンダーの ID 一覧を取得する（EventKit 実装の `calendars: nil` 相当）。
    private func fetchCalendarIDs(accessToken: String) async throws -> [String] {
        var ids: [String] = []
        var pageToken: String?
        repeat {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.googleapis.com"
            components.path = "/calendar/v3/users/me/calendarList"
            var queryItems = [URLQueryItem(name: "minAccessRole", value: "reader")]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components.queryItems = queryItems
            let response: CalendarListResponse = try await get(components.url!, accessToken: accessToken)
            ids.append(contentsOf: response.items.map(\.id))
            pageToken = response.nextPageToken
        } while pageToken != nil
        return ids
    }

    private struct EventsResponse: Decodable {
        struct EventDateTime: Decodable {
            let date: String?
            let dateTime: String?
        }
        struct Event: Decodable {
            let start: EventDateTime?
            let end: EventDateTime?
            let summary: String?
            /// "opaque"（既定・予定あり扱い）/ "transparent"（空き時間扱い、EventKit の `.free` 相当）。
            let transparency: String?
        }
        let items: [Event]
        let nextPageToken: String?
    }

    private func fetchBusyIntervals(calendarID: String, accessToken: String, from start: Date, to end: Date) async throws -> [BusyInterval] {
        var intervals: [BusyInterval] = []
        var pageToken: String?
        let isoFormatter = ISO8601DateFormatter()

        repeat {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.googleapis.com"
            components.path = "/calendar/v3/calendars/\(calendarID)/events"
            var queryItems = [
                URLQueryItem(name: "timeMin", value: isoFormatter.string(from: start)),
                URLQueryItem(name: "timeMax", value: isoFormatter.string(from: end)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
            ]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components.queryItems = queryItems
            let response: EventsResponse = try await get(components.url!, accessToken: accessToken)

            for event in response.items where event.transparency != "transparent" {
                if let interval = busyInterval(from: event, isoFormatter: isoFormatter) {
                    intervals.append(interval)
                }
            }
            pageToken = response.nextPageToken
        } while pageToken != nil

        return intervals
    }

    private func busyInterval(from event: EventsResponse.Event, isoFormatter: ISO8601DateFormatter) -> BusyInterval? {
        let title = event.summary ?? ""

        if let dateString = event.start?.date, let endDateString = event.end?.date {
            // 終日予定（date のみで時刻を持たない）。UTC 基準の日付境界として解釈する。
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dayFormatter.timeZone = TimeZone(identifier: "UTC")
            guard let startDate = dayFormatter.date(from: dateString),
                  let endDate = dayFormatter.date(from: endDateString) else { return nil }
            return BusyInterval(start: startDate, end: endDate, isAllDay: true, title: title)
        }

        guard let startString = event.start?.dateTime, let endString = event.end?.dateTime,
              let startDate = isoFormatter.date(from: startString),
              let endDate = isoFormatter.date(from: endString) else { return nil }
        return BusyInterval(start: startDate, end: endDate, isAllDay: false, title: title)
    }

    private func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleCalendarServiceError.requestFailed
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - 起動時セッション復元・URL ハンドリング

    /// アプリ起動時に前回のサインイン状態を復元する。
    static func restorePreviousSignInIfNeeded() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in
                continuation.resume()
            }
        }
    }

    /// OAuth リダイレクト URL を処理する。
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Presenting View Controller

#if os(iOS)
    @MainActor
    private static func presentingViewController() throws -> UIViewController {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            throw GoogleCalendarServiceError.noPresentingViewController
        }
        return rootViewController
    }
#endif
}

enum GoogleCalendarServiceError: LocalizedError {
    case signInCancelled
    case notSignedIn
    case noPresentingViewController
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .signInCancelled:
            String(localized: "error.google.signInCancelled")
        case .notSignedIn:
            String(localized: "error.google.notSignedIn")
        case .noPresentingViewController:
            String(localized: "error.google.presentationFailed")
        case .requestFailed:
            String(localized: "error.google.requestFailed")
        }
    }
}
