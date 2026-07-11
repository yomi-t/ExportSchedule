//
//  SchedulePreviewView.swift
//  ExportSchedule
//
//  候補日（空き時間帯）を時間帯枠のタイムバー上に視覚化し、
//  同じ枠に既存の予定も重ねて表示するプレビュー。
//  緑のバー（候補）は端をドラッグして範囲を5分単位で調整でき、
//  変更はコピペ用テキストにも即時反映される。
//  予定のバーをタップするとタイトルと時間をポップオーバー表示する。
//

import SwiftUI

struct SchedulePreviewView: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        if !viewModel.daySchedules.isEmpty {
            AppSection("候補日プレビュー") {
                ForEach(viewModel.daySchedules) { schedule in
                    DayScheduleRow(schedule: schedule,
                                   calendar: viewModel.displayCalendar) { index, newRange in
                        viewModel.updateFreeInterval(dayID: schedule.id, at: index, to: newRange)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                ColorLegend()
            }
        }
    }
}

// MARK: - 凡例

/// 色の意味を示す凡例（緑＝候補、赤＝既存の予定）。
private struct ColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                legendItem(color: .appGreen, label: "候補（空き）")
                legendItem(color: .red, label: "既存の予定")
                Spacer()
            }
            Text("緑のバーの端をドラッグすると、候補の時間を5分単位で調整できます。")
                .foregroundStyle(.secondary)
            Text("予定のバーをタップすると、タイトルと時間を表示します。")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.top, 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.75))
                .frame(width: 14, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 1日分の行

private struct DayScheduleRow: View {
    let schedule: DaySchedule
    let calendar: Calendar
    /// 候補区間の編集を親（ViewModel）へ伝えるコールバック（index, 編集後の区間）。
    let onUpdate: (Int, DateRange) -> Void

    private static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 見出し：日付＋状態バッジ
            HStack {
                Text(dateLabel)
                    .font(.headline)
                Spacer()
            }

            // タイムバー（時間帯枠の上に候補と予定を重ね、時間目盛りを添える）
            DayTimelineBar(schedule: schedule, calendar: calendar, onUpdate: onUpdate)
        }
    }

    // MARK: テキスト整形

    private var dateLabel: String {
        let month = calendar.component(.month, from: schedule.day)
        let day = calendar.component(.day, from: schedule.day)
        let weekday = calendar.component(.weekday, from: schedule.day)
        let symbol = Self.weekdaySymbols[(weekday - 1) % 7]
        return "\(month)/\(day)(\(symbol))"
    }
}

// MARK: - タイムバー

/// 時間帯枠を全幅とし、候補（緑・ドラッグ編集可）と既存予定（赤）を比率で重ね、毎正時の目盛りを添える横棒。
private struct DayTimelineBar: View {
    let schedule: DaySchedule
    let calendar: Calendar
    let onUpdate: (Int, DateRange) -> Void

    private let barHeight: CGFloat = 24
    /// ドラッグ中の時刻ラベルがバー上端からはみ出して表示される余白。
    private let labelHeadroom: CGFloat = 22

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            VStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    // 背景トラック（時間帯枠）
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.18))

                    // 既存の予定（赤・タップでポップオーバー）
                    ForEach(Array(schedule.events.enumerated()), id: \.offset) { _, event in
                        if let metrics = metrics(for: event.range, width: width) {
                            EventSegment(event: event,
                                         calendar: calendar,
                                         width: metrics.length,
                                         offset: metrics.offset,
                                         height: barHeight)
                        }
                    }

                    // 毎正時の目盛り線
                    ForEach(Array(hourTicks.enumerated()), id: \.offset) { _, tick in
                        Rectangle()
                            .fill(Color.primary.opacity(0.25))
                            .frame(width: 1)
                            .offset(x: tickX(tick, width: width))
                            .allowsHitTesting(false)
                    }

                    // 候補（緑・端をドラッグして5分単位で調整）。予定の上に重ねて空き帯を強調する。
                    ForEach(Array(schedule.freeIntervals.enumerated()), id: \.offset) { index, free in
                        FreeSegment(index: index,
                                    range: free,
                                    window: schedule.window,
                                    lowerBound: lowerBound(at: index),
                                    upperBound: upperBound(at: index),
                                    trackWidth: width,
                                    height: barHeight,
                                    calendar: calendar,
                                    onCommit: onUpdate)
                    }
                }
                .frame(height: barHeight)
                // ドラッグ中の時刻ラベルが上方向にはみ出しても切れないように余白を確保する。
                .padding(.top, labelHeadroom)

                // 目盛りラベル（毎正時の「時」）
                ZStack(alignment: .topLeading) {
                    ForEach(Array(hourTicks.enumerated()), id: \.offset) { _, tick in
                        Text("\(calendar.component(.hour, from: tick))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(x: clampedLabelX(tickX(tick, width: width), width: width), y: 6)
                    }
                }
                .frame(height: 12)
            }
        }
        .frame(height: barHeight + labelHeadroom + 14)
    }

    // MARK: 隣接区間の境界（重なり防止）

    /// `index` の候補区間が左方向へ広げられる下限（直前の区間の終端、なければ枠の開始）。
    private func lowerBound(at index: Int) -> Date {
        index > 0 ? schedule.freeIntervals[index - 1].end : schedule.window.start
    }

    /// `index` の候補区間が右方向へ広げられる上限（直後の区間の開始、なければ枠の終了）。
    private func upperBound(at index: Int) -> Date {
        index < schedule.freeIntervals.count - 1 ? schedule.freeIntervals[index + 1].start : schedule.window.end
    }

    // MARK: 位置計算

    /// 区間を候補ウィンドウ内に収め、比率に応じた位置・幅を返す。範囲外なら nil。
    private func metrics(for range: DateRange, width: CGFloat) -> (offset: CGFloat, length: CGFloat)? {
        let total = schedule.window.duration
        guard total > 0 else { return nil }
        let clampedStart = max(range.start, schedule.window.start)
        let clampedEnd = min(range.end, schedule.window.end)
        let length = clampedEnd.timeIntervalSince(clampedStart)
        guard length > 0 else { return nil }
        let offset = clampedStart.timeIntervalSince(schedule.window.start) / total * Double(width)
        let pixelLength = max(6, length / total * Double(width))
        return (CGFloat(offset), CGFloat(pixelLength))
    }

    /// 候補ウィンドウ内に含まれる毎正時の時刻一覧。
    private var hourTicks: [Date] {
        let total = schedule.window.duration
        guard total > 0 else { return [] }
        var ticks: [Date] = []
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: schedule.window.start)
        guard var tick = calendar.date(from: comps) else { return [] }
        if tick < schedule.window.start {
            tick = calendar.date(byAdding: .hour, value: 1, to: tick) ?? tick
        }
        while tick <= schedule.window.end {
            ticks.append(tick)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: tick) else { break }
            tick = next
        }
        return ticks
    }

    private func tickX(_ date: Date, width: CGFloat) -> CGFloat {
        let total = schedule.window.duration
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(schedule.window.start) / total * Double(width))
    }

    /// ラベルが端で見切れないように位置を内側へ寄せる。
    private func clampedLabelX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 8), max(8, width - 8))
    }
}

// MARK: - 候補セグメント（端をドラッグして5分単位で調整）

private struct FreeSegment: View {
    let index: Int
    let range: DateRange
    let window: DateRange
    /// 開始側をこれより前へは動かせない境界（隣接区間 or 枠の開始）。
    let lowerBound: Date
    /// 終了側をこれより後へは動かせない境界（隣接区間 or 枠の終了）。
    let upperBound: Date
    let trackWidth: CGFloat
    let height: CGFloat
    let calendar: Calendar
    let onCommit: (Int, DateRange) -> Void

    /// 調整できる最小単位（5分）。
    private static let step: TimeInterval = 5 * 60
    /// 候補区間の最小長（0＝幅0まで縮められる。幅0の区間は出力に含めない）。
    private static let minDuration: TimeInterval = 0
    /// ドラッグ操作を受け付ける掴み代の幅。
    private let handleHitWidth: CGFloat = 28
    /// ハンドル（白いつまみ）の見た目の幅。幅0のバー描画にも使う。
    private let handleWidth: CGFloat = 4

    @State private var draft: DateRange?
    @State private var activeEdge: Edge?
    /// 幅0から始めたドラッグで操作する端。最初の移動方向で決め、その操作中は固定する。
    @State private var mergedEdge: Edge?

    private enum Edge { case leading, trailing }

    /// 描画に使う区間（ドラッグ中は draft、それ以外は確定値）。
    private var current: DateRange { draft ?? range }

    /// 確定値の幅が0かどうか。0のときはハンドルを1つに統合して表示する。
    /// （ドラッグ中の draft では切り替えず確定値で判定し、操作中にビューが差し替わって
    /// 　ジェスチャが中断されるのを防ぐ。）
    private var isCollapsed: Bool { range.duration <= 0 }

    var body: some View {
        let metrics = pixelMetrics(for: current)
        ZStack(alignment: .leading) {
            // 緑の帯（本体はヒットさせず、端のハンドルだけドラッグを受ける）
            RoundedRectangle(cornerRadius: 5)
                .frame(width: metrics.length, height: height)
                .glassEffect(.clear.tint(.barGreen), in: .rect(cornerRadius: 5))
                .offset(x: metrics.offset)
                .allowsHitTesting(false)

            if isCollapsed {
                // 幅0：統合した1つのハンドル。ドラッグ方向に応じて左右どちらかへ伸びる。
                // 動いている端は mergedHandle が担当（ドラッグを保持）。
                mergedHandle(metrics: metrics)
                // 0からドラッグして幅が出た瞬間、固定側の端にも見た目だけのハンドルを出し、
                // ジェスチャを途切れさせずに2ハンドル表示へ切り替える。
                if let edge = activeEdge, current.duration > 0 {
                    let edges = edgeXs(for: current)
                    handleVisual(centerX: edge == .trailing ? edges.start : edges.end)
                }
            } else {
                // ハンドルは最小幅クランプを受けない真の端座標に置く。
                // （緑バーの描画長は最小6pxに切り上げるため、それを使うと
                // 　区間が短いとき leading ドラッグで trailing も押し出されて見える。）
                let edges = edgeXs(for: current)
                handle(.leading, centerX: edges.start)
                handle(.trailing, centerX: edges.end)
            }

            // 実幅が0の瞬間だけ、ハンドル中央にハンドル幅の緑の丸を重ねて存在を示す
            // （確定値ではなくドラッグ中の幅で判定するので、0になった/0でなくなった瞬間に出入りする）。
            if current.duration <= 0 {
                Circle()
                    .fill(Color.appGreen)
                    .frame(width: handleWidth, height: handleWidth)
                    .offset(x: edgeXs(for: current).start - handleWidth / 2)
                    .allowsHitTesting(false)
            }

            if let edge = activeEdge {
                dragTimeLabel(for: edge)
            }
        }
    }

    // MARK: ハンドル

    private func handle(_ edge: Edge, centerX: CGFloat) -> some View {
        // 視認用の白いつまみ＋透明な広いヒット領域。
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.95))
            .frame(width: handleWidth, height: height * 0.55)
            .frame(width: handleHitWidth, height: height)
            .contentShape(Rectangle())
            .offset(x: centerX - handleHitWidth / 2)
            .gesture(dragGesture(for: edge))
    }

    /// 見た目だけのハンドル（ドラッグは受けない）。マージ中に固定側の端を見せるのに使う。
    private func handleVisual(centerX: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.95))
            .frame(width: handleWidth, height: height * 0.55)
            .frame(width: handleHitWidth, height: height)
            .offset(x: centerX - handleHitWidth / 2)
            .allowsHitTesting(false)
    }

    /// 幅0のときの統合ハンドル。ドラッグ中は伸びている側の端へ追従する。
    private func mergedHandle(metrics: (offset: CGFloat, length: CGFloat)) -> some View {
        // 待機中はバーの左右中央、ドラッグ中は伸びている側の端（真の端座標）へ追従する。
        let edges = edgeXs(for: current)
        let centerX: CGFloat
        switch activeEdge {
        case .trailing: centerX = edges.end
        case .leading: centerX = edges.start
        case .none: centerX = metrics.offset + metrics.length / 2
        }
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.95))
            .frame(width: handleWidth, height: height * 0.55)
            .frame(width: handleHitWidth, height: height)
            .contentShape(Rectangle())
            .offset(x: centerX - handleHitWidth / 2)
            .gesture(mergedDragGesture())
    }

    private func mergedDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // 最初の移動方向で操作する端を決め、その操作中は固定する
                // （途中で原点を越えて反対へ動かしても切り替えない）。
                let edge = mergedEdge ?? (value.translation.width >= 0 ? .trailing : .leading)
                mergedEdge = edge
                activeEdge = edge
                draft = updatedRange(for: edge, translationX: value.translation.width)
            }
            .onEnded { value in
                let edge = mergedEdge ?? (value.translation.width >= 0 ? .trailing : .leading)
                let committed = draft ?? updatedRange(for: edge, translationX: value.translation.width)
                draft = nil
                activeEdge = nil
                mergedEdge = nil
                onCommit(index, committed)
            }
    }

    private func dragGesture(for edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                activeEdge = edge
                draft = updatedRange(for: edge, translationX: value.translation.width)
            }
            .onEnded { value in
                // 画面に表示していた draft をそのまま確定する。
                // onEnded の translation は直前の onChanged とわずかにズレることがあり、
                // 再計算するとスナップ先が変わって離した瞬間に位置が飛んで見えるため。
                let committed = draft ?? updatedRange(for: edge, translationX: value.translation.width)
                draft = nil
                activeEdge = nil
                onCommit(index, committed)
            }
    }

    // MARK: ドラッグ中の時刻ラベル

    private func dragTimeLabel(for edge: Edge) -> some View {
        let date = edge == .leading ? current.start : current.end
        let edges = edgeXs(for: current)
        let edgeX = edge == .leading ? edges.start : edges.end
        return Text(timeText(date))
            .font(.caption2.bold())
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(.primary)
            .fixedSize()
            // バーの上端より上に浮かせて表示する。
            .position(x: min(max(edgeX, 24), max(24, trackWidth - 24)), y: -12)
            .allowsHitTesting(false)
    }

    // MARK: 区間の更新ロジック

    /// ドラッグ量を時間に換算し、5分刻みにスナップ・境界クランプした新しい区間を返す。
    private func updatedRange(for edge: Edge, translationX: CGFloat) -> DateRange {
        let total = window.duration
        guard total > 0, trackWidth > 0 else { return range }
        let deltaSeconds = Double(translationX) / Double(trackWidth) * total

        switch edge {
        case .leading:
            var newStart = snapToStep(range.start.addingTimeInterval(deltaSeconds))
            let maxStart = range.end.addingTimeInterval(-Self.minDuration)
            newStart = min(max(newStart, lowerBound), maxStart)
            return DateRange(start: newStart, end: range.end)
        case .trailing:
            var newEnd = snapToStep(range.end.addingTimeInterval(deltaSeconds))
            let minEnd = range.start.addingTimeInterval(Self.minDuration)
            newEnd = max(min(newEnd, upperBound), minEnd)
            return DateRange(start: range.start, end: newEnd)
        }
    }

    /// 5分の壁時計境界へ最も近い時刻に丸める。
    private func snapToStep(_ date: Date) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        let snapped = (t / Self.step).rounded() * Self.step
        return Date(timeIntervalSinceReferenceDate: snapped)
    }

    // MARK: 位置計算

    /// 区間の開始・終了の真のX座標（最小幅クランプなし。ハンドルやラベルの位置に使う）。
    private func edgeXs(for r: DateRange) -> (start: CGFloat, end: CGFloat) {
        let total = window.duration
        guard total > 0 else { return (0, 0) }
        let clampedStart = max(r.start, window.start)
        let clampedEnd = min(r.end, window.end)
        let startX = clampedStart.timeIntervalSince(window.start) / total * Double(trackWidth)
        let endX = clampedEnd.timeIntervalSince(window.start) / total * Double(trackWidth)
        return (CGFloat(startX), CGFloat(endX))
    }

    private func pixelMetrics(for r: DateRange) -> (offset: CGFloat, length: CGFloat) {
        let total = window.duration
        guard total > 0 else { return (0, 0) }
        let clampedStart = max(r.start, window.start)
        let clampedEnd = min(r.end, window.end)
        let offset = clampedStart.timeIntervalSince(window.start) / total * Double(trackWidth)
        let length = max(0, clampedEnd.timeIntervalSince(clampedStart) / total * Double(trackWidth))
        return (CGFloat(offset), CGFloat(length))
    }

    private func timeText(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%d:%02d", hour, minute)
    }
}

// MARK: - 予定セグメント（タップでポップオーバー）

private struct EventSegment: View {
    let event: BusyInterval
    let calendar: Calendar
    let width: CGFloat
    let offset: CGFloat
    let height: CGFloat

    @State private var isShowingDetail = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .frame(width: width, height: height)
            .glassEffect(.clear.tint(.red), in: .rect(cornerRadius: 5))
            .onTapGesture { isShowingDetail = true }
            .popover(
                isPresented: $isShowingDetail,
            ) {
                detail
                    .presentationCompactAdaptation(.popover)
            }
            .offset(x: offset)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title.isEmpty ? "（無題）" : event.title)
                .font(.headline)
            Label(timeRangeText, systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 180, alignment: .leading)
    }

    private var timeRangeText: String {
        if event.isAllDay {
            return "終日"
        }
        return "\(timeText(event.start))〜\(timeText(event.end))"
    }

    private func timeText(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%d:%02d", hour, minute)
    }
}
