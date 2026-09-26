import Foundation
import SwiftData

/// A finished (or ended-early) workout, persisted for progress tracking.
@Model
final class WorkoutRecord {
    var date: Date
    var workSeconds: Int
    var restSeconds: Int
    var roundsPerSet: Int
    var sets: Int
    var completedRounds: Int
    var totalRounds: Int
    /// Active time spent in the workout, excluding pauses.
    var duration: TimeInterval

    init(date: Date, config: WorkoutConfig, completedRounds: Int, duration: TimeInterval) {
        self.date = date
        self.workSeconds = config.work
        self.restSeconds = config.rest
        self.roundsPerSet = config.rounds
        self.sets = config.sets
        self.completedRounds = completedRounds
        self.totalRounds = config.totalRounds
        self.duration = duration
    }

    var isComplete: Bool { completedRounds >= totalRounds }
}

enum ProgressStats {
    /// Number of consecutive days with at least one workout, ending today
    /// (or yesterday, so a streak isn't lost before today's workout).
    static func streak(dates: [Date], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    struct DailyTotal: Identifiable {
        let day: Date
        let minutes: Double
        var id: Date { day }
    }

    /// Minutes trained per day for the last `days` days, oldest first.
    static func dailyTotals(records: [WorkoutRecord], days: Int = 7, calendar: Calendar = .current, now: Date = .now) -> [DailyTotal] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: TimeInterval] = [:]
        for record in records {
            totals[calendar.startOfDay(for: record.date), default: 0] += record.duration
        }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(day: day, minutes: (totals[day] ?? 0) / 60)
        }
    }
}
