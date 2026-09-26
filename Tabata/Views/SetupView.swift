import SwiftUI

struct SetupView: View {
    @AppStorage("config.prepare") private var prepare = WorkoutConfig.classic.prepare
    @AppStorage("config.work") private var work = WorkoutConfig.classic.work
    @AppStorage("config.rest") private var rest = WorkoutConfig.classic.rest
    @AppStorage("config.rounds") private var rounds = WorkoutConfig.classic.rounds
    @AppStorage("config.sets") private var sets = WorkoutConfig.classic.sets
    @AppStorage("config.setRest") private var setRest = WorkoutConfig.classic.setRest

    @AppStorage(WorkoutFeedback.soundKey) private var soundEnabled = true
    @AppStorage(WorkoutFeedback.voiceKey) private var voiceEnabled = true
    @AppStorage(WorkoutFeedback.hapticsKey) private var hapticsEnabled = true

    @State private var activeWorkout: ActiveWorkout?

    private var config: WorkoutConfig {
        WorkoutConfig(prepare: prepare, work: work, rest: rest, rounds: rounds, sets: sets, setRest: setRest)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    summary
                }

                Section("Presets") {
                    presets
                }

                Section("Intervals") {
                    DurationRow(title: "Work", systemImage: "flame.fill", tint: .phaseWork, seconds: $work, range: 5...600)
                    DurationRow(title: "Rest", systemImage: "pause.circle.fill", tint: .phaseRest, seconds: $rest, range: 0...600)
                    DurationRow(title: "Get Ready", systemImage: "hourglass", tint: .phasePrepare, seconds: $prepare, range: 0...60)
                }

                Section {
                    CountRow(title: "Rounds", systemImage: "repeat", value: $rounds, range: 1...50)
                    CountRow(title: "Sets", systemImage: "square.stack.3d.up.fill", value: $sets, range: 1...10)
                    if sets > 1 {
                        DurationRow(title: "Rest Between Sets", systemImage: "cup.and.saucer.fill", tint: .phaseSetRest, seconds: $setRest, range: 0...600, step: 10)
                    }
                } header: {
                    Text("Rounds")
                } footer: {
                    Text("A round is one work interval followed by a rest. Sets repeat all rounds.")
                }

                Section("Cues") {
                    Toggle("Beeps", systemImage: "speaker.wave.2.fill", isOn: $soundEnabled)
                    Toggle("Voice", systemImage: "person.wave.2.fill", isOn: $voiceEnabled)
                    Toggle("Haptics", systemImage: "iphone.radiowaves.left.and.right", isOn: $hapticsEnabled)
                }
            }
            .navigationTitle("Tabata")
            .safeAreaInset(edge: .bottom) {
                Button {
                    activeWorkout = ActiveWorkout(config: config)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.phaseWork)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .fullScreenCover(item: $activeWorkout) { workout in
                WorkoutView(config: workout.config)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text(formatClock(config.totalDuration))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: config.totalDuration)
            Text("\(config.totalRounds) rounds · \(work)s work / \(rest)s rest")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Preset.all) { preset in
                    let isSelected = preset.config == config
                    Button {
                        apply(preset.config)
                    } label: {
                        VStack(spacing: 2) {
                            Text(preset.name).font(.subheadline.bold())
                            Text("\(preset.config.work)/\(preset.config.rest) × \(preset.config.totalRounds)")
                                .font(.caption)
                                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.phaseWork : Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private func apply(_ preset: WorkoutConfig) {
        withAnimation {
            prepare = preset.prepare
            work = preset.work
            rest = preset.rest
            rounds = preset.rounds
            sets = preset.sets
            setRest = preset.setRest
        }
    }
}

private struct ActiveWorkout: Identifiable {
    let id = UUID()
    let config: WorkoutConfig
}

private struct DurationRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    var step = 5

    var body: some View {
        Stepper(value: $seconds, in: range, step: step) {
            HStack {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                Spacer()
                Text(seconds < 60 ? "\(seconds)s" : formatClock(seconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CountRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(value)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SetupView()
}
