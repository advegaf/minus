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
    /// Dispersion is a blend, and a blend needs to know what it is blending
    /// onto. On the void the fringes ADD toward white; on paper they have to
    /// subtract, or additive math over near-white leaves nothing at all.
    @Environment(\.colorScheme) private var colorScheme

    private var onPaper: Bool { colorScheme == .light }

    /// One full shimmer cycle. Slow on purpose — stillness is the brand's
    /// confidence, so the drift is barely perceptible.
    private let cycle: Double = 6.65

    /// UITestMode renders the phase-0 still: deterministic screenshots, and
    /// no continuous TimelineView redraw — the iOS 27 simulator renders in
    /// software, where the per-frame blur + plusLighter stack kept the main
    /// thread busy enough to time out XCUITest snapshots (Phase 0 finding).
    private var isStatic: Bool {
        #if DEBUG
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-UITestMode")
        #else
        reduceMotion
        #endif
    }

    var body: some View {
        Group {
            if isStatic {
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
            // Glass body — a hair away from the canvas, never a mass. Black
            // sits 6% off obsidian and white sits 3% off paper, so on either
            // ground the cube all but disappears and the dispersion is the
            // whole subject. Filling it with ink on paper would invert that
            // relationship rather than mirror it: the mass would become the
            // subject and the light a faint halo.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(onPaper ? Color.white : Color.black)
                .frame(width: s, height: s)

            // Three dispersion clones — the chromatic edges. One triad for
            // both grounds: the blend does the work, not the palette. Neon
            // green multiplied onto paper lands at (41, 244, 39), the mirror
            // of that same neon added onto black.
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
                // The catch flips with everything else: MN.boneWhite already
                // resolves to ink on paper, so adding becomes multiplying and
                // the white highlight becomes a dark one.
                .blendMode(onPaper ? .multiply : .plusLighter)
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
            // Three washes stack, and multiplying stacks harder than adding
            // does, so paper takes half. Dropping it entirely left the faces
            // flat white, where the dark ones carry a faint chromatic tint.
            .fill(color.opacity(onPaper ? 0.05 : 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    // A multiplied edge through a blur reads fainter than an
                    // additive one, so paper gets a heavier stroke to land at
                    // the same intensity.
                    .stroke(color, lineWidth: onPaper ? 2.1 : 1.5)
            )
            .frame(width: side, height: side)
            .offset(x: dx, y: dy)
            .blur(radius: 1.6)
            // The mirror image of the same idea: on the void the channels sum
            // toward white where they overlap, on paper they multiply toward
            // ink. Either way the overlap is where the light gathers.
            .blendMode(onPaper ? .multiply : .plusLighter)
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
