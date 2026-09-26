import SwiftData
import SwiftUI

struct WorkoutView: View {
    let config: WorkoutConfig

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine: TabataEngine
    @State private var feedback = WorkoutFeedback()
    @State private var showEndConfirmation = false
    @State private var saved = false

    init(config: WorkoutConfig) {
        self.config = config
        _engine = State(initialValue: TabataEngine(config: config))
    }

    private var backgroundColor: Color {
        if engine.state == .finished { return .phaseDone }
        if engine.state == .paused { return Color(white: 0.3) }
        return engine.currentPhase?.kind.color ?? .phaseDone
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: backgroundColor)

            if engine.state == .finished {
                WorkoutSummaryView(engine: engine) { dismiss() }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                timerContent
            }
        }
        .foregroundStyle(.white)
        .animation(.spring, value: engine.state)
        .statusBarHidden()
        .onAppear(perform: begin)
        .onDisappear(perform: tearDown)
        .onChange(of: engine.state) { _, state in
            if state == .finished { save() }
        }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active && engine.isActive
        }
        .confirmationDialog("End workout?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End Workout", role: .destructive, action: endEarly)
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text(engine.completedRounds > 0
                 ? "Your \(engine.completedRounds) completed round\(engine.completedRounds == 1 ? "" : "s") will be saved."
                 : "No rounds completed yet, so nothing will be saved.")
        }
    }

    // MARK: - Timer UI

    private var timerContent: some View {
        VStack(spacing: 24) {
            header

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text(engine.state == .paused ? "Paused" : (engine.currentPhase?.kind.title ?? ""))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .textCase(.uppercase)
                    .contentTransition(.opacity)

                ZStack {
                    ProgressRing(progress: engine.phaseProgress, lineWidth: 18)
                    Text(formatClock(engine.remainingSeconds))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(36)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: engine.remainingSeconds)
                }
                .frame(maxWidth: 320, maxHeight: 320)
                .padding(.vertical, 8)

                if let next = engine.nextPhase {
                    Text("Next: \(next.kind.title) · \(Int(next.duration))s")
                        .font(.headline)
                        .opacity(0.8)
                }
            }

            roundIndicator

            Spacer(minLength: 0)

            overallProgress

            controls
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Button {
                if engine.isActive {
                    showEndConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: .circle)
            }
            .accessibilityLabel("End workout")

            Spacer()

            if config.sets > 1, let phase = engine.currentPhase {
                Text("Set \(phase.set) of \(config.sets)")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: .capsule)
            }
        }
    }

    private var roundIndicator: some View {
        VStack(spacing: 10) {
            if let phase = engine.currentPhase {
                Text(phase.kind == .prepare ? "\(config.totalRounds) rounds ahead" : "Round \(phase.round) of \(config.rounds)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            if config.rounds <= 20 {
                HStack(spacing: 6) {
                    ForEach(1...config.rounds, id: \.self) { round in
                        Capsule()
                            .fill(.white.opacity(roundOpacity(round)))
                            .frame(height: 8)
                    }
                }
                .frame(maxWidth: 360)
            }
        }
    }

    /// Filled for rounds done in the current set, brighter for the one in progress.
    private func roundOpacity(_ round: Int) -> Double {
        guard let phase = engine.currentPhase, phase.kind != .prepare else { return 0.25 }
        if round < phase.round { return 1 }
        if round == phase.round {
            return phase.kind == .work ? 0.65 : 1
        }
        return 0.25
    }

    private var overallProgress: some View {
        VStack(spacing: 6) {
            ProgressView(value: engine.overallProgress)
                .tint(.white)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
            HStack {
                Text("\(formatClock(Int(engine.elapsed))) elapsed")
                Spacer()
                Text("\(formatClock(Int((engine.totalDuration - engine.elapsed).rounded(.up)))) left")
            }
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .opacity(0.85)
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            ControlButton(systemImage: "stop.fill", size: 64) {
                showEndConfirmation = true
            }
            .accessibilityLabel("Stop")

            ControlButton(systemImage: engine.state == .paused ? "play.fill" : "pause.fill", size: 88) {
                engine.togglePause()
            }
            .accessibilityLabel(engine.state == .paused ? "Resume" : "Pause")

            ControlButton(systemImage: "forward.end.fill", size: 64) {
                engine.skip()
            }
            .accessibilityLabel("Skip interval")
        }
        .padding(.bottom, 8)
    }

    // MARK: - Lifecycle

    private func begin() {
        let config = config
        let feedback = feedback
        feedback.activate()
        engine.onPhaseStart = { feedback.phaseStarted($0, config: config) }
        engine.onCountdown = { feedback.countdown($0) }
        engine.onFinish = { feedback.finished() }
        UIApplication.shared.isIdleTimerDisabled = true
        engine.start()
    }

    private func tearDown() {
        engine.stop()
        feedback.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func endEarly() {
        engine.stop()
        save()
        dismiss()
    }

    private func save() {
        guard !saved, engine.completedRounds > 0 else { return }
        saved = true
        let record = WorkoutRecord(
            date: engine.startDate ?? .now,
            config: config,
            completedRounds: engine.completedRounds,
            duration: engine.elapsed
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}

private struct ControlButton: View {
    let systemImage: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .bold))
                .frame(width: size, height: size)
                .background(.white.opacity(0.22), in: .circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct WorkoutSummaryView: View {
    let engine: TabataEngine
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .symbolEffect(.bounce, value: engine.state)

            VStack(spacing: 6) {
                Text("Workout Complete")
                    .font(.largeTitle.bold())
                Text("Nice work — every round counts.")
                    .font(.headline)
                    .opacity(0.85)
            }

            HStack(spacing: 12) {
                SummaryStat(title: "Time", value: formatClock(Int(engine.elapsed)))
                SummaryStat(title: "Rounds", value: "\(engine.completedRounds)/\(engine.config.totalRounds)")
                SummaryStat(title: "Work", value: formatClock(engine.completedRounds * engine.config.work))
            }
            .padding(.horizontal)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: .rect(cornerRadius: 16))
                    .foregroundStyle(Color.phaseDone)
            }
            .padding(.horizontal, 24)
            .padding(.bottom)
        }
    }
}

private struct SummaryStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.2), in: .rect(cornerRadius: 14))
    }
}

#Preview {
    WorkoutView(config: .classic)
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
