import SwiftUI

/// Tap-through detail for a daily card's 3-source consensus (F3). Shows each
/// source's own verdict — the "아이폰 날씨는 비라던데 기상청은 아니네?" moment —
/// then a plain-language note about how much they agreed. Presented as a bottom
/// sheet from `DailyView`.
struct ConsensusSheet: View {
    let day: DailySummary
    let consensus: DailyConsensus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(spacing: 0) {
                ForEach(consensus.sources) { source in
                    sourceRow(source)
                    if source.id != consensus.sources.last?.id {
                        Rectangle().fill(UbiColors.divider).frame(height: 1)
                    }
                }
            }
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            note
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(hex: 0xF7FAFD))
    }

    private var header: some View {
        HStack(spacing: 10) {
            WeatherIconView(condition: day.condition, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(day.dayLabel) · \(day.conditionLabel)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2F4A6D))
                Text("세 예보의 판단을 비교했어요")
                    .font(.system(size: 12))
                    .foregroundStyle(UbiColors.textMuted)
            }
            Spacer()
            if let badge = consensus.badgeText {
                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(UbiColors.showerHighlightLabel)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0xFFF3E0))
                    .overlay(Capsule().stroke(UbiColors.showerHighlightBorder, lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
        .padding(.bottom, 16)
    }

    private func sourceRow(_ source: DailyConsensus.SourceView) -> some View {
        HStack(spacing: 10) {
            Text(source.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UbiColors.textBody)
                .frame(width: 108, alignment: .leading)

            Text(source.saysRain ? "비 옴" : "안 옴")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(source.saysRain ? Color(hex: 0x3F7FD0) : UbiColors.textMuted)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(source.saysRain ? Color(hex: 0xE8F1FC) : Color(hex: 0xEEF1F5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            HStack(spacing: 4) {
                if let pop = source.precipProbability {
                    Text("\(pop)%").font(.system(size: 13, weight: .bold)).foregroundStyle(UbiColors.textBody)
                }
                if let tmax = source.tempMax {
                    Text("· \(tmax)°").font(.system(size: 13)).foregroundStyle(UbiColors.textSub)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }

    private var note: some View {
        Text(consensus.sheetNote)
            .font(.system(size: 12.5))
            .foregroundStyle(UbiColors.textSub)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(hex: 0xF3F7FC))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.top, 14)
    }

    /// Grows with the source count so two-source fallbacks don't leave a gap.
    private var sheetHeight: CGFloat {
        CGFloat(210 + consensus.sources.count * 46)
    }
}
