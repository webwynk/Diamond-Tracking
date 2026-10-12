# 03 — Design System

Modern, responsive, fast. Built for a field worker holding a cheap phone in bright sunlight with one hand, and for an admin scanning 150 people quickly.

**Every value here is a token. Never write a literal hex, font size, radius, or spacing number in widget code.** If a value you need is missing, add it here first and get approval.

---

## 1. Design principles

1. **One primary action per screen.** The employee's duty toggle is the clearest thing on their home screen; everything else is secondary.
2. **Status is colour plus a label**, never colour alone. Colour-blind users and bright sunlight both defeat colour-only meaning.
3. **Never show a blank screen.** Every async surface is loading, empty, error, or content. There is no fifth state.
4. **Large touch targets.** This app is used outdoors, in motion, possibly with gloves.
5. **Fast perceived performance.** Skeletons over spinners; optimistic updates where safe.
6. **Calm by default, loud only when it matters.** Red and orange are reserved for genuine problems.
7. **Responsive, not just phone-sized.** Works from a 320 dp budget phone to a tablet, and later a browser.

---

## 2. Colour palette

### Brand ramp

`#016893` is the brand colour and sits at `primary-600`. The ramp is derived from it (hue ≈ 198°) so tints and shades stay in family.

| Token | Hex | Use |
|---|---|---|
| `primary-50` | `#E8F3F8` | Page tint, selected-row background |
| `primary-100` | `#C5E1EC` | Chip background, subtle fill |
| `primary-200` | `#9ECDDF` | Borders on tinted surfaces |
| `primary-300` | `#76B9D2` | Disabled brand elements |
| `primary-400` | `#4AA5C6` | Illustrations, map chrome, decorative accents. **Too light for text.** |
| `primary-500` | `#0E86B4` | Hover and pressed on light |
| **`primary-600`** | **`#016893`** | **BRAND. Buttons, app bar, active states, links** |
| `primary-700` | `#015676` | Pressed state on light |
| `primary-800` | `#01425A` | Headings on tinted surfaces |
| `primary-900` | `#002938` | Deepest brand shade |

**Verified contrast**
- White text on `#016893` = **6.17:1** — passes WCAG AA for normal text; does not reach AAA.
- `#016893` text on white = **6.17:1** — passes AA.
- **Only `primary-600` and darker may be used for text or icons.** `primary-500` and lighter do not reach 4.5:1 on white and are for fills and decoration only.

### Neutrals

| Token | Hex | Use |
|---|---|---|
| `neutral-0` | `#FFFFFF` | Cards and sheets in light mode |
| `neutral-50` | `#F8FAFC` | Light page background |
| `neutral-100` | `#F1F5F9` | Subtle fill, skeleton base |
| `neutral-200` | `#E2E8F0` | Dividers, borders |
| `neutral-300` | `#CBD5E1` | Input borders, skeleton shimmer |
| `neutral-400` | `#94A3B8` | Placeholder text, disabled text, **off-duty status** |
| `neutral-500` | `#64748B` | Secondary text |
| `neutral-600` | `#475569` | Body text on light |
| `neutral-700` | `#334155` | Strong body text, icon on a light fill |
| `neutral-800` | `#1E293B` | **Blocked status** |
| `neutral-900` | `#0F172A` | Primary text, headings |

### Semantic

| Token | Hex | Meaning |
|---|---|---|
| `success` | `#16A34A` | On duty, uploaded, saved |
| `success-bg` | `#DCFCE7` | Success banner background |
| `warning` | `#F59E0B` | Stale location, queued offline, low battery |
| `warning-bg` | `#FEF3C7` | Warning banner background |
| `error` | `#DC2626` | Fake-GPS flag, GPS off, failure |
| `error-bg` | `#FEE2E2` | Error banner background |
| `info` | `#0284C7` | Neutral information |
| `info-bg` | `#E0F2FE` | Info banner background |

### Map status colours

Must match the PRD status table exactly. Defined once, used by map, lists, and reports.

| Status | Token | Hex | Label shown |
|---|---|---|---|
| Active, on duty | `status-active` | `#16A34A` | "On duty" |
| Stale, over 5 min | `status-stale` | `#F59E0B` | "No update 5 min" |
| Suspect, mock or GPS off | `status-suspect` | `#DC2626` | "Check needed" |
| Off duty | `status-off` | `#94A3B8` | "Off duty" |
| Blocked | `status-blocked` | `#1E293B` | "Blocked" |

**Always render the label with the colour.** A marker also carries a distinct shape or icon so status survives greyscale printing and colour blindness.

### Light mode only

**This app has no dark mode.** It ships one light theme and ignores the system dark-mode setting.

| Role | Value |
|---|---|
| Page background | `neutral-50` |
| Card surface | `neutral-0` |
| Elevated surface | `neutral-0` + soft shadow |
| Primary text | `neutral-900` |
| Secondary text | `neutral-500` |
| Divider | `neutral-200` |
| Brand | `primary-600` |

Reasons this is the right call here: the app is used outdoors in bright sunlight, where a light theme on a high-brightness screen is more legible; a map has to be styled and tested twice if there are two themes; and every status colour would need its contrast re-verified against a dark surface. One theme means one set of verified contrast values.

**Consequences to respect in code:** force the light theme explicitly rather than leaving it to follow the system, and never add a colour that only works on a dark surface. If dark mode is ever wanted, it is a deliberate project with its own contrast verification pass — not a switch to flip.

---

## 3. Typography

**DM Sans** throughout, **bundled with the app** at `assets/fonts/DMSans-Variable.ttf` rather than fetched at runtime, so the first screen is never unstyled on a slow connection. The `google_fonts` package is deliberately **not** used.

It is a **variable** font — Google Fonts publishes no static instances for DM Sans — so weight is selected with `fontVariations: [FontVariation('wght', 600)]`. `fontWeight` alone snaps to the nearest axis instance and is imprecise at the 500 and 600 steps this scale uses, so the implementation sets both.

Weights used: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold. Do not use any other weight.

| Token | Size / line height | Weight | Use |
|---|---|---|---|
| `display` | 32 / 40 | 700 | The km and hours figures on the duty screen |
| `h1` | 28 / 36 | 700 | Screen title on a large header |
| `h2` | 24 / 32 | 600 | Section heading |
| `h3` | 20 / 28 | 600 | Card title, app bar title |
| `title` | 18 / 26 | 600 | List item title, dialog title |
| `bodyLarge` | 16 / 24 | 400 | Primary reading text, input text |
| `body` | 14 / 20 | 400 | Default body, list subtitle |
| `label` | 13 / 18 | 500 | Button text, chip text, field label |
| `caption` | 12 / 16 | 400 | Timestamps, helper text |
| `overline` | 11 / 16 | 600, +0.5 letter spacing | Table and section micro-headings, uppercase |

### Rules
- Minimum body size is **14**. Nothing smaller than `caption` at 12, and 12 is never used for anything the user must read to act.
- Maximum **two** type sizes in one component.
- Numbers in tables and stat cards use **tabular figures**, so columns do not jitter as values change.
- Text must survive system font scaling to **150%** without clipping. Test it.
- Never centre a paragraph. Centre only short labels.

---

## 4. Spacing, radius, elevation

### Spacing — 4 dp base

| Token | Value | Use |
|---|---|---|
| `space-1` | 4 | Icon-to-text gap |
| `space-2` | 8 | Inside a chip or dense row |
| `space-3` | 12 | Between related elements |
| `space-4` | 16 | **Default. Screen side padding, card padding** |
| `space-5` | 20 | Card padding on a roomy layout |
| `space-6` | 24 | Between sections |
| `space-8` | 32 | Above a major section |
| `space-10` | 40 | Empty-state breathing room |
| `space-12` | 48 | Top and bottom of a centred state |
| `space-16` | 64 | Rare, large hero spacing |

Screen horizontal padding is **16 dp**, always. No horizontal page scroll, ever.

### Radius

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 8 | Chips, small buttons, badges |
| `radius-md` | 12 | **Default. Inputs, buttons, cards** |
| `radius-lg` | 16 | Large cards, sheets |
| `radius-xl` | 24 | Bottom sheets, modals |
| `radius-full` | 999 | Avatars, pills, the duty toggle |

### Elevation

Keep it flat. Prefer a `neutral-200` border over a heavy shadow.

| Token | Use |
|---|---|
| `elev-0` | Flat on background, with a `neutral-200` border |
| `elev-1` | Card. Very soft shadow, or a border where a shadow would look muddy |
| `elev-2` | Sticky header, FAB |
| `elev-3` | Bottom sheet, dialog |

---

## 5. Touch targets and responsiveness

- **Minimum touch target is 48 × 48 dp.** No exceptions, including icon buttons.
- The duty toggle is **at least 120 dp tall** and spans the content width. It is the most important control in the app.
- Minimum gap between adjacent targets is 8 dp.

### Breakpoints

| Name | Width | Layout |
|---|---|---|
| `compact` | < 600 dp | Single column. The default. Bottom navigation. |
| `medium` | 600–1023 dp | Two columns where useful; list and detail side by side. Navigation rail. |
| `expanded` | ≥ 1024 dp | Map plus side panel. Mainly for the phase-2 web dashboard. |

Design for `compact` first and let it grow. Never let a layout assume a minimum width above 320 dp.

### Safe areas and orientation
- Respect notches, cutouts, and the system navigation bar.
- Portrait is the primary orientation. Map screens must also work in landscape.
- Keyboard must never cover the field being typed into.

---

## 6. Loading states

Pick by what the user is waiting for. Getting this wrong is the main cause of an app feeling slow.

| Situation | Use | Never use |
|---|---|---|
| First load of a list or screen with known layout | **Skeleton** | Full-screen spinner |
| Loading the next page of a list | Small inline spinner at the list end | Skeleton, full-screen spinner |
| A button action, such as starting duty | **Inline spinner inside the button**, button disabled, label changes to "Starting…" | Blocking overlay |
| Pull to refresh | Standard refresh indicator | Skeleton |
| Map tiles loading | MapLibre's own tile loading, plus a branded placeholder behind it | Spinner over the map |
| Report generating | **Progress indicator with a stage label** and an explicit "you can leave this screen" note | Indeterminate spinner with no text |
| Photo uploading | Progress on the photo thumbnail | Blocking dialog |
| Realtime reconnecting | Thin banner at the top, non-blocking | Dialog |

### Rules
- **Never block the whole screen** unless the user genuinely cannot continue.
- Under about 300 ms, show nothing. A flash of a loader feels worse than a short wait.
- Over about 10 seconds, show progress and what is happening. "Loading…" alone is not acceptable.
- A loading state must always be able to reach an error state. A spinner that can spin forever is a bug.
- **Every loading state needs a timeout** that resolves to an error with a retry.

---

## 7. Skeletons

Skeletons mirror the real layout so content does not jump when it arrives.

### Appearance
- Base `neutral-100`, shimmer highlight `neutral-300`.
- Shimmer travels left to right, roughly 1.5 s per cycle. Subtle, not animated hard.
- Corner radius matches the real element.
- Text lines render as bars at the real line height, with the last line about 60% width.

### Where each is needed
| Screen | Skeleton |
|---|---|
| Employee list | 6 rows: circular avatar, two text bars, a status pill |
| Notification centre | 6 rows: icon, title bar, body bar, timestamp bar |
| Duty history | 5 cards: date bar plus a 4-cell stat grid |
| Employee profile | Avatar block, 3 info bars, a stat-card row |
| Stat cards | Rectangle of the card's exact size |
| Places list | 5 rows: icon, name bar, radius and type bar |
| Visit list | 5 rows: square photo placeholder, two text bars |
| Report preview | Header bar plus 8 table rows |

### Rules
- Show between 3 and 8 skeleton rows. More looks broken.
- **A skeleton is never shown for longer than about 10 seconds.** Move to an error state after that.
- Never skeleton a map. Use a branded placeholder instead.
- Never mix skeletons and real content in the same list on first load.

---

## 8. Pagination

**Every list is paginated from the first version.** No exceptions. An unpaginated list is a defect, not a shortcut.

### Strategy

| List | Approach | Page size |
|---|---|---|
| Employee list | Infinite scroll, keyset | 20 |
| Notification centre | Infinite scroll, keyset | 25 |
| Duty history | Infinite scroll, keyset | 20 |
| Visit list | Infinite scroll, keyset | 20 |
| Places list | Infinite scroll, keyset | 25 |
| Geofence events | Infinite scroll, keyset | 25 |
| Location points, in the route view | Load the whole day by session, then simplify for drawing | n/a |
| Report rows | Server-side, numbered pages | 50 |

### Use keyset pagination, not offset

Keyset — "give me rows after this timestamp and id" — stays fast as data grows and does not skip or duplicate rows when new data arrives mid-scroll. Offset pagination does both of those things badly on a live dataset like this one. Details in [06-SUPABASE-BEST-PRACTICES.md](06-SUPABASE-BEST-PRACTICES.md).

### Behaviour
- Trigger the next page when roughly 80% scrolled, not at the very bottom.
- Loading the next page shows a small inline spinner at the end, **never** a skeleton and never a jump.
- A failed page load shows an inline retry row, and keeps everything already loaded.
- The end of a list shows a quiet "No more records" marker, not an endless spinner.
- Scroll position must survive navigating away and back.
- Pull to refresh resets to the first page.
- Refreshing a list the user is reading must not yank their position.

---

## 9. Filters, search, and sort

### Pattern
- **Search** sits in a pinned field at the top of the list. Debounced at 300 ms. A clear button appears once there is text.
- **Filters** open in a bottom sheet from a filter button that carries a badge with the number of active filters.
- **Quick filters** are horizontally scrolling chips directly under the search field, for the two or three most-used options.
- **Sort** lives inside the filter sheet, not as a separate control.

### Filters by screen

| Screen | Filters |
|---|---|
| Employee list | Status (active, blocked), duty state (on, off), has flags, sort by name / code / last active |
| Live map | Status (the five map statuses), place, search by name or code |
| Notification centre | Unread only, type, employee, date range |
| Duty history | Date range, end reason (manual, auto, blocked), has flags, min hours |
| Visit list | Date range, place, photo (attached, skipped), type (geofence, manual) |
| Places list | Type, active state, search by name |
| Reports | Report type, employee or team, date range |

### Rules
- **Filters are applied on the server**, inside the query. Never fetch everything and filter on the device.
- Active filters appear as removable chips above the list, so state is never hidden.
- "Clear all" is always available when any filter is active.
- Filter state survives rotation and a trip to another screen and back.
- A filter combination with no results shows a **filtered empty state** with a clear-filters action — distinct from a genuinely empty list.
- Date ranges offer presets: Today, Yesterday, Last 7 days, This month, Last month, Custom.
- Never let a filter silently produce a misleading report. Always print the applied filters on the export.

---

## 10. Empty and error states

### Empty states
Three parts: an illustration or icon, a one-line explanation, and an action where one makes sense.

| Case | Message | Action |
|---|---|---|
| No employees yet | "No employees yet. Add your first team member." | Add employee |
| Nobody on duty | "No one is on duty right now." | View all employees |
| No notifications | "You're all caught up." | — |
| No duty history | "No duty records yet." | — |
| No route for the day | "No location recorded on this date." | Pick another date |
| No visits | "No visits recorded." | — |
| **Filtered to nothing** | "No results for these filters." | **Clear filters** |
| Search found nothing | "Nothing matches '<term>'." | Clear search |
| Route older than 30 days | "Detailed route is kept for 30 days. Totals for this day are still available." | View summary |

### Error states
Every error says **what happened, why if known, and what to do.** Never show a raw exception or an error code alone.

| Case | Message | Action |
|---|---|---|
| No internet | "No internet connection. Your work is saved and will sync automatically." | Retry |
| Request failed | "Couldn't load this. Please try again." | Retry |
| Permission denied | "You don't have access to this." | Go back |
| Location permission missing | "Location permission is needed to start duty." | Open settings |
| Location services off | "Turn on location to start duty." | Open settings |
| Battery optimisation on | "Battery saver may stop tracking. Allow background activity for accurate records." | Open settings |
| Outside duty hours | "Duty can be started between 8:00 AM and 11:00 PM." | — |
| Account blocked | "Your account is blocked. Please contact the office." | — |
| Wrong device | "This account is registered to another device. Contact the office." | — |
| Report failed | "Report could not be generated. Try a shorter date range." | Retry |

### Rules
- A full-screen error is only for a screen that has no content at all. Otherwise use an inline banner or a snackbar and keep the content visible.
- A retry must actually retry, not reload the whole app.
- **Offline is never an error for the employee.** It is a reassuring info banner, because their data is safely queued.

---

## 11. Core components

### Buttons
| Variant | Appearance | Use |
|---|---|---|
| Primary | `primary-600` fill, white text, `radius-md`, 48 dp tall | The main action |
| Secondary | `primary-600` outline and text, transparent fill | Alternative action |
| Tertiary | Text only, `primary-600` | Low-emphasis action |
| Destructive | `error` fill, white text | Block an employee, delete a place |
| Icon | 48 × 48 dp target, 24 dp icon | Toolbar actions |

States: default, pressed (one step darker), disabled (`primary-300` fill, `neutral-400` text), loading (inline spinner, disabled, label changes).
**A disabled button always explains why**, through nearby helper text or a tooltip. A dead control with no explanation is a defect.

### Duty toggle
The signature component. At least 120 dp tall, full content width, `radius-full`.
- **Off:** `neutral-100` fill, `neutral-600` label "Start duty".
- **On:** `success` fill, white label "On duty", with a live elapsed timer.
- **Disabled:** `neutral-100` fill, `neutral-400` label, with the reason and the next available time directly beneath.
- Switching plays a short animation and a haptic tap. It never changes appearance until the server confirms, except for a brief optimistic "Starting…".

### Stat card
Label in `overline`, value in `display` with tabular figures, unit in `label`, optional trend in `caption`. Used for today's km, hours, and visits.

### Employee list row
48 dp circular avatar with initials, name in `title`, code and phone in `body`, a status pill on the right, and a chevron. Row height is at least 72 dp.

### Status pill
`radius-full`, the status colour at 12% opacity as the background, the status colour as the text, an 8 dp dot, and the label in `label` size. **Colour plus text, always.**

### Banner
Full width, `radius-md`, 16 dp padding, semantic background and an icon. Dismissible only when the condition is not blocking.

### Bottom sheet
`radius-xl` on the top corners, drag handle, title in `h3`, scrollable content, actions pinned at the bottom. Used for filters, place pickers, and visit capture.

### Map marker
32 dp circle in the status colour, white border, a status icon inside, and the employee's initials. Clusters render as a larger circle carrying the count and the colour of the most severe status present.

### Form inputs
48 dp minimum height, `radius-md`, `neutral-300` border, `primary-600` border when focused, `error` border and message when invalid. Label above the field, not as a placeholder, because a placeholder disappears exactly when it is needed. Helper text sits below.

---

## 12. Motion

- Standard duration **200 ms**, with the standard easing curve.
- Page transitions 250 ms, slide plus fade.
- Bottom sheets 250 ms up, 200 ms down.
- Skeleton shimmer 1.5 s, looping.
- The duty toggle gets a slightly longer 300 ms transition, because it is a deliberate, significant action.
- **Respect the system "reduce motion" setting.** Fall back to a cross-fade.
- Never animate a list reorder while the user is scrolling it.

---

## 13. Iconography and assets

- One icon set throughout. 24 dp default, 20 dp dense, 32 dp for map markers.
- `neutral-600` by default, `primary-600` when active, the status colour for status.
- **An icon never carries meaning alone.** Pair it with text or a label.
- The app icon uses the brand colour with a mark that stays legible at 48 dp.
- The splash screen is `primary-600` with the logo centred. No spinner.

---

## 14. Accessibility checklist

Checked before any screen is considered done.

- [ ] Text contrast is at least 4.5:1, and 3:1 for large text. Verified, not assumed.
- [ ] Status is conveyed by colour **plus** text or shape.
- [ ] Every touch target is at least 48 × 48 dp.
- [ ] Layout survives font scaling to 150%.
- [ ] Every interactive element has a screen-reader label.
- [ ] Every image and icon-only button has a semantic label.
- [ ] Focus order is logical.
- [ ] No information is conveyed by colour alone.
- [ ] Error messages are linked to their field for screen readers.
- [ ] Reduce-motion is respected.

---

## 15. Performance rules

- `const` constructors wherever possible; avoid rebuilding subtrees needlessly.
- Every long list is lazily built. Never build 150 rows at once.
- Images are cached, sized, and never decoded larger than they are displayed.
- Map markers are clustered beyond about 50 visible points.
- Route lines are simplified for drawing. Never hand 3,000 raw points to the renderer.
- Heavy work — report assembly, large parsing — goes off the UI thread.
- Target a steady 60 fps while scrolling and panning the map. **Measure it on a budget phone, not a flagship.**
