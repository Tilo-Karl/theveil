import SwiftUI

struct MegaResonanceBeamOverlay: View {
    let startedAt: Date
    let currentCharge: Int
    let peakCharge: Int
    let capacitorCapacity: Int
    let intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let remaining = Double(currentCharge) / Double(max(peakCharge, 1))
                let source = CGPoint(x: size.width * 0.5, y: size.height * 0.94)
                let target = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let beamWidth = 8 + intensity * 26
                let pulse = 0.82 + sin(elapsed * 52) * 0.18

                var cone = Path()
                cone.move(to: CGPoint(x: source.x - beamWidth * 0.7, y: source.y))
                cone.addLine(to: CGPoint(x: target.x - beamWidth * 0.12, y: target.y))
                cone.addLine(to: CGPoint(x: target.x + beamWidth * 0.12, y: target.y))
                cone.addLine(to: CGPoint(x: source.x + beamWidth * 0.7, y: source.y))
                cone.closeSubpath()

                context.fill(
                    cone,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.55, green: 0.2, blue: 1).opacity(0.2 * remaining),
                            Color.cyan.opacity(0.5 * remaining),
                            Color.white.opacity(0.82 * remaining)
                        ]),
                        startPoint: source,
                        endPoint: target
                    )
                )

                for strand in 0..<5 {
                    let strandPhase = elapsed * (39 + Double(strand) * 3.7)
                    let offset = sin(strandPhase) * beamWidth * 0.32
                    var path = Path()
                    path.move(to: CGPoint(x: source.x + offset, y: source.y))

                    for step in 1...7 {
                        let fraction = Double(step) / 7
                        let y = source.y + (target.y - source.y) * fraction
                        let taper = 1 - fraction
                        let jitter = sin(strandPhase + fraction * 19) * beamWidth * 0.28 * taper
                        path.addLine(to: CGPoint(x: source.x + jitter, y: y))
                    }

                    context.stroke(
                        path,
                        with: .color(strand.isMultiple(of: 2) ? .white : .cyan),
                        style: StrokeStyle(
                            lineWidth: (1.2 + intensity * 2.4) * pulse,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                let ringProgress = 1 - remaining
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: target.x - 42 - ringProgress * 95,
                        y: target.y - 42 - ringProgress * 95,
                        width: 84 + ringProgress * 190,
                        height: 84 + ringProgress * 190
                    )),
                    with: .color(
                        Color(red: 0.66, green: 0.3, blue: 1)
                            .opacity(remaining * 0.78)
                    ),
                    lineWidth: 2 + intensity * 2
                )
            }
            .background(
                Color.white.opacity(
                    currentCharge > capacitorCapacity
                        ? 0.04 + intensity * 0.08
                        : 0
                )
            )
        }
        .ignoresSafeArea()
    }
}
