---
# Every field is optional. What is missing is simply left out of the layout,
# except the date, which falls back to today.

# "DIN-5008-B" (default) puts the address field 45mm from the top and leaves
# room above it for annotations such as Einschreiben. "DIN-5008-A" is the
# compact variant at 27mm, for a letter that needs the extra lines.
format: DIN-5008-B

sender:
  name: Erika Mustermann
  address: |
    Musterstraße 1
    12345 Musterstadt
  # Shown in the letterhead under the address, not in the address field.
  # Ignored when `header` below is set, which replaces the letterhead whole.
  extra: |
    Telefon: 0123 456789
    erika@example.org
  # Optional. Replaces the whole letterhead (name, address and extra) when one
  # name is not enough, for instance on a letter two people sign. The first
  # line is set bold. `name` and `address` are still used for the return line
  # above the address field and for the PDF metadata, so leave them in place.
  header:
    - Erika Mustermann
    - Max Mustermann
    - Musterstraße 1
    - 12345 Musterstadt
    # Quoted, because an unquoted "key: value" is a YAML mapping, not a line.
    - "Telefon: 0123 456789"

recipient: |
  Musterfirma GmbH & Co. KG
  Abteilung Vertragswesen
  Musterweg 2
  54321 Andernorts

# Printed above the address, inside the envelope window. This is where the
# Versandart belongs: Einschreiben, Einwurfeinschreiben, Persönlich/Vertraulich.
annotations: Einwurfeinschreiben

# "Musterstadt, den 27.08.2026". Drop `date` and today is used; drop `place`
# and only the date is printed. `date-line` overrides both when a fixed
# wording is wanted ("im August 2026").
place: Musterstadt
date: 2026-08-27

subject: Kündigung des Vertrags Nr. 4711 zum 30. November 2026

# Optional, rendered in the reference block under the address field.
reference-signs:
  Ihr Zeichen: VW/2024-4711
  Unser Zeichen: EM-03

# Default is "Mit freundlichen Grüßen". Set to an empty string to drop it,
# for instance when the body already ends in its own closing.
closing: Mit freundlichen Grüßen

# One ruled signature line per entry, side by side, name printed underneath.
signatures:
  - Erika Mustermann
  - Max Mustermann

enclosures:
  - Kopie des Vertrags vom 18.03.2024
---

Sehr geehrte Damen und Herren,

hiermit kündige ich den oben genannten Vertrag ordentlich und fristgerecht zum
**30. November 2026**, hilfsweise zum nächstmöglichen Termin.

Bitte bestätigen Sie mir den Zugang dieser Kündigung sowie den
Beendigungszeitpunkt schriftlich.

Der Text ist gewöhnliches Markdown, also gibt es **Fettdruck**, *Kursives*,
Aufzählungen:

- ein erster Punkt
- ein zweiter Punkt

und alles Weitere, was Pandoc nach Typst übersetzen kann. Was nicht hierher
gehört, sind Absender, Empfänger, Datum, Betreff und Unterschriften: die stehen
oben im Frontmatter und werden vom Layout gesetzt, nicht vom Fließtext.
