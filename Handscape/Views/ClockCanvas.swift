import SwiftUI

struct ClockCanvas: View {
    let poses: [HandPose]
    let stacked: Bool
    let handColor: Color
    let showFaces: Bool
    let faceFill: Color
    let faceOutline: Color

    init(
        poses: [HandPose], stacked: Bool, handColor: Color, showFaces: Bool,
        faceFill: Color = Color(white: 0.12), faceOutline: Color? = nil
    ) {
        self.poses = poses
        self.stacked = stacked
        self.handColor = handColor
        self.showFaces = showFaces
        self.faceFill = faceFill
        self.faceOutline = faceOutline ?? handColor.opacity(0.24)
    }

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let layout = ClockBoardLayout(stacked: stacked)
            let scale = min(size.width / layout.width, size.height / layout.height)
            let origin = CGPoint(
                x: (size.width - layout.width * scale) / 2,
                y: (size.height - layout.height * scale) / 2
            )
            let radius = scale * ClockHandGeometry.dialRadius
            let lineWidth = max(2, scale * ClockHandGeometry.strokeRatio)

            for index in poses.indices {
                let position = layout.position(for: index)
                let center = CGPoint(x: origin.x + position.x * scale, y: origin.y + position.y * scale)
                let face = CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )

                if showFaces {
                    context.fill(Path(ellipseIn: face), with: .color(faceFill))
                    context.stroke(
                        Path(ellipseIn: face), with: .color(faceOutline),
                        lineWidth: max(0.5, scale * 0.008)
                    )
                }

                let pose = poses[index]
                let color = handColor.opacity(pose.emphasis)
                // Leave room for thicker rounded caps inside each dial.
                for (angle, length) in [(pose.first, radius * ClockHandGeometry.firstLengthRatio),
                                        (pose.second, radius * ClockHandGeometry.secondLengthRatio)] {
                    let radians = angle * .pi / 180
                    let tip = CGPoint(
                        x: center.x + sin(radians) * length,
                        y: center.y - cos(radians) * length
                    )
                    var hand = Path()
                    hand.move(to: center)
                    hand.addLine(to: tip)
                    context.stroke(
                        hand, with: .color(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                let hub = CGRect(
                    x: center.x - lineWidth * 0.52, y: center.y - lineWidth * 0.52,
                    width: lineWidth * 1.04, height: lineWidth * 1.04
                )
                context.fill(Path(ellipseIn: hub), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

