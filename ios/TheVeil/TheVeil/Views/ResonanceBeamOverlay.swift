import SwiftUI

struct ResonanceBeamOverlay: View {
    let progress: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let source = CGPoint(x: size.width * 0.5, y: size.height * 0.93)
                let target = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let pulse = 0.82 + sin(time * 34) * 0.18

                var glowPath = Path()
                glowPath.move(to: source)
                glowPath.addLine(to: target)
                context.stroke(
                    glowPath,
                    with: .color(.cyan.opacity(0.18 * pulse)),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )

                for strand in 0..<3 {
                    let phase = time * (29 + Double(strand) * 4.5)
                    var path = Path()
                    path.move(to: source)

                    for step in 1...9 {
                        let fraction = Double(step) / 9
                        let y = source.y + (target.y - source.y) * fraction
                        let taper = 1 - fraction
                        let jitter = sin(phase + fraction * 21) * 3.5 * taper
                        path.addLine(to: CGPoint(x: source.x + jitter, y: y))
                    }

                    context.stroke(
                        path,
                        with: .color(strand == 1 ? .white : .cyan),
                        style: StrokeStyle(
                            lineWidth: strand == 1 ? 1.4 : 2.1,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                let contactRadius = 21 + progress * 17 + sin(time * 18) * 2
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: target.x - contactRadius,
                        y: target.y - contactRadius,
                        width: contactRadius * 2,
                        height: contactRadius * 2
                    )),
                    with: .color(.cyan.opacity(0.75)),
                    lineWidth: 1.5
                )
            }
        }
        .ignoresSafeArea()
    }
}
