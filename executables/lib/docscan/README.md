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

## The flat-field trick, and how to get it wrong

The biggest win is not the contrast curve, it is the flat-field division. An
estimate of how the page was lit is computed, and the image is divided by it.
That cancels the lighting, which removes the shadow of the photographer's hand,
an uneven flash, and the yellowing of old paper in one step, while leaving the
text untouched. It is the same correction astronomers apply to sensor images,
and it beats any global contrast adjustment on a photographed page.

**The estimate must not see the text.** The first version estimated the
illumination with a wide Gaussian blur, which is the obvious choice and is
wrong. A blur wide enough to smooth the lighting also spans several lines of
text, so its output tracks how dense the text is: a dense paragraph gets a
darker estimate, the division brightens it more than its surroundings, and thin
strokes wash out. The page still looks clean, and whole lines have quietly
stopped being readable.

A maximum filter (the brightest pixel in a small neighbourhood) does not have
that failure. With a radius a little larger than a letter it looks straight over
the text and reports the paper behind it, so the estimate carries illumination
only. The maximum filter runs first, a blur then smooths its output.

## What the OCR measurements said

Measured over 40 photographed pages of a 1980s typewritten Mietvertrag, by
running Vision OCR over both the originals and the processed pages and counting
runs of four or more consecutive words that the processed version lost:

| Pipeline | lost blocks |
|---|---|
| blur flat-field + unsharp mask (first version) | 18 |
| maximum-filter flat-field + unsharp mask | 11 |
| maximum-filter flat-field, no unsharp mask | 7 |
| no flattening at all | 5 |

Two conclusions are baked into the defaults. The unsharp mask costs more text
than it gains in looks, so it is off unless `--sharpen` is passed. And flattening
still costs a little accuracy even done right, so where the text matters more
than the look, `--no-flatten` is the better run.

**Do not assume one rendering serves both purposes.** Neither setting won on
every page: over those 40 pages, the standard rendering read 16 pages more
completely and `--no-flatten` read 24. Running both and keeping the better text
per page is a legitimate thing to do, and cheap, since OCR is about a second per
page.

## Where detection needs help

Document detection fails in two ways, both reported per file during a run:

- **The sheet runs past the edge of the photo.** No closed contour, so no crop.
  The file is written as a full frame and listed at the end of the run.
- **The detector locks onto the printed block instead of the paper**, and the
  crop then cuts off whatever sits in the margin, for example figures in a
  right-hand column. This is what `--text-guard` is for: Vision is asked where
  the text is, and the crop is widened until no text falls outside it. The
  widening is capped, because a photo of paper in a folder nearly always shows a
  neighbouring sheet and its text must not drag the crop back open.

`VNDetectRectanglesRequest` was tried as a second opinion for the second case
and did not help: paper on a light desk has edges too weak for it to find.
Hence the text guard, plus `--min-area` as an explicit escape hatch, rather
than more detection cleverness.

## Text that goes missing is not always the tool's fault

Two traps, both hit for real while tuning this against OCR output:

- **Text can be present in the image and simply not be read.** Before blaming
  the crop, check whether the words are visible in the output page. On the test
  set every single suspected crop loss turned out to be an OCR failure caused by
  the flat-field, not a pixel that had been cut away.
- **Removed text can be the correct outcome.** Photographs of a stack show the
  neighbouring sheet, so a closing line or a letterhead may vanish from a page
  that never owned it. A diff against OCR of the uncropped original reports
  those as losses. They are the crop working.
