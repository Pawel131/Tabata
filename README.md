# Tabata

A Tabata / interval timer for iPhone and iPad, built with SwiftUI.

## Features

- **Configurable workout**: work time, rest time, rounds, sets, rest between sets, and a "get ready" countdown. Built-in presets (Classic 20/10 × 8, Beginner, Double, Endurance, HIIT 45/15). Your settings are remembered.
- **Live workout screen**: full-screen color per phase (get ready / work / rest / set rest), a large countdown, a ring for the current interval, round dots, and overall elapsed and remaining time.
- **Controls**: pause/resume, skip interval, end early (asks you to confirm).
- **Cues**: 3-2-1 countdown beeps, spoken announcements ("Round 3. Work!", "Rest", "Last round"), and haptics. Each can be turned off. Audio mixes with your music.
- **Accurate timing**: the timer runs from wall-clock end times, not tick counts, so it stays correct if the app is briefly in the background. The screen stays awake during a workout.
- **Progress tracking**: each workout is saved with SwiftData. The Progress tab shows total workouts, day streak, total time, rounds, workouts this week, completion rate, a chart of minutes trained over the last 7 days, and a full history you can swipe to delete.

## Requirements

- Xcode 16 or later
- iOS 17.0 or later

## Running

1. Open `Tabata.xcodeproj` in Xcode.
2. Pick an iPhone simulator or your device.
3. To run on a device, choose your team under *Signing & Capabilities* and change the bundle identifier (`com.example.tabata`) if needed.
4. Press ⌘R.

## Project layout

```
Tabata/
  App/TabataApp.swift          App entry point and tab view
  Models/WorkoutConfig.swift   Workout settings, phase list, presets
  Models/WorkoutRecord.swift   SwiftData history model and progress stats
  Timer/TabataEngine.swift     Timer state machine
  Timer/WorkoutFeedback.swift  Beeps, voice, and haptics
  Views/SetupView.swift        Settings screen
  Views/WorkoutView.swift      Live workout and summary screens
  Views/HistoryView.swift      Progress stats, chart, and history
  Views/PhaseStyle.swift       Phase colors and progress ring
```

The Xcode project uses a synchronized folder group, so any file you add under `Tabata/` is included in the build automatically.
