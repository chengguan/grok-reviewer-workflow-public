# Task #18 — Markup as real PDFAnnotation

Intent: Highlight / strike / underline as overlay annotations, per-action color, toggle-off.
Why: Users need markup; #16 removed it with ink/notes. Do not bring ink/notes/image-insert back.

Constraints:
- Overlay only; do not rewrite page streams
- `isSelectableObject` still excludes markup
- Do not enable `network.client`
- Do not recut 1.2.2 (6)

Acceptance:
- MK-01..04 + Core tests green
- Device: select, mark, toggle-off leftover keeps original color
- Privacy copy includes markup styles; do not bump LegalAcceptance

Decisions during work: D-018, D-019
Out of scope: ink, notes, form-fill, Pencil-as-tool
