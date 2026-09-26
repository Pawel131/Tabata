import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "figure.highintensity.intervaltraining",
                        description: Text("Finish a workout and your progress will show up here.")
                    )
                } else {
                    List {
                        Section {
                            StatsGrid(records: records)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        Section("Last 7 Days") {
                            WeeklyChart(records: records)
                                .padding(.vertical, 8)
                        }

                        Section("Workouts") {
                            ForEach(records) { record in
                                RecordRow(record: record)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}

private struct StatsGrid: View {
    let records: [WorkoutRecord]

    private var totalTime: TimeInterval { records.reduce(0) { $0 + $1.duration } }
    private var totalRounds: Int { records.reduce(0) { $0 + $1.completedRounds } }
    private var streak: Int { ProgressStats.streak(dates: records.map(\.date)) }
    private var thisWeek: Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return records.filter { week.contains($0.date) }.count
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(title: "Workouts", value: "\(records.count)", systemImage: "checkmark.seal.fill", tint: .phaseDone)
            StatCard(title: "Day Streak", value: "\(streak)", systemImage: "flame.fill", tint: .phasePrepare)
            StatCard(title: "Total Time", value: formatClock(Int(totalTime)), systemImage: "clock.fill", tint: .phaseRest)
            StatCard(title: "Rounds", value: "\(totalRounds)", systemImage: "repeat", tint: .phaseWork)
            StatCard(title: "This Week", value: "\(thisWeek)", systemImage: "calendar", tint: .phaseSetRest)
            StatCard(title: "Completion", value: completionRate, systemImage: "target", tint: .teal)
        }
    }

    private var completionRate: String {
        guard !records.isEmpty else { return "–" }
        let complete = records.filter(\.isComplete).count
        return "\(Int((Double(complete) / Double(records.count) * 100).rounded()))%"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}

private struct WeeklyChart: View {
    let records: [WorkoutRecord]

    var body: some View {
        let totals = ProgressStats.dailyTotals(records: records)
        Chart(totals) { total in
            BarMark(
                x: .value("Day", total.day, unit: .day),
                y: .value("Minutes", total.minutes)
            )
            .foregroundStyle(Color.phaseWork.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxisLabel("min")
        .frame(height: 160)
    }
}

private struct RecordRow: View {
    let record: WorkoutRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isComplete ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(record.isComplete ? Color.phaseDone : Color.phasePrepare)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    .font(.subheadline.weight(.semibold))
                Text("\(record.workSeconds)s / \(record.restSeconds)s · \(record.completedRounds)/\(record.totalRounds) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatClock(Int(record.duration)))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
