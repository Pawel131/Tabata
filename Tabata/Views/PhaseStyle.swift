import SwiftUI

extension Color {
    static let phasePrepare = Color.orange
    static let phaseWork = Color(red: 0.96, green: 0.27, blue: 0.24)
    static let phaseRest = Color(red: 0.16, green: 0.55, blue: 0.95)
    static let phaseSetRest = Color.indigo
    static let phaseDone = Color(red: 0.18, green: 0.72, blue: 0.40)
}

extension Phase.Kind {
    var color: Color {
        switch self {
        case .prepare: .phasePrepare
        case .work: .phaseWork
        case .rest: .phaseRest
        case .setRest: .phaseSetRest
        }
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
