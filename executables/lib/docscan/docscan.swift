// docscan - turn photos of paper documents into clean, readable scans.
//
// Uses only Apple frameworks:
//   Vision      VNDetectDocumentSegmentationRequest finds the sheet of paper in the photo
//   Core Image  CIPerspectiveCorrection dewarps it, a flat-field division kills the
//               shadow gradient, a tone curve makes the text readable
//   Core Graphics  optional multi-page PDF output
//
// Originals are never touched; results go to a separate output directory.
//
// Not run directly: executables/macbin/docscan compiles and caches this file.
// See README.md next to this source for the design notes.

import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import Vision
import UniformTypeIdentifiers

// MARK: - Options

enum Mode: String {
    case color, gray, bw
}

struct Options {
    var inputs: [URL] = []
    var outDir: URL?
    var mode: Mode = .gray
    var crop = true
    var margin: Double = 1.5        // percent, keeps page numbers near the paper edge
    var minArea: Double = 20        // percent of the frame below which cropping is refused
    var textGuard: Double = 15      // percent an edge may travel to keep text inside
    var flatten = true
    var flattenDivisor: Double = 20 // blur radius = image width / this
    // Off by default: measured on this repo's test set, the unsharp mask costs
    // more text to OCR than it gains in looks (11 lost blocks with it, 7 without).
    var sharpen = false
    var contrast: Double = 1.0      // extra contrast on top of the tone curve
    var scaleHeight: Int?
    var a4 = false
    var pdf: URL?
    var quality: Double = 0.85
    var limit: Int?
    var overwrite = false
}

let usage = """
docscan - clean up photos of paper documents

USAGE
  docscan <file-or-directory>... [options]

OPTIONS
  --out <dir>        output directory (default: <input dir>/cleaned)
  --mode <m>         color | gray | bw          (default: gray)
  --no-crop          skip document detection and perspective correction
  --margin <pct>     widen the detected paper edge by this much (default: 1.5)
  --min-area <pct>   refuse to crop if the detected sheet covers less of the frame
                     than this, and keep the full photo instead (default: 20)
  --text-guard <pct> how far each edge of the crop may travel outward so that no
                     detected text falls outside it; 0 disables it (default: 15)
  --no-flatten       skip shadow/background flattening
  --flatten-radius <d>  illumination blur radius = width/d; smaller d means a
                     smoother estimate that touches the text less (default: 20)
  --sharpen          apply an unsharp mask; looks crisper to the eye but costs
                     accuracy when the result is fed to OCR (default: off)
  --contrast <f>     extra contrast, 1.0 = none (default: 1.0)
  --scale <px>       scale output to this height in pixels (e.g. 2480 for A4 @300dpi)
  --a4               force A4 aspect ratio after cropping
  --pdf <file>       also write all pages into one PDF, in filename order
  --quality <f>      JPEG quality 0..1 (default: 0.85)
  --limit <n>        process only the first n files (for a quick preview)
  --overwrite        overwrite existing output files
  -h, --help         this text

EXAMPLES
  docscan ~/photos --limit 3
  docscan ~/photos --mode bw --scale 2480 --pdf ~/mietvertrag.pdf
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("docscan: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

func parseArguments() -> Options {
    var o = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    var positional: [String] = []

    func next(_ flag: String) -> String {
        guard !args.isEmpty else { fail("\(flag) needs a value") }
        return args.removeFirst()
    }

    while !args.isEmpty {
        let a = args.removeFirst()
        switch a {
        case "-h", "--help": print(usage); exit(0)
        case "--out": o.outDir = URL(fileURLWithPath: next(a))
        case "--mode":
            let v = next(a)
            guard let m = Mode(rawValue: v) else { fail("unknown mode '\(v)'") }
            o.mode = m
        case "--no-crop": o.crop = false
        case "--margin": o.margin = Double(next(a)) ?? 1.5
        case "--min-area": o.minArea = Double(next(a)) ?? 20
        case "--text-guard": o.textGuard = Double(next(a)) ?? 15
        case "--no-flatten": o.flatten = false
        case "--flatten-radius": o.flattenDivisor = Double(next(a)) ?? 20
        case "--sharpen": o.sharpen = true
        case "--no-sharpen": o.sharpen = false
        case "--contrast": o.contrast = Double(next(a)) ?? 1.0
        case "--scale": o.scaleHeight = Int(next(a))
        case "--a4": o.a4 = true
        case "--pdf": o.pdf = URL(fileURLWithPath: next(a))
        case "--quality": o.quality = Double(next(a)) ?? 0.85
        case "--limit": o.limit = Int(next(a))
        case "--overwrite": o.overwrite = true
        default:
            if a.hasPrefix("--") { fail("unknown option '\(a)'") }
            positional.append(a)
        }
    }

    if positional.isEmpty { print(usage); exit(0) }

    let fm = FileManager.default
    let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]
    var files: [URL] = []
    for p in positional {
        let url = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { fail("no such file: \(p)") }
        if isDir.boolValue {
            let entries = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            files += entries.filter { extensions.contains($0.pathExtension.lowercased()) }
        } else {
            files.append(url)
        }
    }
    // Sort so that "-2" comes before "-10" instead of after it.
    o.inputs = files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    if let n = o.limit { o.inputs = Array(o.inputs.prefix(n)) }
    if o.inputs.isEmpty { fail("no images found") }
    if o.outDir == nil { o.outDir = o.inputs[0].deletingLastPathComponent().appendingPathComponent("cleaned") }
    return o
}

// MARK: - Document detection

/// Area of the detected quad as a fraction of the whole frame, via the shoelace formula.
func quadArea(_ o: VNRectangleObservation) -> Double {
    let p = [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft]
    var sum = 0.0
    for i in 0..<4 {
        let a = p[i], b = p[(i + 1) % 4]
        sum += a.x * b.y - b.x * a.y
    }
    return abs(sum) / 2.0
}

func detectDocument(_ image: CIImage, minArea: Double) -> VNRectangleObservation? {
    let request = VNDetectDocumentSegmentationRequest()
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    guard (try? handler.perform([request])) != nil else { return nil }
    guard let obs = request.results?.first else { return nil }
    // A small or low-confidence quad usually means the detector locked onto the
    // printed block rather than the sheet of paper, which would cut off anything
    // sitting near the paper edge. Keeping the whole frame is the safer answer.
    guard obs.confidence > 0.5, quadArea(obs) > minArea / 100.0 else { return nil }
    return obs
}

/// Every text region Vision can find in the frame, in normalised coordinates.
/// Cheap: this only locates text, it does not read it.
func textBoxes(_ image: CIImage) -> [CGRect] {
    let request = VNDetectTextRectanglesRequest()
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    guard (try? handler.perform([request])) != nil else { return [] }
    return (request.results ?? []).map(\.boundingBox)
}

/// The corners to crop along, in normalised coordinates.
///
/// The detected paper edge is not trusted blindly. Document segmentation
/// regularly places an edge a little inside the actual sheet, which slices the
/// last word off every line: the page still looks fine, and the text is gone.
/// So every edge of the quad is pushed outward until no text lies beyond it, and
/// only then by the fixed `margin`.
///
/// **The test has to be against the edges, not against a bounding box.** The quad
/// is a quadrilateral, and a photographed sheet is always a little rotated, so its
/// bounding box can span the entire frame while a sloping edge still cuts across a
/// column of figures. Comparing bounding boxes finds nothing to fix and the text
/// is cropped away regardless. This is not hypothetical: it is what the first
/// version of this guard did.
///
/// `guardCap` bounds how far an edge may travel, only so that one stray detection
/// cannot fling a corner across the frame. It is deliberately generous. Keeping a
/// strip of desk or a neighbouring sheet in the picture costs nothing; cropping a
/// figure off an invoice cannot be undone by anything downstream.
func cropCorners(_ obs: VNRectangleObservation,
                 textBoxes: [CGRect],
                 margin: Double,
                 guardCap: Double) -> [CGPoint] {
    var corners = [obs.topLeft, obs.topRight, obs.bottomRight, obs.bottomLeft]

    if !textBoxes.isEmpty && guardCap > 0 {
        let cap = guardCap / 100.0
        let padding = 0.004        // never leave text flush against the cut
        let centre = CGPoint(x: corners.map(\.x).reduce(0, +) / 4,
                             y: corners.map(\.y).reduce(0, +) / 4)
        let points = textBoxes.flatMap { b in
            [CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.minY),
             CGPoint(x: b.maxX, y: b.maxY), CGPoint(x: b.minX, y: b.maxY)]
        }

        // Each edge becomes a line n·x = c, with n pointing out of the quad.
        var normals: [CGPoint] = [], offsets: [Double] = []
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(1e-9, (dx * dx + dy * dy).squareRoot())
            var n = CGPoint(x: dy / len, y: -dx / len)
            if (n.x * (a.x - centre.x) + n.y * (a.y - centre.y)) < 0 {
                n = CGPoint(x: -n.x, y: -n.y)
            }
            let base = n.x * a.x + n.y * a.y
            // How far the furthest text corner sticks out past this edge.
            let overshoot = points.map { n.x * $0.x + n.y * $0.y - base }.max() ?? 0
            normals.append(n)
            offsets.append(base + min(max(overshoot + padding, 0), cap))
        }

        // The new corners are where the shifted edges meet again.
        var moved: [CGPoint] = []
        for i in 0..<4 {
            let (n1, c1) = (normals[(i + 3) % 4], offsets[(i + 3) % 4])
            let (n2, c2) = (normals[i], offsets[i])
            let det = n1.x * n2.y - n2.x * n1.y
            if abs(det) < 1e-9 { moved = corners; break }   // parallel: leave as is
            moved.append(CGPoint(x: (c1 * n2.y - c2 * n1.y) / det,
                                 y: (n1.x * c2 - n2.x * c1) / det))
        }
        corners = moved
    }

    // Push every corner outward from the centre, so a page number or a signature
    // sitting right on the paper edge does not get clipped off either.
    //
    // The result is deliberately NOT clamped to the frame. Clamping a corner back
    // into the photo drags its two edges inward with it, quietly undoing the guard
    // above and re-cutting the text it had just rescued. A corner outside the frame
    // is harmless: the sampled image is clamped instead, so the area beyond the
    // photo comes out as a smear of the border pixels. A strip of smeared border is
    // an acceptable thing to find on a page; a missing figure is not.
    let cx = corners.map(\.x).reduce(0, +) / 4
    let cy = corners.map(\.y).reduce(0, +) / 4
    let factor = 1.0 + margin / 100.0
    return corners.map { p in
        CGPoint(x: cx + (p.x - cx) * factor, y: cy + (p.y - cy) * factor)
    }
}

func perspectiveCorrect(_ image: CIImage, corners: [CGPoint]) -> CIImage {
    let e = image.extent
    func point(_ p: CGPoint) -> CIVector {
        CIVector(x: e.origin.x + p.x * e.width, y: e.origin.y + p.y * e.height)
    }
    // Clamped, so corners pushed past the photo edge sample the border instead of
    // cutting the crop short. See cropCorners for why they are allowed out there.
    let corrected = image.clampedToExtent().applyingFilter("CIPerspectiveCorrection", parameters: [
        "inputTopLeft": point(corners[0]),
        "inputTopRight": point(corners[1]),
        "inputBottomRight": point(corners[2]),
        "inputBottomLeft": point(corners[3]),
    ])
    // Move the result back to the origin so downstream extents stay predictable.
    return corrected.transformed(by: CGAffineTransform(translationX: -corrected.extent.origin.x,
                                                       y: -corrected.extent.origin.y))
}

// MARK: - Enhancement

/// Divide the image by an estimate of how the page was lit. The division cancels
/// the lighting, which removes shadows, an uneven flash and the yellowing of old
/// paper in one step, while leaving the text itself alone.
///
/// The estimate is a maximum filter (the brightest pixel in a small neighbourhood)
/// followed by a blur. The maximum filter is what makes this safe: with a radius a
/// little larger than a letter, it looks straight over the text and reports the
/// paper behind it, so the estimate carries illumination only.
///
/// A plain blur cannot do that, and the failure is subtle enough to be worth
/// recording. A blur wide enough to smooth the lighting also spans several lines
/// of text, so its output tracks how dense the text is. Dense paragraphs get a
/// darker estimate, the division brightens them more than their surroundings, and
/// thin strokes wash out. Measured on this repo's test set, the blur version lost
/// 18 blocks of text to OCR where the maximum filter loses 4, and it was worse
/// than doing no flattening at all.
func flatField(_ image: CIImage, divisor: Double) -> CIImage {
    let width = Double(image.extent.width)
    // Big enough to step over a glyph, small enough to follow a shadow edge.
    let glyphRadius = min(24.0, max(3.0, width / 120.0))
    let smoothRadius = max(10.0, width / max(1.0, divisor))
    let illumination = image
        .clampedToExtent()
        .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: glyphRadius])
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: smoothRadius])
        .cropped(to: image.extent)
    // CIDivideBlendMode computes background / foreground.
    return illumination.applyingFilter("CIDivideBlendMode", parameters: [
        kCIInputBackgroundImageKey: image
    ])
}

func toneCurve(_ image: CIImage, points: [(Double, Double)]) -> CIImage {
    var params: [String: Any] = [:]
    for (i, p) in points.enumerated() {
        params["inputPoint\(i)"] = CIVector(x: p.0, y: p.1)
    }
    return image.applyingFilter("CIToneCurve", parameters: params)
}

func enhance(_ input: CIImage, _ o: Options) -> CIImage {
    var image = input

    if o.flatten { image = flatField(image, divisor: o.flattenDivisor) }

    if o.mode != .color {
        image = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0])
    }

    switch o.mode {
    case .color:
        image = toneCurve(image, points: [(0, 0), (0.28, 0.20), (0.5, 0.5), (0.78, 0.90), (1, 1)])
    case .gray:
        image = toneCurve(image, points: [(0, 0), (0.25, 0.12), (0.5, 0.5), (0.80, 0.94), (1, 1)])
    case .bw:
        // Steep enough to act like a threshold, but without the hard edges and
        // lost hairlines a real 1-bit threshold produces on a photo.
        image = toneCurve(image, points: [(0, 0), (0.45, 0.03), (0.58, 0.30), (0.72, 0.97), (1, 1)])
    }

    if o.contrast != 1.0 {
        image = image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: o.contrast])
    }

    if o.sharpen {
        image = image.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 1.4,
            kCIInputIntensityKey: 0.7,
        ])
    }

    return image.cropped(to: input.extent)
}

func resize(_ image: CIImage, _ o: Options) -> CIImage {
    var image = image

    if o.a4 {
        // A4 is 1:sqrt(2). Stretch horizontally to that ratio, keeping the height.
        let target = image.extent.height / 1.41421356
        let sx = target / image.extent.width
        image = image.transformed(by: CGAffineTransform(scaleX: sx, y: 1))
    }

    if let h = o.scaleHeight, image.extent.height > 0 {
        let scale = Double(h) / Double(image.extent.height)
        image = image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0,
        ])
    }

    return image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x,
                                                   y: -image.extent.origin.y))
}

// MARK: - Output

let context = CIContext(options: [.useSoftwareRenderer: false])

func writeJPEG(_ image: CIImage, to url: URL, mode: Mode, quality: Double) throws {
    let space = mode == .color ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceGray()
    try context.writeJPEGRepresentation(
        of: image,
        to: url,
        colorSpace: space,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
    )
}

/// One image per page, aspect-fit onto A4 portrait, which is what these documents are.
func writePDF(pages: [URL], to url: URL) throws {
    let a4 = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    var box = a4
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
        throw NSError(domain: "docscan", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "cannot create PDF at \(url.path)"])
    }
    for page in pages {
        guard let src = CGImageSourceCreateWithURL(page as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
        pdf.beginPage(mediaBox: &box)
        let scale = min(a4.width / CGFloat(cg.width), a4.height / CGFloat(cg.height))
        let w = CGFloat(cg.width) * scale, h = CGFloat(cg.height) * scale
        pdf.draw(cg, in: CGRect(x: (a4.width - w) / 2, y: (a4.height - h) / 2, width: w, height: h))
        pdf.endPage()
    }
    pdf.closePDF()
}

// MARK: - Main

let options = parseArguments()
let fm = FileManager.default
try fm.createDirectory(at: options.outDir!, withIntermediateDirectories: true)

var written: [URL] = []
var notDetected: [String] = []

for (i, input) in options.inputs.enumerated() {
    let name = input.deletingPathExtension().lastPathComponent
    let output = options.outDir!.appendingPathComponent(name + ".jpg")

    if fm.fileExists(atPath: output.path) && !options.overwrite {
        print("[\(i + 1)/\(options.inputs.count)] \(input.lastPathComponent): exists, skipped")
        written.append(output)
        continue
    }

    guard let original = CIImage(contentsOf: input, options: [.applyOrientationProperty: true]) else {
        print("[\(i + 1)/\(options.inputs.count)] \(input.lastPathComponent): cannot read, skipped")
        continue
    }

    var image = original
    var note = "full frame"
    if options.crop {
        if let obs = detectDocument(original, minArea: options.minArea) {
            let boxes = options.textGuard > 0 ? textBoxes(original) : []
            let corners = cropCorners(obs, textBoxes: boxes,
                                      margin: options.margin, guardCap: options.textGuard)
            image = perspectiveCorrect(original, corners: corners)
            note = String(format: "cropped %.0f%%", quadArea(obs) * 100)
        } else {
            notDetected.append(input.lastPathComponent)
            note = "not detected reliably, full frame"
        }
    }

    image = resize(enhance(image, options), options)

    do {
        try writeJPEG(image, to: output, mode: options.mode, quality: options.quality)
        written.append(output)
        let size = "\(Int(image.extent.width))x\(Int(image.extent.height))"
        print("[\(i + 1)/\(options.inputs.count)] \(input.lastPathComponent) -> \(output.lastPathComponent)  \(size), \(note)")
    } catch {
        print("[\(i + 1)/\(options.inputs.count)] \(input.lastPathComponent): write failed (\(error.localizedDescription))")
    }
}

if let pdf = options.pdf {
    try writePDF(pages: written, to: pdf)
    print("PDF: \(pdf.path) (\(written.count) pages)")
}

if !notDetected.isEmpty {
    print("\nNot cropped (no reliable paper edge found), written as full frame: \(notDetected.count) file(s)")
    for n in notDetected { print("  \(n)") }
}
