import SwiftUI

/// Unit-space layout for the PrismArtifact cube cluster. Deliberately colorless
/// — the chromatic vocabulary is fileprivate to PrismArtifact.swift so it can
/// never leak into general UI.
struct PrismCube {
    /// Center in unit coordinates (0…1), origin top-left.
    var center: CGPoint
    /// Side length as a fraction of the canvas.
    var side: CGFloat
    /// Face rotation — a mix of upright squares (0°) and 45° diamonds.
    var rotation: Angle
    /// Shimmer phase seed (radians) so cubes drift out of sync.
    var phase: Double
}

/// The cluster recipe and dispersion vectors, resolved against a 240pt
/// reference canvas and scaled by `PrismArtifact` for other sizes.
enum PrismGeometry {
    /// A tight, asymmetric cluster: two upright squares anchor the mass, three
    /// diamonds cross their edges so faces overlap and light can fracture where
    /// they meet.
    static let cubes: [PrismCube] = [
        PrismCube(center: CGPoint(x: 0.44, y: 0.42), side: 0.36, rotation: .degrees(0),  phase: 0.0),
        PrismCube(center: CGPoint(x: 0.61, y: 0.54), side: 0.27, rotation: .degrees(45), phase: 1.3),
        PrismCube(center: CGPoint(x: 0.53, y: 0.29), side: 0.21, rotation: .degrees(45), phase: 2.7),
        PrismCube(center: CGPoint(x: 0.35, y: 0.60), side: 0.23, rotation: .degrees(0),  phase: 4.0),
        PrismCube(center: CGPoint(x: 0.66, y: 0.35), side: 0.16, rotation: .degrees(45), phase: 5.2),
    ]

    /// Per-channel dispersion headings (unit vectors, y-down). Each channel
    /// leaves in a different direction so the three clones split into fringes
    /// rather than a uniform halo.
    static let redDirection   = CGVector(dx: -0.82, dy: -0.57)
    static let greenDirection = CGVector(dx:  0.10, dy:  1.00)
    static let blueDirection  = CGVector(dx:  0.86, dy: -0.51)

    /// Per-channel base offset magnitude in points at the 240pt reference.
    /// Kept small so the three clones overlap near each edge — summing toward a
    /// white glow — and only diverge into saturated fringes at their extremes,
    /// rather than reading as three separate colored outlines.
    static let redMagnitude:   CGFloat = 2.6
    static let greenMagnitude: CGFloat = 2.0
    static let blueMagnitude:  CGFloat = 3.0

    /// Reference canvas the magnitudes and radii are authored against.
    static let referenceSize: CGFloat = 240
}
