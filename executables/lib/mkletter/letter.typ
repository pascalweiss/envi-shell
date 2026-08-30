// letter.typ — the DIN 5008 letter template behind the `mkletter` command.
// =============================================================================
// This file does not typeset the address field, the folding marks or the hole
// mark. That is `letter-pro`, an MIT licensed package from the Typst registry
// which already implements DIN 5008 form A and form B to the millimetre.
// Reimplementing that by hand would be work with no upside.
//
// What this file adds is everything `letter-pro` leaves to the author and that
// a letter needs every single time:
//
//   * one entry point taking a plain data object (the Markdown file's YAML
//     frontmatter, converted to JSON), so a caller never writes Typst
//   * multi-line YAML strings turned into real line breaks, because a newline
//     is whitespace in Typst, not a break
//   * a date line ("Stuttgart, den 27.08.2026") built from a place and an ISO
//     date, falling back to today
//   * a letterhead that can carry more than one name, which `letter-pro`'s
//     automatic one cannot (see the note at `build-header` below)
//   * a closing formula and a signature block with one ruled line per signer,
//     the part Markdown cannot express at all
//   * an Anlagen block
//
// `mkletter` writes a three-line driver next to this file at build time:
//
//     #import "letter.typ": letter
//     #show: letter.with(meta: json("meta.json"))
//     #include "body.typ"
//
// so every field below is reachable from YAML and nothing is passed
// positionally. The full field reference is in README.md next to this file.
// =============================================================================

#import "@preview/letter-pro:3.0.0": letter-simple

// --- helpers ----------------------------------------------------------------

// YAML block scalars arrive as one string with newlines in it. In Typst a
// newline is whitespace, so an address written over three lines would come out
// as one. Split and rejoin with real breaks. Accepts a list just as happily.
#let as-lines(value) = {
  if value == none { return none }
  if type(value) == array {
    let items = value.map(str).filter(l => l.trim() != "")
    return if items.len() == 0 { none } else { items.join(linebreak()) }
  }
  let parts = str(value).trim().split("\n").map(l => l.trim()).filter(l => l != "")
  if parts.len() == 0 { none } else { parts.join(linebreak()) }
}

// Same thing as a plain array of strings, for callers that need the parts
// rather than the rendered content.
#let as-list(value) = {
  if value == none { return () }
  if type(value) == array { return value.map(str).filter(l => l.trim() != "") }
  str(value).trim().split("\n").map(l => l.trim()).filter(l => l != "")
}

// "2026-08-27" -> "27.08.2026". Anything that is not an ISO date passes through
// untouched, which is the escape hatch for "im August 2026".
#let format-date(value) = {
  if value == none {
    return datetime.today().display("[day].[month].[year]")
  }
  let s = str(value).trim()
  let parts = s.split("-")
  if parts.len() == 3 and parts.at(0).len() == 4 {
    parts.at(2) + "." + parts.at(1) + "." + parts.at(0)
  } else {
    s
  }
}

// The letterhead. `letter-pro` builds one automatically from `sender`, but its
// name field also feeds `set document(author:)`, which only accepts a string.
// A jointly signed letter therefore cannot get both names into the letterhead
// through that route. Building the header here sidesteps it: the author stays
// a single string, the letterhead takes as many lines as the frontmatter gives.
#let build-header(lines, margin) = {
  if lines.len() == 0 { return auto }
  pad(
    left: margin.left,
    right: margin.right,
    top: margin.top,
    bottom: 5mm,
    align(bottom + right, {
      set text(size: 10pt)
      strong(lines.first())
      if lines.len() > 1 {
        linebreak()
        lines.slice(1).join(linebreak())
      }
    }),
  )
}

// One ruled line per signer, side by side, name printed underneath. The gap
// above the rules is the space actually signed into, so it is generous on
// purpose: a cramped signature line is the tell of a form letter.
#let signature-block(names, gap: 20mm, width: 55mm) = {
  let list = as-list(names)
  if list.len() == 0 { return none }

  v(gap)
  grid(
    columns: list.len(),
    column-gutter: 8mm,
    ..list.map(name => block(width: width, breakable: false)[
      #line(length: 100%, stroke: 0.5pt)
      #v(-3mm)
      #text(size: 9pt, name)
    ]),
  )
}

// --- entry point ------------------------------------------------------------

#let letter(meta: (:), body) = {
  // `.at(default:)` alone is not enough: a YAML key present but empty arrives
  // as none, and none must fall back to the default just like an absent key.
  let get(key, default: none) = {
    let v = meta.at(key, default: none)
    if v == none { default } else { v }
  }

  let sender = get("sender", default: (:))
  let margin = (
    left: 25mm,
    right: 20mm,
    top: 20mm,
    bottom: 20mm,
  )

  // The return address printed above the recipient (the Rücksendeangabe) is a
  // single line by design. `letter-pro` splits it back on ", " for the
  // letterhead, so joining with commas is what the package expects, not a
  // shortcut.
  let sender-address = {
    let explicit = sender.at("return-line", default: none)
    if explicit != none {
      str(explicit)
    } else {
      let parts = as-list(sender.at("address", default: none))
      if parts.len() == 0 { none } else { parts.join(", ") }
    }
  }

  // Letterhead: `sender.header` wins, otherwise name plus address plus extra,
  // which is what `letter-pro` would have produced on its own.
  let header-lines = {
    let explicit = as-list(sender.at("header", default: none))
    if explicit.len() > 0 {
      explicit
    } else {
      let name = sender.at("name", default: none)
      // The parentheses are load-bearing: without them typst reads the leading
      // `+` of the next line as a unary plus on a new expression and fails with
      // "cannot apply unary '+' to array".
      (
        (if name == none { () } else { (str(name),) })
          + as-list(sender.at("address", default: none))
          + as-list(sender.at("extra", default: none))
      )
    }
  }

  let place = get("place")
  let date-line = if get("date-line") != none {
    str(get("date-line"))
  } else if place != none {
    str(place) + ", den " + format-date(get("date"))
  } else {
    format-date(get("date"))
  }

  // YAML mapping -> the array of 2-tuples letter-pro wants.
  let reference-signs = {
    let r = get("reference-signs")
    if r == none { none } else if type(r) == dictionary {
      r.pairs().map(((k, v)) => ([#k], [#v]))
    } else { r }
  }

  show: letter-simple.with(
    format: get("format", default: "DIN-5008-B"),
    font: get("font", default: "Libertinus Serif"),
    folding-marks: get("folding-marks", default: true),
    hole-mark: get("hole-mark", default: true),
    margin: margin,

    header: build-header(header-lines, margin),

    sender: (
      name: sender.at("name", default: none),
      address: sender-address,
      extra: as-lines(sender.at("extra", default: none)),
    ),

    recipient: as-lines(get("recipient")),
    annotations: as-lines(get("annotations")),
    reference-signs: reference-signs,
    stamp: get("stamp", default: false),

    date: date-line,
    subject: get("subject"),
  )

  body

  let closing = get("closing", default: "Mit freundlichen Grüßen")
  if closing != none and str(closing).trim() != "" {
    v(6mm)
    str(closing)
  }

  signature-block(get("signatures"))

  let enclosures = as-list(get("enclosures"))
  if enclosures.len() > 0 {
    v(10mm)
    text(weight: "bold", "Anlagen")
    linebreak()
    enclosures.join(linebreak())
  }
}
