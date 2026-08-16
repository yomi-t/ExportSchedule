//
//  FreeDaysOutputSectionView.swift
//  ExportSchedule
//
//  整形済みの「空いてる日」テキストを表示し、コピーできるセクション。
//

import SwiftUI

struct FreeDaysOutputSectionView: View {
    @Bindable var viewModel: FreeDaysViewModel
    @State private var didCopy = false
    /// 最後に生成された出力テキストを初期値とし、その場で編集できる本文。
    @State private var editableText = ""

    var body: some View {
        AppSection("freeDays.output.title") {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if viewModel.outputText.isEmpty {
                Text("freeDays.output.placeholder")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                TextEditor(text: $editableText)
                    .font(.body.monospaced())
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity)
                    .background(.base)
                    .cornerRadius(8)
                HStack {
                    Spacer()
                    Button {
                        Clipboard.copy(editableText)
                        didCopy = true
                    } label: {
                        Label(didCopy ? "freeDays.output.copied" : "freeDays.output.copy",
                              systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .bold()
                        .padding()
                        .glassEffect(.regular.interactive())
                    }
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

#Preview {
    FreeDaysExportView()
}
