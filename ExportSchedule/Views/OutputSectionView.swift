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
                Text(viewModel.outputText)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    viewModel.copyToClipboard()
                    didCopy = true
                } label: {
                    Label(didCopy ? "コピーしました" : "クリップボードにコピー",
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .onChange(of: viewModel.outputText) { _, _ in
                    didCopy = false
                }
            }
        }
    }
}
