//
//  AppSection.swift
//  ExportSchedule
//
//  Created by TAIGA ITO on 2026/06/18.
//

import SwiftUI

struct AppSection<Header: View, Content: View, Footer: View>: View {
    let header: Header
    let content: Content
    let footer: Footer
    
    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !(header is EmptyView) {
                header
                    .font(.headline)
            }
            VStack(spacing: 8) {
                Group(subviews: content) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        subviews[index]
                            .frame(maxWidth: .infinity)
                        if index < subviews.count - 1 {
                            Divider()
                        }
                    }
                }
            }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.section)
                .cornerRadius(16)
            if !(footer is EmptyView) {
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension AppSection where Footer == EmptyView {
    init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.footer = EmptyView()
        self.content = content()
    }
}

extension AppSection where Header == EmptyView {
    init(@ViewBuilder footer: () -> Footer, @ViewBuilder content: () -> Content) {
        self.header = EmptyView()
        self.footer = footer()
        self.content = content()
    }
}

extension AppSection where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.header = EmptyView()
        self.footer = EmptyView()
    }
}

extension AppSection where Header == Text {
    init(
        _ title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        // StringをTextビューに変換してheaderに代入
        self.content = content()
        self.header = Text(title)
        self.footer = footer()
    }
}

// パターンB: ヘッダーはString、フッターはなし（EmptyView）
extension AppSection where Header == Text, Footer == EmptyView {
    init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.header = Text(title)
        self.footer = EmptyView()
    }
}
