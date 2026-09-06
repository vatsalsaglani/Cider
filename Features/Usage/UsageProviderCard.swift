import SwiftUI
import CiderDomain
import CiderUI
import CiderPlatform

struct UsageProviderCard: View {
    let provider: String
    let value: ProviderUsage?
    let mode: UsageDisplayMode
    let enabled: Bool
    let refreshing: Bool
    let message: String?
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            card(now: context.date)
        }
    }
    private func card(now: Date) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 16) {
            HStack(spacing: 7) {
                BrandImage(provider, size: compact ? 18 : 26)
                Text(provider == "codex" ? "Codex" : "Claude Code").font(compact ? .caption.weight(.semibold) : .title2)
                Spacer()
                if refreshing { ProgressView().controlSize(.mini) }
                else if let observed = value?.observedAt {
                    Text(age(observed, now: now)).font(.system(size: compact ? 9 : 11)).foregroundStyle(.secondary)
                }
            }
            if !enabled {
                Text("Turn on in connection settings").font(.caption).foregroundStyle(.secondary)
            } else if let value {
                if !compact { Text(value.account ?? "Current account").font(.caption).foregroundStyle(.secondary) }
                LazyVGrid(columns: compact ? Array(repeating: GridItem(.flexible(), spacing: 6), count: min(3, max(1, value.displayQuotas.count))) : [GridItem(.adaptive(minimum: 240), alignment: .leading)], alignment: .leading, spacing: 12) {
                    ForEach(value.displayQuotas) { quota in
                        quotaCell(quota, value: value, now: now)
                    }
                }
                if compact {
                    let summary = paceSummary(value, now: now)
                    Text(summary.text).font(.system(size: 9)).foregroundStyle(summary.warning ? CiderColor.warning : .secondary)
                        .lineLimit(1).help(summary.text + ". Estimated from the reported window average; model limits are separate.")
                } else {
                    Text("Estimates use each window’s average so far and assume the same pace until reset. Model limits are separate; they are not extra capacity.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(value.source == "cli" ? "Agent command line" : "Agent sign-in").font(.caption2).foregroundStyle(.secondary)
                }
                if message != nil { Text("Showing the last successful update").font(.caption2).foregroundStyle(.secondary) }
            } else { Text(refreshing ? "Reading usage…" : "No usage yet").font(.caption).foregroundStyle(.secondary) }
            if enabled, let message {
                Text(message).font(.caption2).foregroundStyle(CiderColor.warning).lineLimit(compact ? 2 : nil)
            }
        }.padding(.horizontal, compact ? 10 : 20).padding(.vertical, compact ? 7 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: compact ? 12 : 18))
    }
    private func quotaCell(_ quota: Quota, value: ProviderUsage, now: Date) -> some View {
        let pace = UsagePace.estimate(quota: quota, observedAt: value.observedAt, now: now)
        let percent = mode.percent(for: quota)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: compact ? 7 : 12) {
                UsageRing(percent: percent, warning: pace.warning || (quota.validUsedPercent ?? 0) >= 90, size: compact ? 36 : 58,
                          label: quota.label + " " + mode.rawValue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quota.shortLabel).font(compact ? .system(size: 10, weight: .medium) : .headline).lineLimit(1)
                    if !compact { Text(mode.title).font(.caption).foregroundStyle(.secondary) }
                    Text(resetLabel(quota, now: now)).font(.system(size: compact ? 8 : 11)).foregroundStyle(.secondary).lineLimit(compact ? 1 : 2)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !compact {
                Text(pace.note).font(.caption).foregroundStyle(pace.warning ? CiderColor.warning : .secondary)
                if let hourly = pace.hourlyPercent { Text("Average \(hourly.formatted(.number.precision(.fractionLength(0...2))))% of this limit per hour").font(.caption2).foregroundStyle(.secondary) }
            }
        }.help(quota.label + ": " + (percent.map { "\(Int($0.rounded()))% \(mode.rawValue)" } ?? "Not reported by this connection") + ". " + resetHelp(quota) + ". " + pace.note)
    }
    private func paceSummary(_ value: ProviderUsage, now: Date) -> (text: String, warning: Bool) {
        let estimates = value.quotas.map { ($0, UsagePace.estimate(quota: $0, observedAt: value.observedAt, now: now)) }
        let selected = estimates.filter { $0.1.warning }.max { ($0.1.projectedUsedAtReset ?? 0) < ($1.1.projectedUsedAtReset ?? 0) }
            ?? estimates.filter { $0.1.state != .unknown }.max { ($0.1.projectedUsedAtReset ?? 0) < ($1.1.projectedUsedAtReset ?? 0) }
            ?? estimates.first
        guard let (quota, pace) = selected else { return ("Pace unavailable", false) }
        return (quota.shortLabel + " · " + pace.note, pace.warning)
    }
    private func resetLabel(_ quota: Quota, now: Date) -> String {
        guard let reset = quota.resetDate else { return quota.validUsedPercent == nil ? "Not reported" : "Reset unknown" }
        return reset > now ? "↻ " + UsagePace.durationLabel(reset.timeIntervalSince(now)) : "Reset due"
    }
    private func resetHelp(_ quota: Quota) -> String {
        quota.resetDate.map { "Resets " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "Reset not reported"
    }
    private func age(_ observed: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(observed)
        return seconds < 60 ? "Just updated" : UsagePace.durationLabel(seconds) + " ago"
    }
}
