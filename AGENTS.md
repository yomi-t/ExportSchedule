# AGENTS.md

ExportSchedule プロジェクトで作業する AI コーディングアシスタント(Claude Code, Codex CLI, Cursor など)向けの規約ドキュメントです。人間の開発者にも同様に適用されます。

## プロジェクト概要

カレンダーの空き時間を抽出してテキストとして出力する iOS ユーティリティアプリです。

- SwiftUI 製、iOS 26.0+
- `ExportSchedule.xcodeproj` 単体構成(ワークスペースなし、Swift Package Manager による外部依存なし)
- Bundle ID: `com.taiga.ito.ExportSchedule`

## アーキテクチャ

`ExportSchedule/` 配下は責務ごとにレイヤー分割されています。新しいコードは既存の層に沿って配置してください。

- **`Models/`** — `Codable, Sendable, Hashable` を実装した素のデータ構造。ロジックを持たせない。
- **`Logic/`** — EventKit など外部依存を一切持たない純粋関数群。Foundation のみで完結させ、テスト容易性を保つ。
- **`Services/`** — 外部依存の抽象化。`CalendarEventProviding` プロトコルで EventKit をモック差し替え可能にしている。**`EventKitCalendarService.swift` は EventKit を import する唯一のファイル**という制約があるため、EventKit への依存を新たに増やす場合もこのファイルに閉じ込めること。
- **`ViewModels/`** — `@MainActor @Observable final class`(Observation フレームワーク)。`ObservableObject` / `@Published` は使わない。
- **`Views/`** / **`Views/Components/`** — SwiftUI ビュー。複数箇所で再利用する部品は `Components/` に分離する。

## 命名・コーディングスタイル

- 1 ファイル 1 主要型。ファイル名は型名と一致させる。
- プロトコルは `~Providing` 接尾辞を付ける(例: `CalendarEventProviding`)。
- 依存性注入はイニシャライザ経由で行う。デフォルト引数にプロダクション実装を渡し、テストではモックを注入する。
- public なプロパティ・メソッドには日本語の `///` ドキュメンテーションコメントを付ける。
- Swift 6 の厳格な並行性チェックは有効化していない(`SWIFT_VERSION = 5.0`)。`@MainActor` などの注釈は既存コードに倣うこと。

## ビルド・テスト

- プロジェクト: `ExportSchedule.xcodeproj` / スキーム: `ExportSchedule`
- ビルド: `xcodebuild build -project ExportSchedule.xcodeproj -scheme ExportSchedule ...`
- テスト: `xcodebuild test -project ExportSchedule.xcodeproj -scheme ExportSchedule ...`
- `ExportScheduleTests` は **Swift Testing**(`import Testing`, `@Test`, `#expect`)を使用する。`XCTest` ではない。`TestSupport.swift` に Asia/Tokyo 固定の `Calendar` 等の共通ヘルパーがあるので、日時に依存するテストはこれを利用して決定的にする。
- `ExportScheduleUITests` は標準の `XCTest` テンプレートのまま。
- **実装(コード)を変更したら、既存テストの更新または新規テストの追加が必要かどうかを必ず判断すること。** 必要であれば `ExportScheduleTests` を更新する(`FreeSlotCalculatorTests.swift` / `ScheduleTextFormatterTests.swift` の既存パターンに倣う)。テスト不要と判断した場合も、その判断が妥当か一度立ち止まって確認する。

## String Catalog / ローカライズ規約

String Catalog(`ExportSchedule/Localizable.xcstrings`)によるローカライズ対応を進行中です。`sourceLanguage` は `ja`(日本語が原文言語)。`developmentRegion = ja`、`knownRegions` に `en` / `ja` / `Base` を登録済み。文字列を追加・変更する際は以下の規約に従うこと(実装中の `Localizable.xcstrings` から確認した実際の運用ルール)。

新規キーを追加したら、必ず `ExportSchedule/Localizable.xcstrings` にも `ja` / `en` 両方の翻訳エントリを追加すること(`extractionState: "manual"` で手動追加する運用。Xcode のビルド時自動抽出には頼らない)。`defaultValue:` パラメータは使わない — カタログそのものが翻訳の正とする。

**キーは例外なくすべて `画面(またはドメイン).機能.要素` のドット区切りの記号的な形式にする。日本語原文そのものをキーにする方式(Xcode 標準の抽出方式)は使わない。**

- 特定の画面に閉じた文字列は画面名をトップレベルにする: `settings.*`(`SettingsSectionView`)、`output.*`(`OutputSectionView`)、`preview.*`(`SchedulePreviewView`)、`action.*` / `content.*`(`ContentView`)。
- 複数の画面・レイヤーで共有するドメインはドメイン名をトップレベルにする: `weekday.*`(曜日ラベル、`ScheduleTextFormatter` と `SettingsSectionView` で共有)、`error.*`(`ScheduleViewModel` のエラーメッセージ)、`event.*`(予定表示、`SchedulePreviewView`)。
- View の固定ラベル(`Text` / `Picker` / `Toggle` / `AppSection` のタイトルなど)は `Text("settings.buffer.title")` のようにキー文字列をそのまま渡せば `LocalizedStringKey` として解決される。`String` 型のパラメータが必要な箇所(`DatePicker` の `String` 版イニシャライザ、`ViewModels/` や `Logic/` 内の文字列)は `String(localized: "key")` で明示的に解決する。
- プレースホルダーが必要な場合はカタログ側の値に `%d` / `%@` を使った書式文字列を登録し、`String(format: String(localized: "key"), args...)` で埋め込む。

  ```swift
  AppSection("settings.dateRange.title") { ... }
  DatePicker(String(localized: "settings.dateRange.start"), selection: $viewModel.settings.rangeStart, ...)
  errorMessage = String(localized: "error.accessDenied")
  Text(String(format: String(localized: "settings.outputFormat.exampleLabel"), previewSample))
  ```

- 新規キーの命名が既存キーと衝突・重複しないか、追加前に `Localizable.xcstrings` 内を確認する。
- `InfoPlist.xcstrings` は Info.plist 由来の文言(`NSCalendarsFullAccessUsageDescription` など)専用。アプリ内 UI 文言とは分けて管理する。

## バージョン・環境に関する既知の注意点

- メインアプリターゲットの `IPHONEOS_DEPLOYMENT_TARGET` は `26.0` だが、`ExportScheduleTests` / `ExportScheduleUITests` は `26.5` のままで不整合がある。デプロイターゲットに関わる変更をする場合はこの差異に注意する。
- `TARGETED_DEVICE_FAMILY` は `"1,2"`(iPhone, iPad)。Vision Pro 向けの設定は削除済み。
- `developmentRegion` は `ja`、`knownRegions` は `en` / `ja` / `Base`(String Catalog 導入に伴い設定済み)。

## コミット規約

- コミットメッセージは直近の履歴に倣い、日本語で簡潔な要約にする(例: 「出力形式をカスタマイズできるようにする」)。
- AI アシスタントは、ユーザーから明示的な指示がない限り `git commit` を実行しない。
