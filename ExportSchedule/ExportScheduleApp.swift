//
//  ExportScheduleApp.swift
//  ExportSchedule
//
//  Created by TAIGA ITO on 2026/07/16.
//

import SwiftUI

@main
struct ExportScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 前回の Google サインイン状態を起動時に復元する。
                .task { await GoogleCalendarService.restorePreviousSignInIfNeeded() }
                // Google サインインの OAuth リダイレクトを処理する。
                .onOpenURL { url in
                    _ = GoogleCalendarService.handle(url)
                }
        }
    }
}
