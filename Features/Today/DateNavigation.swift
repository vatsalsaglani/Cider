import SwiftUI
import CiderDomain
import CiderUI

struct DateNavigator: View {
    @Binding var date: Date
    var body: some View {
        HStack(spacing: 8) {
            IconAction("Previous day", symbol: "chevron.left") { date = Calendar.current.date(byAdding: .day, value: -1, to: date)! }
            Text(date.formatted(.dateTime.month(.abbreviated).day())).font(.caption).monospacedDigit()
            IconAction("Next day", symbol: "chevron.right") { date = Calendar.current.date(byAdding: .day, value: 1, to: date)! }
            IconAction("Return to today", symbol: "arrow.counterclockwise") { date = .now }
        }
    }
}

struct WeekStrip: View {
    @Binding var date: Date
    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    var body: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                Button { date = day } label: {
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption).foregroundStyle(.secondary)
                        Text(day.formatted(.dateTime.day())).font(.title2)
                    }.frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Calendar.current.isDate(day, inSameDayAs: date) ? CiderColor.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            }
        }
    }
}

struct MonthCalendar: View {
    @Binding var date: Date
    @Binding var month: Date
    let tasks: [TaskItem]
    private var days: [Date] {
        let c = Calendar.current
        let first = c.dateInterval(of: .month, for: month)!.start
        let offset = (c.component(.weekday, from: first) - c.firstWeekday + 7) % 7
        return (0..<42).compactMap { c.date(byAdding: .day, value: $0 - offset, to: first) }
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                IconAction("Previous month", symbol: "chevron.left") { shift(-1) }
                IconAction("Next month", symbol: "chevron.right") { shift(1) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 5) {
                ForEach(days.prefix(7), id: \.self) { Text($0.formatted(.dateTime.weekday(.abbreviated))).font(.caption).foregroundStyle(.secondary) }
                ForEach(days, id: \.self) { day in
                    let count = tasks.filter { $0.plannedDay == LocalDay(day) && !$0.completed }.count
                    Button { date = day; month = day } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.formatted(.dateTime.day()))
                            Text(count > 0 ? "\(count) to do" : " ").font(.caption2).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(Calendar.current.isDate(day, inSameDayAs: date) ? CiderColor.accent.opacity(0.2) : CiderColor.surface, in: RoundedRectangle(cornerRadius: 10))
                            .opacity(Calendar.current.isDate(day, equalTo: month, toGranularity: .month) ? 1 : 0.4)
                    }.buttonStyle(.plain).accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(count) tasks")
                }
            }
        }
    }
    private func shift(_ amount: Int) { month = Calendar.current.date(byAdding: .month, value: amount, to: month)! }
}
