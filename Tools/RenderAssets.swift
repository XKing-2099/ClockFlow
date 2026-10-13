import AppKit
import SwiftUI
import ImageIO

/// Generates the icon and visual QA artifacts from the app's actual clock Canvas.
/// Run from the repository root; this tool is not included in the iOS target.
@main
struct RenderAssets {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let previews = root.appendingPathComponent("Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

        let poses = [1, 0, 0, 8].flatMap(ClockDigits.poses(for:))
        try save(
            ClockPreview(poses: poses, stacked: false, palette: .graphite).frame(width: 1280, height: 580),
            to: previews.appendingPathComponent("landscape.png")
        )
        try save(
            ClockPreview(poses: poses, stacked: true, palette: .graphite).frame(width: 430, height: 850),
            to: previews.appendingPathComponent("portrait.png")
        )
        try save(
            ClockPreview(poses: poses, stacked: false, palette: .graphite, showDate: true).frame(width: 912, height: 420),
            to: previews.appendingPathComponent("landscape-date.png")
        )
        try save(
            ClockPreview(poses: poses, stacked: true, palette: .graphite, showDate: true).frame(width: 430, height: 850),
            to: previews.appendingPathComponent("portrait-date.png")
        )
        try save(
            ImmersiveArtwork(poses: poses, stacked: false).frame(width: 912, height: 420),
            to: previews.appendingPathComponent("immersive-landscape.png")
        )
        try save(
            ImmersiveArtwork(poses: poses, stacked: true).frame(width: 430, height: 850),
            to: previews.appendingPathComponent("immersive-portrait.png")
        )
        try save(
            CelebrationGallery().frame(width: 1280, height: 880),
            to: previews.appendingPathComponent("celebrations.png")
        )
        try save(
            ChoreographyGallery().frame(width: 1280, height: 1120),
            to: previews.appendingPathComponent("choreographies.png")
        )
        try saveHourAnimation(to: previews.appendingPathComponent("hour-celebration.gif"))
        try save(
            DigitGallery().frame(width: 1200, height: 540),
            to: previews.appendingPathComponent("digits.png")
        )
        try save(
            AppIconArtwork().frame(width: 1024, height: 1024),
            to: root.appendingPathComponent("Handscape/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        )
        try save(
            AppIconArtwork().frame(width: 180, height: 180),
            to: previews.appendingPathComponent("app-icon.png")
        )
        print("Rendered normal/immersive layouts, six pictures, eight dances, hour animation, digits, and app icon.")
    }

    @MainActor
    private static func save<Content: View>(_ content: Content, to url: URL) throws {
        let opaqueImage = try render(content)
        let bitmap = NSBitmapImageRep(cgImage: opaqueImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.noImage }
        try data.write(to: url)
    }

    @MainActor
    private static func render<Content: View>(_ content: Content) throws -> CGImage {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else { throw RenderError.noRenderedImage }
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw RenderError.noBitmapContext }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let opaqueImage = context.makeImage() else { throw RenderError.noBitmapImage }
        return opaqueImage
    }

    @MainActor
    private static func saveHourAnimation(to url: URL) throws {
        let from = [0, 9, 5, 9].flatMap(ClockDigits.poses(for:))
        let to = [1, 0, 0, 0].flatMap(ClockDigits.poses(for:))
        let plan = Choreography.makePlan(from: from, to: to, style: .ripple, duration: 6,
                                         occasion: .hour, celebration: .bloom)
        let count = Int((plan.duration + 1) * 8) + 1
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, count, nil) else {
            throw RenderError.noImage
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<count {
            let content = ImmersiveArtwork(poses: plan.poses(at: Double(frame) / 8), stacked: false)
                .frame(width: 912, height: 420)
            let image = try render(content)
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.125]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { throw RenderError.noImage }
    }

    private enum RenderError: Error { case noImage, noRenderedImage, noBitmapContext, noBitmapImage }
}

private struct ImmersiveArtwork: View {
    let poses: [HandPose]
    let stacked: Bool
    private let palette = HandPalette.graphite

    var body: some View {
        ClockPreview(poses: poses, stacked: stacked, palette: palette, immersive: true)
    }
}

private struct CelebrationGallery: View {
    private let patterns = CelebrationPattern.allCases
    private let palette = HandPalette.graphite

    var body: some View {
        VStack(spacing: 22) {
            ForEach(0..<3) { row in
                HStack(spacing: 28) {
                    ForEach(0..<2) { column in
                        let pattern = patterns[row * 2 + column]
                        VStack(spacing: 12) {
                            Text(pattern.title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            ClockCanvas(poses: Choreography.patternPoses(pattern, stacked: false), stacked: false,
                                        handColor: palette.color, showFaces: true,
                                        faceFill: palette.faceFill, faceOutline: palette.faceOutline)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(.black)
    }
}

private struct ChoreographyGallery: View {
    private let styles = MotionStyle.dances
    private let palette = HandPalette.graphite

    var body: some View {
        VStack(spacing: 22) {
            ForEach(0..<4) { row in
                HStack(spacing: 28) {
                    ForEach(0..<2) { column in
                        let style = styles[row * 2 + column]
                        let from = [0, 9, 5, 9].flatMap(ClockDigits.poses(for:))
                        let to = [1, 0, 0, 0].flatMap(ClockDigits.poses(for:))
                        let plan = Choreography.makePlan(from: from, to: to, style: style, duration: 6)
                        let sampleTime = plan.segments.first(where: \.isHold).map { $0.startedAt + $0.duration / 2 } ?? 3
                        VStack(spacing: 12) {
                            Text(style.title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            ClockCanvas(poses: plan.poses(at: sampleTime), stacked: false,
                                        handColor: palette.color, showFaces: true,
                                        faceFill: palette.faceFill, faceOutline: palette.faceOutline)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(.black)
    }
}

private struct ClockPreview: View {
    let poses: [HandPose]
    let stacked: Bool
    let palette: HandPalette
    var immersive = false
    var showDate = false

    var body: some View {
        GeometryReader { geometry in
            // Representative phone safe areas, not a screenshot or device specification.
            let insets = stacked ? ClockSafeInsets(top: 62, bottom: 34)
                : ClockSafeInsets(bottom: 21, leading: 59, trailing: 59)
            let viewport = ClockBoardViewport(
                width: geometry.size.width - insets.leading - insets.trailing,
                height: geometry.size.height - insets.top - insets.bottom,
                stacked: stacked, immersive: immersive, showDate: showDate, safeInsets: insets
            )
            ZStack {
                Color.black
                ClockCanvas(
                    poses: poses, stacked: stacked, handColor: palette.color, showFaces: true,
                    faceFill: palette.faceFill, faceOutline: palette.faceOutline
                )
                .frame(width: viewport.width, height: viewport.height)
                .position(x: viewport.center.x + insets.leading, y: viewport.center.y + insets.top)
                if let date = viewport.dateCenter {
                    Text("10月10日 星期六")
                        .font(.system(size: ClockBoardViewport.dateFontSize, weight: .medium))
                        .foregroundStyle(palette.color.opacity(0.42))
                        .frame(height: ClockBoardViewport.dateHeight)
                        .position(x: date.x + insets.leading, y: date.y + insets.top)
                }
                if !immersive {
                    VStack {
                        HStack {
                            Text("CLOCKFLOW").tracking(4).font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Spacer()
                            Text("24 CLOCKS / 48 HANDS").tracking(2).font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        HStack {
                            Text("10:08").font(.system(size: 12, weight: .medium, design: .monospaced))
                            Spacer()
                            Text("自动轮换  ·  每分钟，重新组成时间")
                                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.32))
                        }
                        .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, stacked ? 26 : 36)
                    .padding(.top, insets.top + 20)
                    .padding(.bottom, insets.bottom + (stacked ? 24 : 16))
                    .padding(.leading, insets.leading)
                    .padding(.trailing, insets.trailing)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct DigitGallery: View {
    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<2) { row in
                HStack(spacing: 24) {
                    ForEach(0..<5) { column in
                        let digit = row * 5 + column
                        VStack(spacing: 10) {
                            DigitArtwork(digit: digit)
                            Text("\(digit)").font(.system(size: 14, design: .monospaced)).foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(.black)
    }
}

private struct DigitArtwork: View {
    let digit: Int
    private let palette = HandPalette.graphite

    var body: some View {
        Canvas { context, size in
            let poses = ClockDigits.poses(for: digit)
            let unit = min(size.width / 2.15, size.height / 3.15)
            let origin = CGPoint(x: (size.width - unit * 2.08) / 2, y: (size.height - unit * 3.16) / 2)
            for index in 0..<6 {
                let center = CGPoint(
                    x: origin.x + (0.5 + Double(index % 2) * 1.08) * unit,
                    y: origin.y + (0.5 + Double(index / 2) * 1.08) * unit
                )
                let face = Path(ellipseIn: CGRect(
                    x: center.x - unit * 0.49, y: center.y - unit * 0.49,
                    width: unit * 0.98, height: unit * 0.98
                ))
                context.fill(face, with: .color(palette.faceFill))
                context.stroke(face, with: .color(palette.faceOutline), lineWidth: 0.6)
                for (angle, lengthRatio) in [(poses[index].first, ClockHandGeometry.firstLengthRatio),
                                             (poses[index].second, ClockHandGeometry.secondLengthRatio)] {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: center.x + sin(angle * .pi / 180) * unit * ClockHandGeometry.dialRadius * lengthRatio,
                        y: center.y - cos(angle * .pi / 180) * unit * ClockHandGeometry.dialRadius * lengthRatio
                    ))
                    context.stroke(path, with: .color(palette.color.opacity(poses[index].emphasis)), style: StrokeStyle(lineWidth: unit * ClockHandGeometry.strokeRatio, lineCap: .round))
                }
            }
        }
    }
}

private struct AppIconArtwork: View {
    private let poses = [1, 0, 2, 5].flatMap(ClockDigits.poses(for:))
    private let palette = HandPalette.graphite

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                // Use the portrait clock's real glyphs: hours above minutes.
                // Keep the source square and opaque; iOS applies the icon mask.
                ClockCanvas(
                    poses: poses, stacked: true, handColor: palette.color,
                    showFaces: true, faceFill: palette.faceFill,
                    faceOutline: palette.faceOutline
                )
                .padding(geometry.size.width * 0.07)
            }
        }
    }
}

