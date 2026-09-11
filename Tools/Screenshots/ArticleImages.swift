import AppKit

/// Composites the README hero from the App Store frames in `QA/appstore`.
///
/// Run as `swift Tools/Screenshots/ArticleImages.swift`.
///
/// Two things here are load bearing.
///
/// The 144 DPI tag is the last thing that happens to a bitmap. Setting the size
/// before drawing makes the context one point per two pixels while every
/// rectangle below is still in pixels, so the whole composite doubles and runs
/// off the canvas.
///
/// The ground is the same #101010 the frames themselves are drawn on, and
/// nothing is stroked around them. That is deliberate: matching the backdrop
/// exactly makes three separate frames read as one image with no seam, which is
/// the whole reason to put them on a ground rather than in a table. A hairline
/// or a shadow would put the seam back.

let root = FileManager.default.currentDirectoryPath
let shots = URL(fileURLWithPath: root).appendingPathComponent("QA/appstore")
let out = URL(fileURLWithPath: root).appendingPathComponent("docs/images")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("cannot allocate a \(width) by \(height) bitmap") }
    rep.size = NSSize(width: width, height: height)
    return rep
}

/// The void. Sampled from the frames rather than chosen: they are drawn on
/// srgb(16,16,16) and the point is that the join does not show.
func ground(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let result = bitmap(width, height)
    guard let data = result.bitmapData else { fatalError("no bitmap data") }
    let paper: [UInt8] = [16, 16, 16, 255]
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * result.bytesPerRow + x * 4
            for channel in 0..<4 { data[offset + channel] = paper[channel] }
        }
    }
    return result
}

func withCanvas(_ canvas: NSBitmapImageRep, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// Half the pixel count means 144 DPI in the encoded file, so the PNG reads as
/// a retina asset rather than a very large 1x one.
func write(_ image: NSBitmapImageRep, to url: URL) {
    let pixels = NSSize(width: image.pixelsWide, height: image.pixelsHigh)
    image.size = NSSize(width: pixels.width / 2, height: pixels.height / 2)
    guard let png = image.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(url.lastPathComponent)")
    }
    try! png.write(to: url)
    image.size = pixels
    print("\(url.lastPathComponent) \(image.pixelsWide)x\(image.pixelsHigh)")
}

func load(_ name: String) -> NSImage {
    let url = shots.appendingPathComponent(name)
    guard let image = NSImage(contentsOf: url) else { fatalError("cannot read \(url.path)") }
    return image
}

func draw(_ text: String, at point: CGPoint, canvasHeight: CGFloat, size: CGFloat,
          weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ]
    let string = text as NSString
    let measured = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: point.x, y: canvasHeight - point.y - measured.height),
                withAttributes: attributes)
}

let ink = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.97, alpha: 1)
let inkSoft = NSColor(srgbRed: 0.60, green: 0.60, blue: 0.62, alpha: 1)

// The hero. Three screens at a size a reader can read, with the name and the
// one line that says what the thing is set beside them. 2400x1600 is the shape
// the portfolio cards use, so a cover comes out of this file rather than a
// second export.
do {
    let canvas = CGSize(width: 2400, height: 1600)
    let image = ground(Int(canvas.width), Int(canvas.height))
    withCanvas(image) {
        let blockTop: CGFloat = 120

        if let icon = NSImage(contentsOf: out.appendingPathComponent("logo.png")) {
            NSGraphicsContext.current?.imageInterpolation = .high
            icon.draw(in: CGRect(x: 150, y: canvas.height - blockTop - 118, width: 118, height: 118))
        }
        draw("minus", at: CGPoint(x: 300, y: blockTop + 2), canvasHeight: canvas.height,
             size: 64, weight: .semibold, color: ink)
        draw("A giant clock, your intention, and the few apps you actually need.",
             at: CGPoint(x: 304, y: blockTop + 88),
             canvasHeight: canvas.height, size: 30, weight: .regular, color: inkSoft)

        let names = ["02-home.png", "04-focus.png", "06-schedules.png"]
        let phoneHeight: CGFloat = 1100
        let gap: CGFloat = 70
        let first = load(names[0])
        let aspect = first.size.width / first.size.height
        let phoneWidth = phoneHeight * aspect
        let total = phoneWidth * 3 + gap * 2
        let startX = (canvas.width - total) / 2
        let top = blockTop + 250

        NSGraphicsContext.current?.imageInterpolation = .high
        for (index, name) in names.enumerated() {
            let rect = CGRect(x: startX + CGFloat(index) * (phoneWidth + gap), y: top,
                              width: phoneWidth, height: phoneHeight)
            let flipped = CGRect(x: rect.minX, y: canvas.height - rect.maxY,
                                 width: rect.width, height: rect.height)
            load(name).draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
    write(image, to: out.appendingPathComponent("hero.png"))
}
