# docscan

Implementation notes for the `docscan` command. The command itself is
`executables/macbin/docscan`, a wrapper that compiles this source on first use
and caches the binary; see the comment block at the top of that file for the
build and caching rules. User-facing usage is in the repository README.

## What each step uses

| Step | Framework |
|---|---|
| Find the sheet of paper | Vision, `VNDetectDocumentSegmentationRequest` |
| Dewarp and crop | Core Image, `CIPerspectiveCorrection` |
| Remove shadows and paper yellowing | flat-field division (`CIGaussianBlur` + `CIDivideBlendMode`) |
| Make text readable | `CIToneCurve`, `CIColorControls`, `CIUnsharpMask` |
| Optional multi-page PDF | Core Graphics |

Everything is an Apple framework, so there is no dependency to install and no
data leaves the machine.

## The flat-field trick

The biggest win is not the contrast curve, it is the flat-field division. A
heavily blurred copy of the image is an estimate of how the page was lit.
Dividing the image by that estimate cancels the lighting, which removes the
shadow of the photographer's hand, an uneven flash, and the yellowing of old
paper in one step, while leaving the text untouched. It is the same correction
astronomers apply to sensor images, and it beats any global contrast adjustment
on a photographed page.

## Where detection needs help

Document detection fails in two ways, both reported per file during a run:

- **The sheet runs past the edge of the photo.** No closed contour, so no crop.
  The file is written as a full frame and listed at the end of the run.
- **The detector locks onto the printed block instead of the paper.** The crop
  then cuts off whatever sits in the margin, for example figures in a right-hand
  column. The symptom is a suspiciously small `cropped NN%` in the log next to
  the usual 85 to 95 percent. Rerun those files with `--no-crop`, or raise
  `--min-area` so they are left uncropped from the start.

`VNDetectRectanglesRequest` was tried as a second opinion for the second case
and did not help: paper on a light desk has edges too weak for it to find.
Hence the explicit `--min-area` escape hatch rather than more detection
cleverness.
