import Foundation

/// User-configurable workout parameters. All durations are in seconds.
struct WorkoutConfig: Equatable {
    var prepare = 10
    var work = 20
    var rest = 10
    var rounds = 8
    var sets = 1
    var setRest = 60

    static let classic = WorkoutConfig()

    /// Total rounds (work intervals) across all sets.
    var totalRounds: Int { rounds * sets }

    /// Total length of the workout, including the prepare countdown.
    var totalDuration: Int {
        phases().reduce(0) { $0 + Int($1.duration) }
    }

    /// The ordered list of intervals that make up the workout.
    /// The final round of each set is not followed by a rest interval.
    func phases() -> [Phase] {
        var result: [Phase] = []
        if prepare > 0 {
            result.append(Phase(kind: .prepare, duration: TimeInterval(prepare), round: 1, set: 1))
        }
        for set in 1...max(sets, 1) {
            for round in 1...max(rounds, 1) {
                result.append(Phase(kind: .work, duration: TimeInterval(work), round: round, set: set))
                if round < rounds && rest > 0 {
                    result.append(Phase(kind: .rest, duration: TimeInterval(rest), round: round, set: set))
                }
            }
            if set < sets && setRest > 0 {
                result.append(Phase(kind: .setRest, duration: TimeInterval(setRest), round: rounds, set: set))
            }
        }
        return result
    }
}

struct Phase: Equatable {
    enum Kind: Equatable {
        case prepare, work, rest, setRest
    }

    let kind: Kind
    let duration: TimeInterval
    /// 1-based round within the current set.
    let round: Int
    /// 1-based set number.
    let set: Int
}

extension Phase.Kind {
    var title: String {
        switch self {
        case .prepare: "Get Ready"
        case .work: "Work"
        case .rest: "Rest"
        case .setRest: "Set Rest"
        }
    }
}

struct Preset: Identifiable {
    let name: String
    let config: WorkoutConfig
    var id: String { name }

    static let all: [Preset] = [
        Preset(name: "Classic", config: WorkoutConfig(prepare: 10, work: 20, rest: 10, rounds: 8, sets: 1, setRest: 60)),
        Preset(name: "Beginner", config: WorkoutConfig(prepare: 10, work: 20, rest: 20, rounds: 6, sets: 1, setRest: 60)),
        Preset(name: "Double", config: WorkoutConfig(prepare: 10, work: 20, rest: 10, rounds: 8, sets: 2, setRest: 60)),
        Preset(name: "Endurance", config: WorkoutConfig(prepare: 10, work: 40, rest: 20, rounds: 10, sets: 1, setRest: 60)),
        Preset(name: "HIIT 45/15", config: WorkoutConfig(prepare: 10, work: 45, rest: 15, rounds: 8, sets: 3, setRest: 90)),
    ]
}

/// Formats seconds as `m:ss`, or `h:mm:ss` for an hour or more.
func formatClock(_ seconds: Int) -> String {
    let s = max(seconds, 0)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%d:%02d", s / 60, s % 60)
}
