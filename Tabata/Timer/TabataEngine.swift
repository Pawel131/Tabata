import Foundation
import Observation

/// Drives a workout through its phases.
///
/// Timing is based on wall-clock end dates rather than counting ticks, so the
/// timer stays accurate if ticks are delayed or the app is briefly backgrounded.
@Observable
final class TabataEngine {
    enum State {
        case ready, running, paused, finished, stopped
    }

    let config: WorkoutConfig
    let phases: [Phase]

    private(set) var state: State = .ready
    private(set) var index = 0
    /// Seconds left in the current phase.
    private(set) var remaining: TimeInterval
    /// Work intervals that ran to completion.
    private(set) var completedRounds = 0
    private(set) var startDate: Date?

    @ObservationIgnored var onPhaseStart: ((Phase) -> Void)?
    @ObservationIgnored var onCountdown: ((Int) -> Void)?
    @ObservationIgnored var onFinish: (() -> Void)?

    @ObservationIgnored private var phaseEnd: Date?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCountdownSecond: Int?
    /// Start offset of each phase from the beginning of the workout.
    private let offsets: [TimeInterval]

    init(config: WorkoutConfig) {
        self.config = config
        let phases = config.phases()
        self.phases = phases
        self.remaining = phases.first?.duration ?? 0
        var running: TimeInterval = 0
        self.offsets = phases.map { phase in
            defer { running += phase.duration }
            return running
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Derived state

    var currentPhase: Phase? {
        phases.indices.contains(index) ? phases[index] : nil
    }

    var nextPhase: Phase? {
        phases.indices.contains(index + 1) ? phases[index + 1] : nil
    }

    var totalDuration: TimeInterval {
        phases.reduce(0) { $0 + $1.duration }
    }

    /// Active workout time elapsed, excluding pauses.
    var elapsed: TimeInterval {
        guard let phase = currentPhase else { return totalDuration }
        return offsets[index] + (phase.duration - remaining)
    }

    var overallProgress: Double {
        totalDuration > 0 ? min(elapsed / totalDuration, 1) : 1
    }

    var phaseProgress: Double {
        guard let phase = currentPhase, phase.duration > 0 else { return 1 }
        return min(max(1 - remaining / phase.duration, 0), 1)
    }

    var remainingSeconds: Int { Int(remaining.rounded(.up)) }

    var isActive: Bool { state == .running || state == .paused }

    // MARK: - Controls

    func start() {
        guard state == .ready, !phases.isEmpty else { return }
        let now = Date()
        startDate = now
        state = .running
        phaseEnd = now.addingTimeInterval(phases[index].duration)
        remaining = phases[index].duration
        onPhaseStart?(phases[index])
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        tick()
        guard state == .running else { return }
        state = .paused
        phaseEnd = nil
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        phaseEnd = Date().addingTimeInterval(remaining)
        state = .running
        startTimer()
    }

    func togglePause() {
        state == .running ? pause() : resume()
    }

    /// Jumps to the next phase. A skipped work interval doesn't count as completed.
    func skip() {
        guard isActive else { return }
        index += 1
        guard let phase = currentPhase else {
            finish()
            return
        }
        remaining = phase.duration
        lastCountdownSecond = nil
        if state == .running {
            phaseEnd = Date().addingTimeInterval(phase.duration)
        }
        onPhaseStart?(phase)
    }

    /// Ends the workout early.
    func stop() {
        guard state != .finished else { return }
        stopTimer()
        phaseEnd = nil
        state = .stopped
    }

    // MARK: - Ticking

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .running, var end = phaseEnd else { return }
        let now = Date()

        // Advance through every phase whose end has passed (more than one if
        // ticks were delayed), carrying the overshoot into the next phase.
        var advanced = false
        while now >= end {
            if phases[index].kind == .work {
                completedRounds += 1
            }
            index += 1
            guard index < phases.count else {
                finish()
                return
            }
            end = end.addingTimeInterval(phases[index].duration)
            lastCountdownSecond = nil
            advanced = true
        }
        phaseEnd = end
        remaining = end.timeIntervalSince(now)

        if advanced {
            onPhaseStart?(phases[index])
        }

        let second = remainingSeconds
        if (1...3).contains(second), phases[index].duration > 3, second != lastCountdownSecond {
            lastCountdownSecond = second
            onCountdown?(second)
        }
    }

    private func finish() {
        stopTimer()
        phaseEnd = nil
        index = phases.count
        remaining = 0
        state = .finished
        onFinish?()
    }
}
