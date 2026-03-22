# MONTESSORI_FRONTEND_SKILLS.md

Status: Canonical skill guide for **Montessori-aligned** frontend work—interfaces that respect concentration, clarity, and self-directed use without conflating pedagogy with product hype.

Companion: apply [UNIFIED_ACCESS.md](./UNIFIED_ACCESS.md) first for accessibility, neurodiversity, and age-friendly baselines; this document adds **environment design, order, and autonomy** patterns familiar from Montessori practice, translated into UI engineering.

## 1) What “Montessori-friendly” means here

Not marketing. It means the interface behaves like a **prepared environment**:

- Materials (controls, copy, layout) are **complete enough** to succeed, **bounded enough** to stay safe.
- The user can **choose** within clear limits; the system does not nag, guilt, or rush.
- **Order** is visible: everything has a place; navigation and hierarchy are stable.
- **Errors teach**: feedback is immediate, neutral, and actionable (control of error).
- **Concentration is protected**: motion, sound, and interruptions are scarce and purposeful.

These map to professional dashboards, onboarding, settings, and tools—not only child-facing products.

## 2) Principles → frontend practices

| Montessori idea | Frontend skill |
|-----------------|----------------|
| **Prepared environment** | Defaults, empty states, and first-run paths are complete; no “figure it out” dead ends. Required fields and permissions are explained *before* blocking. |
| **Freedom within limits** | Offer real choices (layouts, density, notification level); hard limits are explicit (why, what unlocks, who decides). |
| **Order** | Consistent grid, spacing scale, component placement, and terminology. Fewer one-off layouts. |
| **Isolation of difficulty** | One new concept per screen or modal; avoid stacking first-time tutorials with billing changes with role edits. |
| **Concrete → abstract** | Show data, previews, and examples before jargon; charts rest on tables or export; APIs link to human-readable outcomes. |
| **Control of error** | Inline validation, reversible actions, undo where safe; errors name the fix, not the user. |
| **Observation (adult)** | Instrument calm metrics: task success, time-to-complete, error recovery—not vanity engagement. |

## 3) Layout and visual calm

- **Visual shelves**: Group related actions in clear regions (primary work, secondary tools, meta/navigation). Avoid scattering the same action type across the viewport.
- **Breathing room**: Generous whitespace beats dense dashboards for sustained work. Density modes are a **user choice**, not the only mode.
- **Predictable rhythm**: Repeat spacing, type scale, and corner radii from a token set. Surprise breaks trust and order.
- **Label everything important**: Icons carry text labels unless universally unambiguous (and even then, tooltips for first use).
- **Color as secondary**: Encode state with text, iconography, or position as well as hue. Honor contrast and [UNIFIED_ACCESS.md](./UNIFIED_ACCESS.md) contrast rules.

## 4) Interaction and flow

- **One invitation at a time**: Avoid competing modals, auto-playing tours, and simultaneous toasts. Queue non-critical messages.
- **Interrupt rarely**: No dark patterns, fake urgency, or infinite scroll traps for settings. Respect `prefers-reduced-motion` and do not hijack focus for promos.
- **Self-direction**: Prefer explicit “Continue” over timed auto-advance. Let users leave and resume; persist obvious draft state.
- **Scaffolding fades**: Progressive disclosure: essentials first, “Advanced” collapsed. Do not hide safety-critical options.
- **Touch and motor**: Large targets, forgiving hit slop, no precision-only gestures for core tasks.

## 5) Copy tone (Montessori-adjacent, professional)

- **Factual and respectful**: Describe what is true and what happens next. No shame, fear, or hype.
- **Short, precise verbs**: “Save draft”, “Send invite”, “Revoke key”—not “Supercharge your workflow”.
- **Second person or neutral imperatives**: “Add a label” not “Smart users add labels”.
- **Define terms once**: Link to a glossary or inline `aria-describedby` for specialized language.

## 6) Components: concrete patterns

### Navigation

- Stable IA; rename or move items with a **changelog** or in-app notice once, not silent drift.
- “You are here” is obvious: breadcrumbs, active nav state, page titles that match nav labels.

### Forms

- Labels visible; placeholders are hints, not the only label.
- Validate on blur or submit with **immediate** neutral messages; preserve user input on error.
- Destructive actions require clear consequences and a distinct control (not the same style as primary).

### Empty and loading states

- Empty states teach the **next physical step** (“Import a CSV” + template link), not empty marketing.
- Skeletons or quiet spinners; avoid flashy loaders that steal attention from parallel tasks.

### Notifications

- Batched, dismissible, severity-coded. Critical path only for modal interruption.
- User-controlled channels (email, in-app, quiet hours) when the product allows.

### Tables and data

- Sortable columns where it helps; sticky headers for long lists; readable default column width.
- Export and keyboard navigation for power users without breaking simple paths.

## 7) Anti-patterns (remove in review)

- Gamification badges for serious or safety-adjacent workflows unless explicitly a learning product.
- Infinite notification red dots, confetti, or streaks for routine work.
- Obscured pricing, forced opt-in toggles, or pre-checked dark patterns.
- “Smart” UI that hides controls users need to **correct mistakes**.
- Layouts that reshuffle on hover or data load without user action.

## 8) Review checklist (frontend PR)

Use with [UNIFIED_ACCESS.md](./UNIFIED_ACCESS.md) §8.

1. Could a focused user complete the primary task **without** being interrupted by secondary promo or chat?
2. Is there **exactly one** dominant primary action per view where that makes sense?
3. Are **errors** neutral, specific, and recoverable?
4. Do **motion and sound** default to restrained; can they be reduced?
5. Is **terminology** consistent with the rest of the app and docs?
6. Would changing this screen next week **break muscle memory**? If yes, document the change for users.

## 9) When this guide is mandatory

Load and apply this file for:

- New operator or public UI in `apps/*`
- Onboarding, settings, safety, or permission flows
- Any interface marketed as calm, educational, family-facing, or “sovereign / long-horizon” work

For pure internal CLI or log-only tools, [UNIFIED_ACCESS.md](./UNIFIED_ACCESS.md) alone may suffice unless humans read the output as a primary task.

## 10) Maintenance

If Montessori-aligned patterns change materially, update this file in the same change as UI tokens or layout primitives, and record drift in `TASKS.md` if cross-doc anchors move.
