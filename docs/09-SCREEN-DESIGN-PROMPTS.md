# 09 — Screen Design Prompts

AI prompts for generating a design for every screen in the app. Generate the design, then hand it back and it becomes the reference for building that screen.

**How to use this file**

1. Copy the **Master Style Block** in section 1.
2. Paste it, then paste the screen prompt you want underneath it.
3. Generate. Review against the checklist in section 6.
4. Save the result as `designs/<screen-number>-<name>.png` and tell me which screens are ready.

Every prompt already matches [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md). If a generated design contradicts the design system, **the design system wins** — or the design system gets updated deliberately, with approval. Do not let a generated image quietly become the source of truth.

**Screen count: 30.** Build order matches [02-DEVELOPMENT-PLAN.md](02-DEVELOPMENT-PLAN.md), so you do not need all 30 before work starts. Phase 1 needs screens 1–5. Phase 2 needs 6–11.

> ### ✅ All 30 screens are cleared to generate
>
> The map-provider question was resolved on 2026-10-13 by switching to **MapLibre + OpenFreeMap**, which carry no use-case restriction. Two consequences for these prompts: map attribution now credits **OpenStreetMap**, not Mapbox, and **there is no satellite view** — screen 25 uses a street map.
---

## 1. Master Style Block

Paste this **above every screen prompt**, unchanged.

```
You are designing a screen for "Diamond Agritech Tracking" — an Android employee
GPS and duty-tracking app used by agricultural field staff in India.

OUTPUT
- A single mobile app screen, high fidelity, pixel-perfect, flat vector UI style.
- Frame: 390 x 844 px, Android portrait. Show the screen only — no device mockup,
  no hand, no shadow behind the phone, no marketing text around it.
- Realistic UI, not an illustration. It should look like a screenshot of a real,
  modern, shipped app.

BRAND
- Company: Diamond Agritech
- Primary brand colour: #016893 (a deep teal-blue)
- Font: DM Sans only, weights 400 / 500 / 600 / 700

THEME: LIGHT MODE ONLY. Never produce a dark variant.

COLOUR TOKENS — use these exact values and nothing else
- Brand:        #016893  (buttons, app bar, active state, links)
- Brand dark:   #015676  (pressed state)
- Brand tint:   #E8F3F8  (selected row, subtle background)
- Brand tint 2: #C5E1EC  (chip background)
- Page background: #F8FAFC
- Card surface:    #FFFFFF
- Border/divider:  #E2E8F0
- Input border:    #CBD5E1
- Text primary:    #0F172A
- Text secondary:  #64748B
- Text disabled:   #94A3B8
- Success / on duty: #16A34A   (bg #DCFCE7)
- Warning / stale:   #F59E0B   (bg #FEF3C7)
- Error / suspect:   #DC2626   (bg #FEE2E2)
- Info:              #0284C7   (bg #E0F2FE)
- Off duty grey:     #94A3B8
- Blocked:           #1E293B

TYPE SCALE — exact sizes, DM Sans
- Display 32/40 Bold      (big stat numbers)
- H2 24/32 SemiBold       (section heading)
- H3 20/28 SemiBold       (app bar title, card title)
- Title 18/26 SemiBold    (list item title)
- Body L 16/24 Regular    (input text, primary reading)
- Body 14/20 Regular      (default text, list subtitle)
- Label 13/18 Medium      (button text, chip, field label)
- Caption 12/16 Regular   (timestamp, helper text)
- Overline 11/16 SemiBold, uppercase, +0.5 letter spacing (micro heading)

LAYOUT
- Horizontal screen padding: 16px, always. No horizontal scrolling.
- Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 only.
- Corner radius: 8 small, 12 default (buttons, inputs, cards), 16 large cards,
  24 bottom sheets, fully rounded for pills and avatars.
- Minimum touch target 48x48px. List rows at least 72px tall.
- Flat design. Use 1px #E2E8F0 borders instead of heavy drop shadows.
- Buttons: 48px tall, 12px radius, #016893 fill, white 13px Medium label.

HARD RULES
- Status is ALWAYS colour + a text label. Never colour alone.
- Numbers in stat cards and tables use tabular (monospaced-width) figures.
- Labels sit ABOVE input fields, never as placeholder-only.
- No gradients, no glassmorphism, no neon, no 3D, no drop-shadow stacking.
- No lorem ipsum. Use the realistic Indian sample data given in the prompt.
- All times in 12-hour format with AM/PM (India). Dates as "12 Oct 2026".
- Distance in km with one decimal. Duration as "7h 24m".
- English only.
```

---

## 2. Auth and onboarding screens

### Screen 01 — Splash

```
SCREEN: Splash / app launch.

Full-bleed #016893 background. Centred vertically and horizontally: the Diamond
Agritech logo mark as a simple white geometric diamond outline, 88px, with the
wordmark "Diamond Agritech" beneath it in white DM Sans SemiBold 24px, and the
tagline "Field Tracking" below that in white at 70% opacity, DM Sans Regular 14px.

At the very bottom, 32px above the safe area: "v1.0.0" in white at 50% opacity,
Caption 12px.

No spinner, no progress bar, no loading text. Calm and completely still.
```

### Screen 02 — Employee login

```
SCREEN: Employee login. This is the first screen a field worker sees.

Top: a 160px tall #016893 header block with the bottom corners rounded 24px.
Inside it, left-aligned at 16px padding: the white diamond logo mark at 40px,
then "Diamond Agritech" in white SemiBold 20px, then "Employee Login" in white
at 80% opacity, Body 14px.

Below the header, on #F8FAFC background, a white card (radius 16, 1px #E2E8F0
border, 20px internal padding), overlapping the header by 24px:

- Field label "Employee ID" (Label 13px, #64748B) above a 48px input,
  radius 12, 1px #CBD5E1 border, containing the value "DA-014" in Body L 16px
  #0F172A. A small ID-card icon on the left inside the field, #94A3B8.
- 16px gap.
- Field label "PIN" above a 48px input showing 6 filled dots, with an
  eye-reveal icon on the right in #94A3B8.
- 8px gap, right-aligned text link "Forgot PIN?" in #016893 Label 13px.
- 24px gap.
- Full-width primary button, 48px, #016893, radius 12, white label "Log in".

Below the card, centred, Caption 12px #64748B:
"Contact the office if you cannot sign in."

At the bottom of the screen, a subtle horizontally centred text button
"Admin login" in #016893 Label 13px.

Include a 1-line info strip under the PIN field in #FEE2E2 with #DC2626 text,
Caption 12px, reading "Incorrect PIN. 3 attempts remaining." — to show the
error state styling.
```

### Screen 03 — Admin login

```
SCREEN: Admin login. Same visual family as the employee login but clearly
a different, more desk-oriented screen.

Top: #016893 header block 140px tall, bottom corners rounded 24px, with the
white diamond logo at 36px and "Admin Login" in white SemiBold 20px.

White card overlapping the header by 24px, radius 16, 1px #E2E8F0 border,
20px padding:
- Label "Email" above a 48px input containing "office@diamondagritech.in"
  in Body L 16px, with a mail icon on the left in #94A3B8.
- Label "Password" above a 48px input with 8 dots and an eye-reveal icon.
- A row with a 20px checkbox "Keep me signed in" (Body 14px #475569) on the
  left, and a "Forgot password?" link in #016893 Label 13px on the right.
- Full-width 48px #016893 button "Log in".

Bottom of the screen: text button "Employee login" in #016893 Label 13px, centred.
```

### Screen 04 — First-login PIN change

```
SCREEN: Forced PIN change on first login. The employee cannot skip this.

App bar: white, 56px, title "Create your PIN" H3 20px #0F172A. NO back arrow
and no close icon — this step is mandatory.

Body, 16px padding:
- A 64px circular #E8F3F8 badge with a #016893 lock icon, centred.
- H2 24px #0F172A centred: "Set a new PIN"
- Body 14px #64748B centred, max 2 lines:
  "Choose a 6-digit PIN. You will use it every time you log in."
- 32px gap.
- Label "New PIN" above a row of 6 separate 48x56px boxes, radius 12,
  1px #CBD5E1 border, 8px apart. The first 3 contain filled dots, the 4th has
  a #016893 2px focus border and a blinking caret, the last 2 are empty.
- 20px gap. Label "Confirm PIN" above an identical empty 6-box row.
- 16px gap. A rules checklist, Caption 12px, each with a small leading icon:
  green check #16A34A "6 digits"
  green check #16A34A "Not the same digit repeated"
  grey #94A3B8 circle "Not a sequence like 123456"
- Spacer, then a full-width 48px #016893 button "Save PIN" shown DISABLED
  (#76B9D2 fill, #94A3B8 label) because the form is incomplete.
```

### Screen 05 — Permission and battery setup

```
SCREEN: Permission setup, shown once before an employee can start duty.
A 3-step vertical checklist on one screen, not a carousel.

App bar: white, 56px, title "Before you start" H3 20px.

Body, 16px padding:
- Body 14px #64748B: "Duty tracking needs these three settings. We only record
  your location while you are on duty."
- 24px gap.

Three stacked cards, each white, radius 12, 1px #E2E8F0 border, 16px padding,
12px apart. Each card has a 40px circular icon badge on the left, title in
Title 18px, one line of Body 14px #64748B below it, and a trailing element:

Card 1 — DONE state: badge #DCFCE7 with a green #16A34A location pin icon.
Title "Location access". Subtitle "Granted". Trailing: a green #16A34A
check-circle icon, 24px.

Card 2 — ACTION NEEDED: badge #E0F2FE with a #0284C7 clock icon.
Title "Allow all the time". Subtitle "Needed so tracking continues when your
screen is off." Trailing: a 36px tall #016893 pill button "Allow".
Give this card a 2px #016893 border to mark it as the current step.

Card 3 — ACTION NEEDED: badge #FEF3C7 with an #F59E0B battery icon.
Title "Disable battery saver". Subtitle "Your phone may stop tracking without
this." Trailing: a 36px tall outlined button, #016893 border and text, "Open".

Below the cards, a #FEF3C7 banner, radius 12, 16px padding, with an #F59E0B
warning triangle and text in #0F172A Body 14px:
"On Xiaomi, Oppo, Vivo and Realme phones this step is essential, or your duty
record may have gaps."

At the bottom, full-width 48px button "Continue", DISABLED (#76B9D2) because
steps 2 and 3 are incomplete, with Caption 12px #94A3B8 centred beneath:
"Complete all three steps to continue."
```

---

## 3. Employee screens

### Screen 06 — Employee home, duty OFF

```
SCREEN: Employee home screen, duty currently OFF. The most important screen
in the app. The duty toggle must dominate it.

App bar: #016893, 56px. Left: white 32px circular avatar with initials "RK".
Centre-left: "Ramesh Kumar" white SemiBold 16px with "DA-014" below in white
80% opacity Caption 12px. Right: a white outline bell icon, no badge.

Body on #F8FAFC, 16px padding:

1. A #E0F2FE info strip, radius 12, 12px padding, with a #0284C7 info icon and
   Body 14px #0F172A: "Duty hours today: 8:00 AM to 11:00 PM".

2. THE DUTY TOGGLE — the hero element. A 140px tall, full-width, fully rounded
   (70px radius) card with #F1F5F9 fill and a 2px #CBD5E1 border. Centred
   inside: a 48px #94A3B8 power icon, then "Start duty" in SemiBold 20px
   #475569, then Caption 12px #94A3B8 "Tap to begin tracking".

3. Overline 11px uppercase #64748B "TODAY SO FAR".
   A row of three equal white stat cards, radius 12, 1px #E2E8F0 border,
   16px padding, 12px apart. Each: Overline label on top, then the value in
   Display 32px Bold #0F172A with tabular figures, then a Caption unit.
   - "HOURS" / "0h 0m"
   - "DISTANCE" / "0.0" / "km"
   - "VISITS" / "0"
   Because the day has not started, all values are in #94A3B8 instead of #0F172A.

4. A white card, radius 12, 1px #E2E8F0 border, 16px padding, titled
   "Yesterday" Title 18px, with three inline rows, each Body 14px with the
   label in #64748B and the value right-aligned in #0F172A SemiBold:
   "Hours" / "8h 12m"
   "Distance" / "47.3 km"
   "Visits" / "5"
   A trailing text link "View history" in #016893 Label 13px at the bottom.

Bottom navigation bar: white, 64px, 1px top border #E2E8F0, three items with
24px icons and Caption 12px labels. "Duty" (active, #016893, filled icon),
"Map" (#94A3B8), "History" (#94A3B8).
```

### Screen 07 — Employee home, duty ON

```
SCREEN: Employee home screen with duty ACTIVE. Same structure as the duty-OFF
version, but alive and green. Generate this as a clear visual pair with it.

App bar: #016893, 56px, same avatar "RK" / "Ramesh Kumar" / "DA-014", bell on
the right now showing no badge.

Body on #F8FAFC, 16px padding:

1. A #DCFCE7 strip, radius 12, 12px padding: a pulsing green #16A34A dot, then
   Body 14px #0F172A SemiBold "Tracking active", then right-aligned Caption 12px
   #64748B "Updated 12 sec ago".

2. THE DUTY TOGGLE, active state: 140px tall, full width, fully rounded,
   #16A34A fill, no border. Centred inside, all white:
   - Overline 11px uppercase at 80% opacity: "ON DUTY SINCE 8:04 AM"
   - The live elapsed timer in Display 32px Bold, tabular figures: "7h 24m"
   - A 40px tall pill with a white 1.5px border and white Label 13px text:
     "Tap to end duty"

3. Overline "TODAY SO FAR" and the same three stat cards, now with live values
   in #0F172A: "HOURS / 7h 24m", "DISTANCE / 38.6 km", "VISITS / 3".

4. A white card, radius 12, 16px padding, titled "Current location" Title 18px.
   Inside: a 120px tall rounded (12px) map thumbnail showing a light-styled
   road map with a single #16A34A pin at its centre, and beneath it
   Caption 12px #64748B "Nashik Road, Maharashtra · accuracy 8 m".
   A trailing text link "Open map" in #016893 Label 13px.

5. A #FEF3C7 strip, radius 12, 12px padding, with an #F59E0B cloud-off icon and
   Body 14px #0F172A: "12 points waiting to sync" plus Caption 12px #64748B
   beneath: "They will upload automatically."

Bottom navigation: same three items, "Duty" active in #016893.
```

### Screen 08 — Employee home, duty disabled (outside hours)

```
SCREEN: Employee home with the duty toggle DISABLED because it is outside the
8:00 AM to 11:00 PM window. Same layout as the duty-OFF screen.

App bar: #016893, 56px, avatar "RK", "Ramesh Kumar", "DA-014", bell.

Body on #F8FAFC, 16px padding:

1. A #FEF3C7 strip, radius 12, 12px padding, with an #F59E0B clock icon and
   Body 14px #0F172A SemiBold "Outside duty hours" and Caption 12px #64748B
   beneath: "Duty can be started between 8:00 AM and 11:00 PM."

2. THE DUTY TOGGLE, disabled state: 140px tall, full width, fully rounded,
   #F1F5F9 fill, 2px #E2E8F0 dashed border. Centred: a 48px #CBD5E1 power icon
   with a small slash through it, "Start duty" in SemiBold 20px #94A3B8, and
   below it a #E2E8F0 pill containing Caption 12px #64748B
   "Available in 6h 42m · 8:00 AM".
   The whole block must read as clearly non-tappable, not merely pale.

3. Overline "TODAY SO FAR" with the three stat cards showing the completed day
   in #0F172A: "HOURS / 8h 56m", "DISTANCE / 52.1 km", "VISITS / 6".

4. A white card titled "Today's duty" Title 18px, radius 12, 16px padding,
   containing two rows: "Started" / "8:02 AM" and "Ended" / "11:00 PM", and
   below them a #FEF3C7 inline chip with Caption 12px #92400E reading
   "Duty ended automatically".

Bottom navigation: "Duty" active.
```

### Screen 09 — Employee live map

```
SCREEN: The employee's own live map while on duty. They see only themselves.

Full-bleed light-styled road map filling the screen behind everything. Quiet,
desaturated map: pale #F1F5F9 land, white roads, soft #C5E1EC water, minimal
labels. A clear green #16A34A route line, 4px, tracing a winding road with
about 6 gentle bends, ending at a 36px #16A34A circular marker with a white
border and a white dot inside. A small #94A3B8 flag marker at the route start.
Three small #016893 pin markers along the route for recorded visits.

Overlaid on top:

- A floating app bar: a white card, radius 12, 1px #E2E8F0 border, inset 16px
  from the top and sides, 48px tall. Inside: a #016893 back chevron, the title
  "My location" Title 18px #0F172A, and on the right a #DCFCE7 pill with a
  green dot and Label 13px #15803D "On duty".

- Bottom sheet, white, top corners radius 24, 1px #E2E8F0 top border, pinned to
  the bottom, with a 32x4px #CBD5E1 drag handle centred at the top and 16px
  padding. Inside:
  - Overline 11px uppercase #64748B "TODAY"
  - A row of three stat blocks separated by thin 1px #E2E8F0 vertical dividers,
    each with Display 28px Bold tabular value and a Caption 12px #64748B label:
    "7h 24m / Hours", "38.6 / km", "3 / Visits"
  - 16px gap
  - A full-width 48px #016893 button, radius 12, with a camera icon and the
    white label "Add visit".

- Two stacked circular floating buttons, 48px, white, 1px #E2E8F0 border, soft
  shadow, on the right side just above the bottom sheet: a #016893 crosshair
  re-centre icon. NOTE: there is no satellite view in this app, so do not add
  a layers or map-type toggle button.

- OpenStreetMap attribution, small and legible, bottom-left above the sheet.
```

### Screen 10 — Visit capture

```
SCREEN: Visit capture. Auto-prompted when the employee enters a registered
place, and also reachable manually. Camera capture only — there must be NO
gallery button anywhere.

Presented as a tall bottom sheet covering about 85% of the screen height, white,
top corners radius 24, over a dimmed #0F172A 40% scrim showing a hint of the
map behind.

Inside, 16px padding:
- A 32x4px #CBD5E1 drag handle, centred.
- A header row: "Add visit" H3 20px #0F172A on the left, a 40px circular
  #F1F5F9 close button with a #475569 X icon on the right.
- A #E8F3F8 strip, radius 12, 12px padding, with a #016893 location pin icon,
  Body 14px #0F172A SemiBold "Shivpuri Farm" and Caption 12px #64748B beneath:
  "You arrived at 2:14 PM · within 500 m".
- Overline 11px uppercase #64748B "PHOTO".
- A 200px tall photo area, radius 12, filled with a realistic photograph of a
  green Indian agricultural field with crop rows under daylight. Over its
  bottom-left corner, a semi-transparent #0F172A 70% rounded chip containing
  white Caption 12px over two lines: "12 Oct 2026, 2:15 PM" and
  "19.9975° N, 73.7898° E".
  In the photo's top-right corner, a 36px circular white button with a #475569
  retake/refresh icon.
- Overline "NOTE (OPTIONAL)".
- A 96px tall multi-line text area, radius 12, 1px #CBD5E1 border, containing
  the typed text "Met owner, discussed kharif seed order." in Body L 16px
  #0F172A, with Caption 12px #94A3B8 bottom-right inside: "42/200".
- 16px gap.
- A full-width 48px #016893 button "Save visit".
- Below it, a full-width 48px TEXT button, no fill, with the label
  "Skip photo" in #64748B Label 13px.
```

### Screen 11 — Duty-off summary

```
SCREEN: Summary shown immediately after the employee ends duty. Should feel
like a satisfying, calm close to the day.

Presented as a centred modal card, radius 24, white, 24px padding, with 24px
margins on each side, over a #0F172A 50% scrim.

Inside, centred:
- A 72px circular #DCFCE7 badge containing a green #16A34A check icon.
- H2 24px #0F172A "Duty ended"
- Body 14px #64748B "12 Oct 2026 · 8:04 AM to 4:28 PM"
- 24px gap.
- A #F8FAFC inner panel, radius 12, 16px padding, containing three rows, each
  with a 20px #64748B leading icon, a Body 14px #64748B label on the left and a
  SemiBold 18px #0F172A tabular value right-aligned:
  clock icon   "Total hours"    "8h 24m"
  road icon    "Distance"       "52.1 km"
  pin icon     "Visits"         "6"
- 8px gap, then a small row in Caption 12px #94A3B8, centred:
  "All data synced" with a small green #16A34A check icon before it.
- 24px gap.
- A full-width 48px #016893 button "Done".
- A full-width text button below it, "View today's route", in #016893 Label 13px.
```

### Screen 12 — My duty history (employee)

```
SCREEN: The employee's own duty history. A scrollable list of past days.

App bar: white, 56px, 1px bottom border #E2E8F0. A #016893 back chevron, title
"My history" H3 20px #0F172A, and a #475569 filter icon on the right carrying a
small #016893 badge with "1".

Below the app bar, a horizontally scrolling row of filter chips, 32px tall,
fully rounded, 8px apart, with 16px side padding. The first chip is SELECTED:
#016893 fill, white Label 13px, "This month". The rest are unselected: white
fill, 1px #CBD5E1 border, #475569 Label 13px — "Last month", "Auto-ended",
"Custom".

A #E8F3F8 summary card, radius 12, 16px padding, margin 16px: Overline 11px
uppercase #64748B "OCTOBER 2026" on top, then a row of four stat blocks with
Display 24px Bold #016893 tabular values and Caption 12px #64748B labels:
"11 / Days", "89h 12m / Hours", "534.8 / km", "48 / Visits".

Then the list. Each row is a white card, radius 12, 1px #E2E8F0 border, 16px
padding, 12px apart, at least 88px tall:
- Top row: the date "Sat, 11 Oct" Title 18px #0F172A on the left, and on the
  right a status chip.
- Second row: four inline stats in Body 14px, each a #64748B label with a
  #0F172A SemiBold value — "8:02 AM – 6:30 PM", "8h 28m", "47.3 km", "5 visits".

Show four rows with different chips so every state is visible:
1. "Sat, 11 Oct" — no chip. Normal day.
2. "Fri, 10 Oct" — #FEF3C7 chip, #92400E Label 13px, "Auto-ended".
3. "Thu, 09 Oct" — #FEE2E2 chip, #DC2626 Label 13px, "2 flags".
4. "Wed, 08 Oct" — a greyed row, #F8FAFC fill, with a #94A3B8 chip "No duty"
   and all stat values as "—".

At the bottom of the visible list, a centred 24px #016893 circular spinner,
indicating the next page is loading.
```

### Screen 13 — My profile (employee)

```
SCREEN: The employee's own profile. Mostly read-only — they can change their
PIN and nothing else.

App bar: #016893, 140px tall, bottom corners radius 24. A white back chevron
top-left. Centred inside: a 72px white circular avatar containing "RK" in
#016893 SemiBold 24px, then "Ramesh Kumar" in white SemiBold 20px, then a white
15%-opacity pill containing white Label 13px "DA-014".

Body on #F8FAFC, 16px padding, overlapping the header by 24px:

1. A white card, radius 16, 1px #E2E8F0 border, titled Overline 11px uppercase
   #64748B "MY DETAILS" with 16px padding. Three rows separated by 1px #E2E8F0
   dividers, each 56px tall with a 20px #94A3B8 leading icon, a Caption 12px
   #64748B label above a Body 14px #0F172A value:
   phone icon  "Phone"        "+91 98765 43210"
   mail icon   "Email"        "ramesh.k@diamondagritech.in"
   calendar    "Joined"       "04 Mar 2026"

2. A white card titled Overline "THIS MONTH", 16px padding, with a 2x2 grid of
   stat blocks, 12px gaps. Each: Display 24px Bold #0F172A tabular value with a
   Caption 12px #64748B label beneath — "11 Days worked", "89h 12m Hours",
   "534.8 km Distance", "48 Visits".

3. A white card with two tappable rows, each 56px, with a 20px #64748B leading
   icon, Body 14px #0F172A label and a #CBD5E1 trailing chevron:
   lock icon    "Change PIN"
   shield icon  "Privacy and tracking"

4. A full-width 48px outlined button, 1px #DC2626 border, #DC2626 Label 13px,
   with a logout icon: "Log out".

5. Centred Caption 12px #94A3B8 at the bottom: "Diamond Agritech · v1.0.0".
```

---

## 4. Admin screens

### Screen 14 — Admin home / dashboard

```
SCREEN: Admin dashboard, the first screen an office admin sees. Must answer
"who is working right now?" in under two seconds.

App bar: #016893, 56px. Left: "Diamond Agritech" white SemiBold 18px with
Caption 12px white 80% "Admin" beneath. Right: a white outline bell icon with a
#DC2626 badge circle containing white "7", and a white 32px circular avatar.

Body on #F8FAFC, 16px padding:

1. Caption 12px #64748B "Sunday, 12 October 2026 · 2:48 PM".

2. A 2x2 grid of stat cards, 12px gaps. Each white, radius 12, 1px #E2E8F0
   border, 16px padding, with a 32px circular tinted icon badge top-left, the
   value in Display 32px Bold tabular beneath it, and an Overline 11px
   uppercase label under that:
   - #DCFCE7 badge, green person icon, "112" in #0F172A, "ON DUTY"
   - #F1F5F9 badge, #94A3B8 person icon, "31" in #0F172A, "OFF DUTY"
   - #FEF3C7 badge, #F59E0B signal icon, "4" in #0F172A, "NO UPDATE"
   - #FEE2E2 badge, #DC2626 alert icon, "3" in #0F172A, "NEEDS CHECK"
   Give the last two cards a 1px border in their own semantic colour so they
   read as needing attention.

3. A white card, radius 16, 1px #E2E8F0 border, with a header row:
   "Live map" Title 18px #0F172A on the left, "View all" link #016893 Label 13px
   on the right. Below it, a 180px tall map thumbnail with the bottom corners
   rounded 16px, showing a light-styled regional map scattered with about 14
   small circular markers — mostly #16A34A, two #F59E0B, one #DC2626 — plus two
   cluster bubbles showing "12" and "8" in white on #16A34A.

4. A white card titled "Recent activity" Title 18px with a "See all" link.
   Four rows, each 64px, separated by 1px #E2E8F0 dividers. Each row: a 36px
   circular tinted badge with an icon, a Body 14px #0F172A title, a Caption 12px
   #64748B subtitle, and a right-aligned Caption 12px #94A3B8 time.
   - #DCFCE7 / green power icon — "Suresh Patel started duty" / "DA-022" / "2m"
   - #FEE2E2 / red alert icon — "Anil Sharma — location flagged" / "DA-008" / "14m"
   - #E8F3F8 / #016893 pin icon — "Vijay Singh reached Shivpuri Farm" / "DA-031" / "26m"
   - #FEF3C7 / amber signal icon — "Prakash Rao — no update 12 min" / "DA-017" / "31m"

Bottom navigation: white, 64px, 1px top border, FIVE items with 24px icons and
Caption 12px labels: "Home" (active, #016893), "Map", "Team", "Places",
"Reports" — the inactive ones in #94A3B8.
```

### Screen 15 — Admin live map

```
SCREEN: The admin live map with all 143 employees. The hardest screen in the
app. It must stay readable at this density.

Full-bleed light-styled regional map of a district in Maharashtra, India:
pale #F1F5F9 land, white road network, soft #C5E1EC water, restrained grey
labels. Deliberately quiet, so the markers dominate.

Markers — each a 32px circle with a 2px white border and a small white icon
inside, so status survives greyscale:
- about 10 individual #16A34A markers (person icon)
- 2 individual #F59E0B markers (signal-off icon)
- 1 individual #DC2626 marker, slightly larger at 40px with a thin #DC2626 halo
  ring, warning icon
- 4 cluster bubbles at 48px, white 2px border, white SemiBold 16px count
  inside: "34" and "21" in #16A34A, "12" in #F59E0B, "6" in #1E293B

Overlaid:

- Floating search bar: white card inset 16px from top and sides, 48px tall,
  radius 12, 1px #E2E8F0 border, soft shadow. A #94A3B8 search icon, the
  placeholder "Search name or ID" in Body L 16px #94A3B8, and on the right a
  #475569 filter icon with a #016893 badge "2".

- Directly below it, a horizontally scrolling row of status filter chips, 32px
  tall, fully rounded, 8px apart. Each has a leading 8px status dot and a count:
  SELECTED "All 143" in #016893 fill with white text; then white chips with 1px
  #CBD5E1 borders — green dot "On duty 112", amber dot "Stale 4",
  red dot "Check 3", grey dot "Off 31", near-black dot "Blocked 2".

- Bottom-right, a vertical stack of three 48px circular white buttons with 1px
  #E2E8F0 borders and soft shadows: a #016893 crosshair, a #64748B layers icon,
  and a #64748B list icon (the list-view alternative).

- Bottom-left, a small white pill, radius 999, 1px #E2E8F0 border, 8px padding,
  containing a pulsing green #16A34A dot and Caption 12px #64748B "Live".

- OpenStreetMap attribution, legible, bottom-left beneath the pill.
```

### Screen 16 — Live map, employee detail sheet

```
SCREEN: The bottom sheet that opens when an admin taps an employee marker on
the live map.

Show the same light-styled map in the upper 45% of the frame, with one
highlighted 40px #16A34A marker near the centre and a short green route tail
behind it.

Bottom sheet filling the lower 55%: white, top corners radius 24, 1px #E2E8F0
top border, 16px padding, with a 32x4px #CBD5E1 drag handle centred at the top.

Inside:
- Header row: a 48px circular #E8F3F8 avatar with "SP" in #016893 SemiBold 18px;
  to its right "Suresh Patel" Title 18px #0F172A with Caption 12px #64748B
  "DA-022 · +91 98201 44556" beneath; on the far right a #DCFCE7 pill with a
  green dot and Label 13px #15803D "On duty".
- A #F8FAFC panel, radius 12, 16px padding, with a 2x2 grid of stat blocks,
  12px gaps, each SemiBold 20px #0F172A tabular value above a Caption 12px
  #64748B label: "7h 24m / On duty since 8:04 AM", "38.6 km / Distance today",
  "3 / Visits today", "82% / Battery".
- A row of three inline meta items in Caption 12px #64748B, each with a 16px
  leading icon: a clock icon "Updated 8 sec ago", a target icon "Accuracy 6 m",
  a speed icon "42 km/h".
- A #E8F3F8 strip, radius 12, 12px padding, with a #016893 pin icon and Body
  14px #0F172A "Near Shivpuri Farm · 180 m away".
- 16px gap, then two buttons side by side, equal width, 48px tall, 12px apart:
  a filled #016893 button "View profile", and an outlined button with a 1px
  #016893 border and #016893 label "Route view".
- A full-width text button beneath, #64748B Label 13px, with a phone icon:
  "Call employee".
```

### Screen 17 — Employee list (admin)

```
SCREEN: The admin's employee list. 143 employees, searchable, filterable,
paginated.

App bar: white, 56px, 1px bottom border #E2E8F0. Title "Team" H3 20px #0F172A,
and on the right a #475569 filter icon with a #016893 badge "1".

Pinned below it:
- A 48px search field, radius 12, 1px #CBD5E1 border, 16px side margins, with a
  #94A3B8 search icon and the typed text "pat" in Body L 16px #0F172A, plus a
  #94A3B8 circular clear X on the right.
- A horizontally scrolling chip row, 32px tall: SELECTED "Active 141" in #016893
  with white text; then white 1px #CBD5E1 chips "On duty 112", "Off duty 31",
  "Blocked 2", "Has flags 3".
- A removable active-filter chip row: a #E8F3F8 pill with #016893 Label 13px
  "Active only" and a small #016893 X, next to a #016893 text link "Clear all".
- Caption 12px #64748B, left-aligned: "Showing 20 of 143".

The list. Each row is a white card, radius 12, 1px #E2E8F0 border, 16px padding,
10px apart, 80px tall:
- A 44px circular avatar with initials, filled #E8F3F8 with #016893 text.
- Name in Title 18px #0F172A, and beneath it Caption 12px #64748B
  "DA-022 · +91 98201 44556".
- A right-aligned status pill, then a #CBD5E1 chevron.

Show five rows covering every status:
1. "SP" "Suresh Patel" — #DCFCE7 pill, green dot, #15803D "On duty"
2. "AS" "Anil Sharma" — #FEE2E2 pill, red dot, #DC2626 "Check needed"
3. "PR" "Prakash Rao" — #FEF3C7 pill, amber dot, #92400E "No update"
4. "MK" "Meena Kulkarni" — #F1F5F9 pill, grey dot, #64748B "Off duty"
5. "DJ" "Dinesh Joshi" — a dimmed row with a #F8FAFC fill and a #1E293B pill
   with white Label 13px "Blocked"

A 56px circular #016893 floating action button with a white plus icon, bottom
right, 16px from the edges, with a soft shadow.

Bottom navigation with "Team" active in #016893.
```

### Screen 18 — Employee detail (admin)

```
SCREEN: An admin viewing one employee's full profile and statistics.

App bar: #016893, 170px tall, bottom corners radius 24. A white back chevron
top-left and a white three-dot overflow icon top-right. Centred: an 80px white
circular avatar with "SP" in #016893 SemiBold 28px, then "Suresh Patel" white
SemiBold 22px, then a white 15%-opacity pill with white Label 13px
"DA-022", then a #DCFCE7 pill with a green dot and #15803D Label 13px
"On duty · 7h 24m".

Body on #F8FAFC, 16px padding, overlapping the header by 24px:

1. Two equal buttons side by side, 48px, 12px apart: a filled #016893 button
   with a map icon, "Track live"; an outlined #016893 button with a history
   icon, "Route view".

2. A white card, radius 16, Overline "CONTACT", with three 56px rows separated
   by 1px #E2E8F0 dividers, each with a 20px #94A3B8 icon, a Caption 12px
   #64748B label and a Body 14px #0F172A value — "Phone / +91 98201 44556",
   "Email / suresh.p@diamondagritech.in", "Joined / 18 Feb 2026".

3. A white card with a header row: Overline "THIS MONTH" on the left and a small
   white chip with a 1px #CBD5E1 border, #475569 Label 13px "October" plus a
   chevron, on the right. Below, a 2x2 grid of stat blocks: Display 24px Bold
   #0F172A tabular values with Caption 12px #64748B labels — "12 Days worked",
   "96h 40m Hours", "578.3 km Distance", "54 Visits".
   Beneath the grid, two inline Caption 12px rows: an #F59E0B dot with
   "1 day auto-ended", and a #DC2626 dot with "0 location flags".

4. A white card titled "Recent duty" Title 18px with a "View all" #016893 link.
   Three rows, each 64px, divided by 1px #E2E8F0: the date in Body 14px
   SemiBold #0F172A on the left with Caption 12px #64748B beneath
   ("8:04 AM – 6:12 PM"), and right-aligned SemiBold 14px #0F172A
   ("8h 08m") over Caption 12px #64748B ("47.3 km").

5. A full-width 48px outlined button, 1px #DC2626 border and #DC2626 Label 13px,
   with a block icon: "Block employee".
```

### Screen 19 — Create / edit employee

```
SCREEN: The admin form for creating a new employee.

App bar: white, 56px, 1px bottom border. A #475569 X close icon on the left,
title "Add employee" H3 20px #0F172A, and a disabled #94A3B8 Label 13px text
button "Save" on the right.

Body on #F8FAFC, 16px padding. Three white cards, radius 16, 1px #E2E8F0 border,
16px padding, 16px apart. Every field has its label ABOVE it in Label 13px
#64748B, a 48px input with radius 12 and a 1px #CBD5E1 border, and Caption 12px
#94A3B8 helper text below.

Card 1 — Overline "EMPLOYEE DETAILS":
- "Full name" — filled with "Kiran Deshmukh" in Body L 16px #0F172A
- "Phone number" — filled with "+91 98220 11334", a phone icon on the left
- "Email" — filled with "kiran.d@diamondagritech.in", a mail icon on the left

Card 2 — Overline "LOGIN":
- "Employee ID" — filled with "DA-144", helper text
  "Cannot be changed later." Show a #DCFCE7 inline chip at the field's right
  edge with a green check and #15803D Caption 12px "Available".
- "Initial PIN" — filled with 6 dots, a dice/refresh icon on the right in
  #016893, helper text "The employee must change this at first login."

Card 3 — Overline "ROLE":
Two selectable tiles side by side, equal width, 72px tall, radius 12, 12px
apart. The first is SELECTED: #E8F3F8 fill, 2px #016893 border, a #016893
person icon, Label 13px #016893 SemiBold "Employee". The second is unselected:
white fill, 1px #CBD5E1 border, a #94A3B8 shield icon, Label 13px #64748B
"Admin".

Below the cards, a #E0F2FE strip, radius 12, 12px padding, with a #0284C7 info
icon and Body 14px #0F172A: "The employee will be asked to allow location
access and background tracking at first login."

Pinned at the bottom, a white bar with a 1px #E2E8F0 top border and 16px
padding, containing a full-width 48px #016893 button "Create employee".
```

### Screen 20 — Block employee sheet

```
SCREEN: The confirmation sheet for blocking an employee. This is a destructive
action with real consequences, and the design must say so.

A bottom sheet over a #0F172A 50% scrim. White, top corners radius 24, 24px
padding, with a 32x4px #CBD5E1 drag handle centred.

Inside:
- A 56px circular #FEE2E2 badge with a #DC2626 block icon, centred.
- H3 20px #0F172A centred: "Block Suresh Patel?"
- Body 14px #64748B centred: "DA-022"
- 20px gap.
- A #FEE2E2 panel, radius 12, 16px padding, titled Label 13px SemiBold #DC2626
  "This will immediately:" followed by three Body 14px #0F172A rows, each with a
  small #DC2626 dot:
  "End their current duty session"
  "Stop location tracking"
  "Prevent them from logging in"
- 16px gap.
- Label 13px #64748B "Reason (required)" above a 96px multi-line text area,
  radius 12, 1px #CBD5E1 border, with the placeholder "Why is this employee
  being blocked?" in Body L 16px #94A3B8.
- Caption 12px #94A3B8: "This reason is recorded in the audit log."
- 20px gap.
- A full-width 48px #DC2626 button with white Label 13px "Block employee",
  shown DISABLED at 40% opacity because the reason is empty.
- A full-width 48px text button beneath, #64748B Label 13px, "Cancel".
```

### Screen 21 — Notification centre

```
SCREEN: The admin in-app notification centre. There is NO push notification in
this app, so this screen is the only place alerts appear.

App bar: white, 56px, 1px bottom border. A #016893 back chevron, title
"Notifications" H3 20px with a #DC2626 badge pill containing white "7" beside
it, and a #016893 Label 13px text button "Mark all read" on the right.

A horizontally scrolling chip row, 32px tall, 16px side margins: SELECTED
"Unread 7" in #016893 with white text; then white 1px #CBD5E1 chips —
"All", "Duty", "Alerts", "Visits".

The list. Rows are 76px tall with 16px padding, separated by 1px #E2E8F0
dividers. Each has a 40px circular tinted icon badge on the left, a Body 14px
#0F172A title (SemiBold when unread), a Caption 12px #64748B subtitle, a
right-aligned Caption 12px #94A3B8 timestamp, and for unread rows an #E8F3F8
row background plus a 4px #016893 vertical bar on the left edge.

Show seven rows in this order:
1. UNREAD — #FEE2E2 badge, #DC2626 warning icon — "Location flagged as mock" /
   "Anil Sharma · DA-008" / "2:46 PM"
2. UNREAD — #FEF3C7 badge, #F59E0B signal icon — "No update for 12 minutes" /
   "Prakash Rao · DA-017" / "2:36 PM"
3. UNREAD — #DCFCE7 badge, green power icon — "Started duty" /
   "Suresh Patel · DA-022" / "2:14 PM"
4. UNREAD — #E8F3F8 badge, #016893 pin icon — "Arrived at Shivpuri Farm" /
   "Vijay Singh · DA-031" / "1:58 PM"
5. READ (white background, no bar) — #FEF3C7 badge, amber battery icon —
   "Battery below 15%" / "Meena Kulkarni · DA-045" / "1:20 PM"
6. READ — #FEE2E2 badge, #DC2626 phone icon — "Login from a new device" /
   "Dinesh Joshi · DA-052" / "11:42 AM"
7. READ — #F1F5F9 badge, #94A3B8 power-off icon — "Ended duty" /
   "Lata Bhosale · DA-009" / "11:05 AM"

Between rows 4 and 5, a sticky date separator: a #F8FAFC strip, 32px tall, with
Overline 11px uppercase #64748B "EARLIER TODAY" at 16px left padding.

Bottom navigation with "Home" active.
```

### Screen 22 — Duty history and attendance (admin)

```
SCREEN: The admin's attendance view for one employee — the screen used to
settle a payroll question.

App bar: white, 56px, 1px bottom border. A #016893 back chevron, title
"Attendance" H3 20px with Caption 12px #64748B "Suresh Patel · DA-022" beneath
it, and a #475569 download/export icon on the right.

Pinned below: a month selector row, 48px, white with a 1px bottom border
#E2E8F0 — a #016893 left chevron, "October 2026" Title 18px #0F172A centred,
and a #016893 right chevron.

A #E8F3F8 summary card, radius 16, 16px padding, 16px margins, with a 2x3 grid
of stat blocks, 12px gaps, each SemiBold 20px #016893 tabular value above a
Caption 12px #64748B label:
"12 / Days worked", "96h 40m / Total hours", "578.3 km / Distance",
"54 / Visits", "1 / Auto-ended", "0 / Flags".

A chip row, 32px tall: SELECTED "All days" in #016893; then white 1px #CBD5E1
chips "Auto-ended 1", "With flags 0", "Absent 19".

The list. One white card per day, radius 12, 1px #E2E8F0 border, 16px padding,
10px apart:
- Left: a 44px rounded-12 #F8FAFC date block with the day number in SemiBold
  18px #0F172A over the weekday in Caption 12px #64748B — "11" / "Sat".
- Middle: "8:04 AM – 6:12 PM" Body 14px #0F172A, and beneath it a Caption 12px
  #64748B row of inline stats: "8h 08m · 47.3 km · 5 visits".
- Right: a #CBD5E1 chevron.

Show five day cards:
1. "11 / Sat" — normal.
2. "10 / Fri" — "8:00 AM – 11:00 PM", "15h 00m · 96.4 km · 9 visits", with a
   #FEF3C7 chip, #92400E Label 13px, "Auto-ended".
3. "09 / Thu" — two sessions: show two "8:02 AM – 1:10 PM" and
   "2:30 PM – 6:40 PM" lines inside the same card, with a #E0F2FE chip
   "2 sessions".
4. "08 / Wed" — dimmed #F8FAFC card, date block in #94A3B8, middle text
   "No duty recorded" in Body 14px #94A3B8, no chevron.
5. "07 / Tue" — normal.
```

### Screen 23 — Route view

> **This is a static route view, not a replay.** Playback was cut from scope on 2026-10-13. The design must contain **no play or pause button, no timeline scrubber, no speed controls, and no animated position marker.** An admin opens a day and reads a picture.

```
SCREEN: Route view — one employee's whole day drawn on a map, with the totals.
A still picture of the day, NOT a video player. There must be no playback
controls of any kind anywhere on this screen.

Upper 62% of the frame: a light-styled road map showing a complete day's route
as a 4px #016893 polyline winding through roads, with:
- a 32px #16A34A circular start marker with a white flag icon
- a 32px #1E293B circular end marker with a white square icon
- five 28px #016893 circular pin markers along the route for visits
- two 24px dashed-outline #F59E0B circles marking long stops
- one 28px #DC2626 marker with a short dashed red line segment, clearly
  distinct, marking a flagged point excluded from the distance
- a thin #E8F3F8 translucent 500m circle around one visit pin, showing a geofence
- the route line should be the clear visual hero of the map: strong and
  highlighted against a deliberately quiet, desaturated basemap

Floating app bar at the top: a white card inset 16px, 48px tall, radius 12, 1px
#E2E8F0 border — a #016893 back chevron, "Route" Title 18px #0F172A with
Caption 12px #64748B "Suresh Patel · Sat, 11 Oct" beneath, and a #475569 share
icon on the right.

Directly below the app bar, a horizontally centred date selector pill: white,
36px tall, fully rounded, 1px #E2E8F0 border, containing a #016893 left chevron,
"Sat, 11 Oct" in Label 13px #0F172A, and a #016893 right chevron.

Lower 38%: a white sheet, top corners radius 24, 1px #E2E8F0 top border, 16px
padding, with a 32x4px #CBD5E1 drag handle centred at the top:
- A row of four stat blocks divided by 1px #E2E8F0 verticals, each SemiBold 20px
  #0F172A tabular over Caption 12px #64748B: "47.3 km / Distance",
  "8h 08m / Duty hours", "5 / Visits", "1 / Flag" (this last value in #DC2626).
- 16px gap.
- A row of two inline meta items in Caption 12px #64748B, each with a 16px
  leading icon: a clock icon "8:04 AM – 6:12 PM", and a pause icon
  "2 long stops".
- A #FEE2E2 strip, radius 12, 12px padding, with a #DC2626 warning icon and
  Body 14px #0F172A "1 flagged point excluded from distance" plus a #016893
  Label 13px link "View".
- A full-width 48px outlined button, 1px #016893 border and #016893 label,
  with a list icon: "View visits".

Bottom-right over the map, a vertical stack of two 48px circular white buttons
with 1px #E2E8F0 borders: a #016893 fit-to-route icon, and a #64748B layers icon.

OpenStreetMap attribution, legible, bottom-left over the map.
```

### Screen 24 — Places list

```
SCREEN: The list of geofenced places — farms, dealers, offices, warehouses.

App bar: white, 56px, 1px bottom border. Title "Places" H3 20px #0F172A, and a
#475569 filter icon on the right.

Pinned below: a 48px search field, radius 12, 1px #CBD5E1 border, 16px margins,
with a #94A3B8 search icon and placeholder "Search places" in Body L 16px
#94A3B8.

A chip row, 32px tall: SELECTED "All 38" in #016893 with white text; then white
1px #CBD5E1 chips with small leading type icons — "Farms 24", "Dealers 9",
"Offices 2", "Warehouses 3", "Inactive 4".

The list. Each row is a white card, radius 12, 1px #E2E8F0 border, 16px padding,
10px apart, 88px tall:
- A 44px rounded-12 tinted badge on the left holding a type icon.
- The place name in Title 18px #0F172A, and beneath it Caption 12px #64748B
  "500 m radius · Nashik, Maharashtra".
- A second Caption 12px line with a small #016893 dot: "14 visits this month".
- A right-aligned #CBD5E1 chevron.

Show five rows:
1. #DCFCE7 badge, green sprout icon — "Shivpuri Farm" / "500 m radius · Nashik,
   Maharashtra" / "14 visits this month"
2. #E0F2FE badge, #0284C7 shop icon — "Patel Agro Dealer" / "500 m radius ·
   Sinnar, Maharashtra" / "9 visits this month"
3. #E8F3F8 badge, #016893 building icon — "Head Office" / "200 m radius ·
   Nashik, Maharashtra" / "41 visits this month"
4. #FEF3C7 badge, #F59E0B warehouse icon — "Igatpuri Warehouse" / "800 m radius
   · Igatpuri, Maharashtra" / "6 visits this month"
5. A dimmed #F8FAFC card — #F1F5F9 badge, #94A3B8 sprout icon —
   "Old Deolali Farm", with a #F1F5F9 pill and #64748B Label 13px "Inactive",
   and "0 visits this month" in #94A3B8.

A 56px circular #016893 floating action button with a white plus icon, bottom
right.

Bottom navigation with "Places" active in #016893.
```

### Screen 25 — Create / edit place

```
SCREEN: Creating a geofenced place. The admin must be able to SEE what the 500 m
radius actually covers before saving.

Upper 55%: a light-styled STREET map of a rural Indian area — pale #F1F5F9 land,
white roads, a thin dirt track, a small cluster of building outlines, a stream
in soft #C5E1EC, sparse grey labels. NOT satellite imagery: this app has no
satellite view. Centred on it, a #016893 translucent circle at about 20% opacity
with a 2px solid #016893 outline, representing the 500 m radius. At the circle's
exact centre, a 40px #016893 teardrop pin with a white centre dot and a small
shadow beneath it. A faint second grey dashed circle at the top-right edge of
the frame, labelled with a tiny grey chip "Patel Agro Dealer — 320 m away",
showing a nearby existing geofence so overlaps are visible.

Add a subtle scale bar in the lower-left of the map area, Caption 12px #64748B,
reading "500 m" with a short rule — because without satellite imagery the admin
needs a clear sense of real-world scale when placing the pin.

A floating app bar at the top: a white card inset 16px, 48px tall, radius 12 —
a #475569 X close icon, "New place" Title 18px #0F172A, and a #016893 Label 13px
"Save" on the right.

OpenStreetMap attribution, legible, at the bottom edge of the map area.

Lower 45%: a white sheet, top corners radius 24, 1px #E2E8F0 top border, 16px
padding, scrollable:
- Label 13px #64748B "Place name" above a 48px input containing
  "Shivpuri Farm" in Body L 16px #0F172A.
- Label "Type" above a horizontally scrolling row of 5 selectable chips, 36px
  tall, fully rounded, each with a leading 16px icon: SELECTED "Farm" in #016893
  with white text; then white 1px #CBD5E1 chips "Dealer", "Office",
  "Warehouse", "Other".
- Label "Radius" with the current value right-aligned in SemiBold 14px #016893
  "500 m". Beneath it a slider: a 6px #E2E8F0 track, radius 999, filled to
  about 30% in #016893, with a 24px #016893 circular thumb with a white centre.
  End labels in Caption 12px #94A3B8: "50 m" left, "2000 m" right.
- A #E0F2FE strip, radius 12, 12px padding, with a #0284C7 info icon and Body
  14px #0F172A: "Employees are asked for a photo when they enter this circle."
- Label "Coordinates" above a 48px read-only input with a #F8FAFC fill and
  #E2E8F0 border, containing "19.99753, 73.78981" in Body 14px #64748B with a
  #016893 copy icon on the right.
- An "Active" row, 56px: Body 14px #0F172A "Active" on the left with Caption
  12px #64748B "Raise events when employees arrive" beneath, and on the right
  a toggle switch in the ON state, #016893 track with a white knob.
```

### Screen 26 — Reports

```
SCREEN: Report builder and export. Generate this as one frame split into TWO
side-by-side panels, each 390x844, labelled at the top: "A — Build" and
"B — Ready".

PANEL A — Build
App bar: white, 56px, 1px bottom border, title "Reports" H3 20px.
Body on #F8FAFC, 16px padding:
- Overline 11px uppercase #64748B "REPORT TYPE". A 2x2 grid of selectable tiles,
  12px gaps, each 80px tall, radius 12. The first is SELECTED: #E8F3F8 fill,
  2px #016893 border, a #016893 24px icon, Label 13px SemiBold #016893
  "Daily detail". The other three are white with 1px #CBD5E1 borders, #94A3B8
  icons and #64748B labels: "Employee summary", "Team summary", "Visit log".
- Overline "DATE RANGE". A row of 4 chips, 32px tall: SELECTED "This month" in
  #016893; white 1px #CBD5E1 chips "Today", "Last 7 days", "Custom".
  Beneath, a 48px read-only field with a #F8FAFC fill and a calendar icon,
  containing "01 Oct 2026 – 12 Oct 2026" in Body 14px #0F172A.
- Overline "EMPLOYEES". A 48px field, radius 12, 1px #CBD5E1 border, containing
  Body L 16px #0F172A "All employees (143)" with a #94A3B8 chevron. Below it two
  #E8F3F8 removable pills with #016893 Label 13px text and small X icons:
  "Suresh Patel", "Anil Sharma".
- Overline "FORMAT". Two tiles side by side, 64px tall, 12px apart: SELECTED
  #E8F3F8 with 2px #016893 border, a #016893 PDF icon, Label 13px #016893
  "PDF"; and white with 1px #CBD5E1, a #94A3B8 spreadsheet icon, #64748B
  "Excel".
- A #E0F2FE strip, radius 12, with a #0284C7 info icon and Body 14px:
  "Reports are generated in English."
- Pinned bottom bar, white with a 1px top border, 16px padding, holding a
  full-width 48px #016893 button "Generate report".

PANEL B — Ready
The same app bar. Centred in the body:
- A 72px circular #DCFCE7 badge with a green #16A34A check icon.
- H3 20px #0F172A centred "Report ready"
- Body 14px #64748B centred "Daily detail · 01–12 Oct 2026 · 143 employees"
- A white card, radius 12, 1px #E2E8F0 border, 16px padding, containing a row
  with a 40px rounded-8 #FEE2E2 badge holding a #DC2626 PDF icon, then
  "attendance-oct-2026.pdf" Body 14px SemiBold #0F172A with Caption 12px
  #64748B "2.4 MB · 1,716 rows" beneath.
- A full-width 48px #016893 button with a share icon, "Share".
- A full-width 48px outlined #016893 button with a download icon, "Save to device".
- Caption 12px #94A3B8 centred: "This export has been recorded in the audit log."
Above all of this, show a thin progress strip at the top of the panel: a 4px
#E2E8F0 track fully filled in #16A34A, with Caption 12px #64748B beneath it
reading "Completed in 14s".
```

---

## 5. Shared patterns

These four are not screens but reusable sheets. Generate them once; they apply everywhere.

### Screen 27 — Filter bottom sheet

```
SCREEN: The reusable filter bottom sheet, shown here for the employee list.

A bottom sheet covering about 75% of the frame, over a #0F172A 40% scrim.
White, top corners radius 24, 16px padding, with a 32x4px #CBD5E1 drag handle.

- Header row: "Filters" H3 20px #0F172A on the left, and a #016893 Label 13px
  text button "Clear all" on the right.
- 1px #E2E8F0 divider.
- Section: Overline 11px uppercase #64748B "STATUS". A wrapped row of 5
  selectable chips, 36px tall, fully rounded, 8px gaps, each with a leading 8px
  status dot and a count. "On duty 112" and "Check needed 3" are SELECTED:
  #E8F3F8 fill, 2px #016893 border, #016893 Label 13px SemiBold, with a small
  #016893 check icon. The rest are white with 1px #CBD5E1 borders and #64748B
  labels: "Off duty 31", "Stale 4", "Blocked 2".
- Section: Overline "DUTY TODAY". Three chips in the same style, with
  "Worked today" SELECTED: "Worked today", "Not started", "Auto-ended".
- Section: Overline "DATE RANGE". Four chips: "Today" SELECTED, then
  "Yesterday", "Last 7 days", "This month". Beneath them a 48px read-only field
  with a #F8FAFC fill, a calendar icon and "12 Oct 2026" in Body 14px.
- Section: Overline "SORT BY". Four full-width 48px radio rows, each with a 20px
  radio control on the left and Body 14px #0F172A: "Name (A–Z)" SELECTED with a
  filled #016893 radio; then "Employee ID", "Last active", "Distance today"
  with empty #CBD5E1 radios.
- Pinned bottom bar, white with a 1px #E2E8F0 top border, 16px padding, holding
  two buttons side by side, equal width, 48px, 12px apart: an outlined button
  with a 1px #CBD5E1 border and #475569 label "Reset"; and a filled #016893
  button with the white label "Show 115 results".
```

### Screen 28 — Empty states

```
SCREEN: A reference sheet of empty states. Lay out SIX cards in a 2x3 grid on a
#F8FAFC background, each card 170x240px, white, radius 16, 1px #E2E8F0 border,
with 16px gaps and a small Overline 11px uppercase #94A3B8 caption above each
card naming the case.

Every card contains, centred and stacked: a 56px simple flat line illustration
in #CBD5E1 with a single #016893 accent, then a Title 16px SemiBold #0F172A
headline, then a Caption 12px #64748B line of up to two lines, and where listed,
a 36px pill button.

1. "NO EMPLOYEES" — illustration: people outline.
   "No employees yet" / "Add your first team member."
   Button: #016893 fill, white label "Add employee".
2. "NOBODY ON DUTY" — illustration: a map pin with a dashed circle.
   "No one is on duty" / "Nobody has started duty today."
   Button: outlined #016893, label "View team".
3. "NO NOTIFICATIONS" — illustration: a bell with a small check.
   "You're all caught up" / "New alerts will appear here."
   No button.
4. "FILTERED TO NOTHING" — illustration: a funnel with a slash.
   "No results for these filters" / "Try removing one or more filters."
   Button: outlined #016893, label "Clear filters".
5. "NO ROUTE" — illustration: a dotted path with a question mark.
   "No location recorded" / "This employee did not go on duty on 08 Oct."
   Button: outlined #016893, label "Pick another date".
6. "ROUTE EXPIRED" — illustration: a calendar with a clock.
   "Route older than 30 days" / "Detailed routes are kept for 30 days. Totals
   are still available."
   Button: outlined #016893, label "View summary".
```

### Screen 29 — Error and offline states

```
SCREEN: A reference sheet of error and connectivity states, on a #F8FAFC
background, laid out as a single 390px wide column with each item labelled above
it in Overline 11px uppercase #94A3B8.

1. "OFFLINE BANNER (INFO, NOT AN ERROR)" — a full-width #E0F2FE strip, radius
   12, 12px padding, with a #0284C7 cloud-off icon, Body 14px #0F172A SemiBold
   "No internet connection" and Caption 12px #64748B beneath: "Your work is
   saved and will sync automatically." No retry button — this is reassurance,
   not a failure.

2. "SYNC PENDING" — a #FEF3C7 strip, radius 12, with an #F59E0B upload icon,
   Body 14px "18 points waiting to sync", and a right-aligned #016893 Label 13px
   link "Details".

3. "GPS OFF (BLOCKING)" — a #FEE2E2 strip, radius 12, with a #DC2626
   location-off icon, Body 14px SemiBold "Location is turned off", Caption 12px
   #64748B "Turn on location to start duty.", and a 36px #DC2626 pill button
   with a white label "Open settings".

4. "INLINE FIELD ERROR" — a 48px input with a 1.5px #DC2626 border containing
   "DA-022" in Body L 16px, with a #DC2626 alert icon inside on the right, and
   beneath it Caption 12px #DC2626 "This employee ID is already in use."

5. "FULL-SCREEN LOAD FAILURE" — a 300px tall white card, radius 16, 1px #E2E8F0
   border, with everything centred: a 64px circular #FEE2E2 badge holding a
   #DC2626 cloud-off icon, Title 18px #0F172A "Couldn't load this", Caption 12px
   #64748B "Check your connection and try again.", a 44px #016893 pill button
   with a refresh icon and the white label "Retry", and a text button beneath in
   #64748B Label 13px "Go back".

6. "REALTIME DISCONNECTED" — a thin 32px full-width #FEF3C7 strip with a small
   spinning #F59E0B icon and Caption 12px #92400E centred: "Reconnecting…".

7. "SNACKBAR" — a floating dark #1E293B bar, radius 12, 56px tall, 16px padding,
   with a white Body 14px message "Employee blocked" on the left and a #4AA5C6
   Label 13px "UNDO" action on the right.
```

### Screen 30 — Skeleton loaders

```
SCREEN: A reference sheet of skeleton loading states. #F8FAFC background,
390px wide column, each block labelled above it in Overline 11px uppercase
#94A3B8.

Every skeleton shape uses a #F1F5F9 base with a soft diagonal #CBD5E1 shimmer
highlight sweeping across it from the lower left to the upper right. Shapes
match the exact geometry of the real content they replace. Text lines are
rounded bars at the real line height, and the final line of any text group is
about 60% width.

1. "EMPLOYEE LIST" — five white cards, radius 12, 1px #E2E8F0 border, 80px tall,
   10px apart. In each: a 44px circle on the left, then two stacked bars (a 140px
   wide 18px tall bar, and a 90px wide 12px tall bar beneath), and on the right a
   72x24px fully rounded pill shape.

2. "STAT CARD ROW" — three equal white cards, radius 12, 16px padding, 12px
   apart. Each contains a 48x11px bar, a 72x32px bar beneath it, and a 28x12px
   bar below that.

3. "NOTIFICATION LIST" — four rows, 76px tall, divided by 1px #E2E8F0. Each: a
   40px circle, then a 180x14px bar and a 120x12px bar, with a 36x12px bar
   right-aligned.

4. "DUTY HISTORY" — three white cards, radius 12, 88px tall. Each: a 44x44px
   rounded-12 square on the left, then a 150x18px bar and a 200x12px bar.

5. "MAP PLACEHOLDER" — a 180px tall rounded-16 block in #E8F3F8 with a faint
   #C5E1EC grid pattern, a centred 32px #94A3B8 map-pin outline icon and
   Caption 12px #94A3B8 beneath it: "Loading map…". NOTE: a map never gets a
   shimmer skeleton — it gets this branded placeholder instead.

6. "NEXT-PAGE LOADER" — a 56px tall centred row containing only a 24px #016893
   circular spinner. NOTE: pagination uses a small spinner, never a skeleton,
   so the list never jumps.
```

---

## 6. Review checklist for every generated design

Reject and regenerate if any of these fail. A generated design that breaks the system is worse than no design, because it will quietly get built.

- [ ] Light mode. No dark variant.
- [ ] DM Sans only. No substituted typeface.
- [ ] `#016893` is the only brand colour. No off-brand blue, purple, or teal.
- [ ] Every colour appears in the token list. No invented greys or accents.
- [ ] Screen padding is 16px and nothing is clipped at the edges.
- [ ] Buttons are 48px tall with a 12px radius. List rows are at least 72px.
- [ ] **Every status shows colour plus a text label.** No colour-only status.
- [ ] Input labels sit above the fields, not inside them.
- [ ] Numbers are tabular and aligned. Times are 12-hour with AM/PM.
- [ ] Realistic Indian sample data. No lorem ipsum, no "John Doe".
- [ ] No gradient, glassmorphism, neon, 3D, or stacked drop shadows.
- [ ] English only.
- [ ] It looks like a real app screenshot, not a dribbble concept.

### Then hand it over

Save as `designs/<number>-<name>.png`, then tell me which numbers are ready. I will cross-check each one against [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md) and raise any conflict **before** building, rather than silently following the image.
