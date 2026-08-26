# mkletter

Implementation notes and the frontmatter field reference for the `mkletter`
command. The command itself is `executables/bin/mkletter`; the comment block at
the top of that file explains the build pipeline. User-facing usage is in the
repository README.

`example.md` next to this file is a complete letter exercising every field. It
is also the fastest check that the toolchain still works:

```bash
mkletter executables/lib/mkletter/example.md -o /tmp/example.pdf --png
```

The example's letter text is German, and deliberately so: DIN 5008 is a German
norm and the address field, the Versandart annotations and the Anlagen block
have no English counterpart worth sampling. Comments and documentation are
English as everywhere else in this repo.

## What is ours and what is not

| Part | Where it comes from |
|---|---|
| Address field, folding marks, hole mark, DIN 5008 form A/B | `letter-pro`, MIT, from the Typst package registry |
| Markdown to Typst markup | pandoc |
| YAML frontmatter to JSON | yq |
| Rendering | typst |
| Frontmatter contract, letterhead, date line, signature block, Anlagen | `letter.typ` here |

`letter-pro` is referenced as `@preview/letter-pro:3.0.0`, so typst downloads it
on first use and caches it under `~/.cache/typst/packages`. That first render
needs network; later ones do not. The version is pinned, so an upstream release
cannot change the look of a letter under you.

## Why the template is copied into the build directory

Typst resolves `#import "..."` against its project root and refuses to read
outside it. Importing the template from `~/.envi` would mean setting the root to
`/` or to `$HOME`, which also hands the document read access to everything under
it. Copying one small file into the temp build directory keeps the root at the
build directory, where the only readable files are the three the tool just
generated.

## Frontmatter fields

All optional. A missing field is left out of the layout; a missing `date` falls
back to today.

| Field | Type | Meaning |
|---|---|---|
| `format` | string | `DIN-5008-B` (default, address field 45mm from the top, room for annotations) or `DIN-5008-A` (compact, 27mm) |
| `font` | string | Default `Libertinus Serif`, which ships inside typst and is therefore present on every machine without a font install |
| `folding-marks` | bool | Default true |
| `hole-mark` | bool | Default true |
| `sender.name` | string | Letterhead first line, the return line above the address field, and the PDF author |
| `sender.address` | multi-line string | Letterhead lines; also joined with commas for the return line |
| `sender.return-line` | string | Overrides that return line when the comma-joined address is too long |
| `sender.extra` | multi-line string | Extra letterhead lines (phone, mail). Ignored when `sender.header` is set |
| `sender.header` | list of strings | Replaces the letterhead whole, first line bold. The way to get two names into it, see below |
| `recipient` | multi-line string | The address, one line per entry |
| `annotations` | string | Printed above the address inside the window: `Einwurfeinschreiben`, `Persönlich/Vertraulich` |
| `stamp` | bool | Leave room for a stamp next to the address |
| `reference-signs` | mapping | `Ihr Zeichen: ...` etc., rendered under the address field |
| `place` | string | Builds `Stuttgart, den 27.08.2026` together with `date` |
| `date` | ISO date | `2026-08-27`. Anything that is not an ISO date passes through unchanged |
| `date-line` | string | Overrides `place` and `date` entirely |
| `subject` | string | The Betreff, set bold, no "Betreff:" prefix (DIN 5008 drops it) |
| `closing` | string | Default `Mit freundlichen Grüßen`; set to `""` to drop it |
| `signatures` | list of strings | One ruled line per entry, side by side, name underneath |
| `enclosures` | list of strings | Rendered as an `Anlagen` block |

### Two signers

`letter-pro` derives the letterhead from `sender.name`, and that same value
feeds `set document(author:)`, which only accepts a plain string. So a second
name cannot go in through `sender.name` without breaking the PDF metadata.
`sender.header` exists for that case: it replaces the letterhead outright while
`sender.name` stays a single string for the metadata and the return line.

```yaml
sender:
  name: Pascal Weiß
  address: |
    Tübinger Str. 70
    70178 Stuttgart
  header:
    - Pascal Weiß
    - Karolin Gomez Carnero
    - Tübinger Str. 70
    - 70178 Stuttgart
signatures:
  - Pascal Weiß
  - Karolin Gomez Carnero
```

A single name in the return line above the address field is correct and normal:
that line exists so the post office can return an undeliverable letter, not to
name every signer.

### What does not belong in the body

Sender, recipient, date, subject, closing formula and signature lines are
layout, not prose. Written into the Markdown body they end up inside the text
block, which means they land below the fold instead of in the address window,
and the letter no longer fits a window envelope. That is the one mistake the
frontmatter exists to prevent.

## Gotchas

- **An unquoted `key: value` in a YAML list is a mapping, not a line.** Write
  `- "Telefon: 0123 456789"` in `sender.header`, or the entry silently turns
  into a dictionary.
- **A newline inside a YAML string is not a line break in Typst**, it is
  whitespace. `as-lines` in `letter.typ` handles that for every multi-line
  field; a new field needs to go through it too.
- **Two unrelated programs are called `yq`.** mikefarah's Go one (Homebrew, and so
  macOS) needs `-o=json`; kislyuk's Python one (Debian's `yq` package, which is what
  sits on `$PATH` ahead of Homebrew on forum0 and forum1) rejects that flag and emits
  JSON by default. `mkletter` tries the flag and falls back, so both work. Verified on
  2026-08-26 that the two produce the same JSON for the frontmatter shapes used here.
- **`--keep-build`** prints the temp directory and leaves it in place, which is
  the way to look at the generated `main.typ`, `meta.json` and `body.typ` when
  typst reports an error in a letter that looks fine.
