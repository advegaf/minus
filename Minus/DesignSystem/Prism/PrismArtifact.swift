import SwiftUI

/// The signature brand artifact: a still cluster of near-black glass cubes that
/// fracture white light into red/green/blue fringes. This is the one chromatic
/// element in all of minus. The prism colors are fileprivate to this file and
/// must never appear anywhere else (enforced by DesignGuardTests).
///
/// Technique, per cube:
///   - a near-black rounded face (the glass body),
///   - three offset color clones stroked + faintly filled and composited with
///     `.plusLighter` under a 1.5pt blur, so where the clones overlap they sum
///     toward white and where they diverge they leave saturated fringes — the
///     chromatic-aberration look,
///   - a bone-white specular stroke masked to the top/left edges only.
/// The whole cluster is wrapped in `.drawingGroup()` because the blend modes and
/// blur need an offscreen buffer to sum against each other, not the canvas.
struct PrismArtifact: View {
    var size: CGFloat = 240

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One full shimmer cycle. Slow on purpose — stillness is the brand's
    /// confidence, so the drift is barely perceptible.
    private let cycle: Double = 6.65

    var body: some View {
        Group {
            if reduceMotion {
                cluster(phase: 0)
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: cycle) / cycle * 2 * .pi
                    cluster(phase: phase)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Minus prism")
    }

    // MARK: Composition

    /// The composited cube cluster for a given shimmer phase.
    private func cluster(phase: Double) -> some View {
        ZStack {
            ForEach(Array(PrismGeometry.cubes.enumerated()), id: \.offset) { _, cube in
                cubeView(cube, phase: phase)
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    private func cubeView(_ cube: PrismCube, phase: Double) -> some View {
        let scale = size / PrismGeometry.referenceSize
        let s = cube.side * size
        let radius = 2.5 * scale
        let center = CGPoint(x: cube.center.x * size, y: cube.center.y * size)

        // Per-cube shimmer: a ±1.5pt sin/cos drift seeded by the cube's phase,
        // shared by all three channels so the fringe cluster breathes as one.
        let drift = reduceMotion
            ? CGSize.zero
            : CGSize(
                width: CGFloat(sin(phase + cube.phase)) * 1.5,
                height: CGFloat(cos(phase + cube.phase)) * 1.5
            )

        return ZStack {
            // Glass body — pure black, a hair darker than obsidian so the cube
            // reads as a solid mass the fringes wrap around.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black)
                .frame(width: s, height: s)

            // Three dispersion clones — the chromatic edges.
            channelClone(.prismRed, direction: PrismGeometry.redDirection, magnitude: PrismGeometry.redMagnitude, side: s, radius: radius, scale: scale, drift: drift)
            channelClone(.prismGreen, direction: PrismGeometry.greenDirection, magnitude: PrismGeometry.greenMagnitude, side: s, radius: radius, scale: scale, drift: drift)
            channelClone(.prismBlue, direction: PrismGeometry.blueDirection, magnitude: PrismGeometry.blueMagnitude, side: s, radius: radius, scale: scale, drift: drift)

            // Specular — only the top/left edges catch light, faded to nothing
            // by the diagonal gradient mask. Composited with plusLighter so it
            // adds onto the colored edges beneath, pulling them to a bright
            // white catch exactly where the fringes overlap.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(MN.boneWhite, lineWidth: 1.4)
                .frame(width: s, height: s)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.62, y: 0.62)
                    )
                    .frame(width: s, height: s)
                )
                .blur(radius: 0.4)
                .blendMode(.plusLighter)
        }
        .rotationEffect(cube.rotation)
        .position(center)
    }

    /// One color channel of a cube: a lightly-filled, strongly-stroked face,
    /// offset along its heading, blurred, and summed with `.plusLighter`.
    private func channelClone(_ color: Color, direction: CGVector, magnitude: CGFloat, side: CGFloat, radius: CGFloat, scale: CGFloat, drift: CGSize) -> some View {
        let dx = direction.dx * magnitude * scale + drift.width
        let dy = direction.dy * magnitude * scale + drift.height
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(color, lineWidth: 1.5)
            )
            .frame(width: side, height: side)
            .offset(x: dx, y: dy)
            .blur(radius: 1.6)
            .blendMode(.plusLighter)
            .opacity(0.9)
    }
}

// MARK: - The one chromatic vocabulary in the app

/// The prism triad. Declared fileprivate here and nowhere else — the entire
/// rest of minus is obsidian, bone, graphite, fog, and ash.
private extension Color {
    static let prismRed   = Color(mnHex: 0xFF2A2A)
    static let prismBlue  = Color(mnHex: 0x2A7FFF)
    static let prismGreen = Color(mnHex: 0x2AFF2A)
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        PrismArtifact(size: 240)
    }
    .preferredColorScheme(.dark)
}
#endif
