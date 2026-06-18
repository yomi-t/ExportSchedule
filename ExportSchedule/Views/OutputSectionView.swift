//
//  OutputSectionView.swift
//  ExportSchedule
//
//  整形済みの空き時間テキストを表示し、コピーできるセクション。
//

import SwiftUI

struct OutputSectionView: View {
    @Bindable var viewModel: ScheduleViewModel
    @State private var didCopy = false
    /// 最後に生成された出力テキストを初期値とし、その場で編集できる本文。
    @State private var editableText = ""

    var body: some View {
        Section("出力") {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if viewModel.outputText.isEmpty {
                Text("「空き時間を生成」を押すと、ここに結果が表示されます。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                TextEditor(text: $editableText)
                    .font(.body.monospaced())
                    .frame(minHeight: 160)
                    .frame(maxWidth: .infinity)

                Button {
                    Clipboard.copy(editableText)
                    didCopy = true
                } label: {
                    Label(didCopy ? "コピーしました" : "クリップボードにコピー",
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
            }
        }
        // 出力が生成・更新されたら、その最新テキストをエディタの初期値として反映する。
        .onAppear { editableText = viewModel.outputText }
        .onChange(of: viewModel.outputText) { _, newValue in
            editableText = newValue
            didCopy = false
        }
    }
}
