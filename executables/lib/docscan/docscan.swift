// docscan - turn photos of paper documents into clean, readable scans.
//
// Uses only Apple frameworks:
//   Vision      VNDetectDocumentSegmentationRequest finds the sheet of paper in the photo
//   Core Image  CIPerspectiveCorrection dewarps it, a flat-field division kills the
//               shadow gradient, tone curve + unsharp mask make the text readable
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
    var flatten = true
    var sharpen = true
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
  --no-flatten       skip shadow/background flattening
  --no-sharpen       skip the unsharp mask
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
        case "--no-flatten": o.flatten = false
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

func perspectiveCorrect(_ image: CIImage, _ obs: VNRectangleObservation, margin: Double) -> CIImage {
    let e = image.extent
    let corners = [obs.topLeft, obs.topRight, obs.bottomRight, obs.bottomLeft]
    // Push every corner outward from the centre, so a page number or a signature
    // sitting right on the paper edge does not get clipped off.
    let cx = corners.map(\.x).reduce(0, +) / 4
    let cy = corners.map(\.y).reduce(0, +) / 4
    let factor = 1.0 + margin / 100.0
    func point(_ p: CGPoint) -> CIVector {
        let x = min(max(cx + (p.x - cx) * factor, 0), 1)
        let y = min(max(cy + (p.y - cy) * factor, 0), 1)
        return CIVector(x: e.origin.x + x * e.width, y: e.origin.y + y * e.height)
    }
    let corrected = image.applyingFilter("CIPerspectiveCorrection", parameters: [
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

/// Divide the image by a heavily blurred copy of itself. The blurred copy is an
/// estimate of the illumination, so the division removes shadows, an uneven flash
/// and the yellowing of old paper, while leaving the text alone.
func flatField(_ image: CIImage) -> CIImage {
    let radius = max(10.0, Double(image.extent.width) / 20.0)
    let illumination = image
        .clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
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

    if o.flatten { image = flatField(image) }

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
            image = perspectiveCorrect(original, obs, margin: options.margin)
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
