# 07 — MapLibre Best Practices

Rules for every map surface: the employee's own map, the admin live map, the route view, and the place picker.

**Stack: MapLibre (renderer) + OpenFreeMap (tiles).** No account, no API key, no usage limits, and **no terms restricting what the maps are used for.**

**Verify package APIs against current docs before implementing.** The Flutter plugin is less mature than a commercial SDK and its API changes; do not rely on remembered names.

---

## 0. Why this stack, and what it cost us

### The decision

Mapbox was the original choice. Research on 2026-10-13 found an archived 2018 copy of their Terms of Service barring customers from using the service to *"track moving physical assets (e.g., personnel or vehicles) on a map"* except on a Commercial or Premium plan — which describes this product exactly. The clause was not found in the current terms, and Mapbox never confirmed either way.

Rather than build on an unresolved legal question, the project switched to **MapLibre**, a BSD-licensed open-source renderer with **no use-case restrictions of any kind**, and **OpenFreeMap** for tiles, which permits commercial use with no key and no request limits.

**This removes an entire category of risk permanently.** No vendor can later decide that tracking your own employees requires a different plan.

### What it cost

| Lost | Impact |
|---|---|
| **Satellite imagery** | OpenFreeMap is street maps only. Affects the place picker (design screen 25). **Owner confirmed street map is acceptable.** |
| SDK polish | The Flutter plugin is community-maintained and less mature than Mapbox's |
| Vendor support | There is none. The community is the support. |

### What it did not cost

The dot, the route line, the kilometres, the hours, clustering, and the live map all work the same. **Location data lives in our own database** — the map provider only draws a backdrop beneath it.

### The known risks, and how they are handled

| Risk | Handling |
|---|---|
| **OpenFreeMap has no SLA.** It is run by one person, funded by donations. | They publish weekly map downloads. **If it ever disappears, we self-host the same tiles.** Documented as the fallback below, not discovered in a crisis. |
| **Plugin maturity.** `maplibre_gl` was at v0.26.1 (May 2026), roughly 58K monthly downloads, health 71/100, maturity 5/15, 67 open issues. | The Phase 2 spike below. |
| **Clustering is unverified.** No clustering API was found documented in the plugin. MapLibre performs clustering at the *source* level in the style spec (`cluster: true` on a GeoJSON source) rather than through a dedicated API, so it likely works if the plugin exposes GeoJSON sources — **but "likely" is not good enough for 150 markers.** | The spike. This is its single most important test. |

### Mandatory spike, early in Phase 2

Roughly half a day. **Do this before any map screen is built on this stack.**

- [ ] A map renders using OpenFreeMap tiles on a real Android device
- [ ] **150 markers cluster correctly** and the clusters expand on zoom
- [ ] Panning and zooming hold a usable frame rate **on a budget phone**, not a flagship
- [ ] A line layer draws a 3,000-point route after simplification
- [ ] A circle can be drawn in real ground metres, for the 500 m geofence preview
- [ ] Attribution renders correctly

**If clustering fails, stop and report before continuing.** The admin live map depends on it, and the alternative would be a product change, not a workaround.

---

## 1. Configuration

- **No API key, no access token, no account.** `env.json` carries no map credential at all — one less secret to manage, rotate, or leak.
- The tile style URL is build-time configuration, not hardcoded, so the tile source can be changed without touching screen code.
- **Attribution is mandatory.** OpenStreetMap data requires credit. Render it legibly on every map surface. Removing it breaks the licence this stack depends on.

---

## 2. Styling to the brand

- One map style across the whole app, so the admin and employee maps feel like one product.
- **Light style only.** The app has no dark mode, so no dark map style is built, styled or tested.
- Keep the base map **quiet.** It is a backdrop for markers and routes, not the subject. Reduce competing colour and detail so the status colours from [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md) dominate.
- Brand accents may use `#016893`, but **never use the brand colour for a status marker.** Status colours are reserved and must not be confusable with brand chrome.
- MapLibre styles are JSON and fully editable, so the base map can be tuned to the palette rather than accepted as shipped. This is an advantage over a locked vendor style — use it, but keep the result quiet.

---

## 3. Markers and the 150-employee problem

The admin live map is the hardest surface in this app.

- **Cluster beyond about 50 visible markers.** 150 individual markers will not stay smooth on a budget phone.
- Clustering is configured on the **GeoJSON source** (`cluster: true`, with a cluster radius), not through a per-marker API. See the spike above.
- A cluster shows the count and takes the colour of the **most severe status inside it**, in the order blocked, suspect, stale, active, off-duty. An admin must never miss a red employee hidden inside a green cluster.
- Markers are drawn as **symbols on a styled layer**, not as 150 Flutter widgets positioned over the map. Widget markers are the standard performance mistake here and will not survive 150 live-updating points.
- Marker design per the design system: 32 dp circle, status colour, white border, status icon, initials. **Status is colour plus shape or icon**, never colour alone.
- Tapping a marker opens the detail sheet. Tapping a cluster zooms in.

### Live updates
- **Update the source data; do not recreate the layer.** Rebuilding the whole source on every Realtime message will drop frames.
- **Debounce and batch.** Collect incoming updates and apply them on a short interval rather than once per message.
- Animate a position change over a short duration so movement reads as movement rather than teleporting. Keep it cheap.
- **Never move the camera because data arrived.** The admin's camera belongs to the admin; it moves only on an explicit action.

---

## 4. Route view

**This is a static route view, not a replay.** The playback controls were deliberately cut: no play or pause button, no timeline scrubber, no speed control, no marker animating along the path. An admin opens a day and sees a picture, not a video.

What it shows:
- The route drawn as a highlighted line
- **Total kilometres**
- **Total hours on duty**
- **Current location**, when viewing today
- Start and end markers, visit pins, and geofence entry points

Rules:
- **Simplify the line before drawing it.** A 3,000-point day handed raw to the renderer will stall. Simplify for display only; the stored data is never altered.
- **Distance is always calculated server-side from the full point set**, never from the simplified line.
- Points flagged as mock or outlier are drawn distinctly and excluded from the drawn path, so an impossible jump never appears as real travel.
- Draw the route as a **line layer**, with start, end, visit and geofence markers as symbol layers.
- Fit the camera to the route's bounds on load, with padding, so the whole day is visible immediately.
- A day with no points shows the empty state from the design system, not a blank map.
- **Available for any day within the 30-day point-retention window.** Older dates show the "detailed route is kept for 30 days" empty state while still showing hours, km and visits from `daily_summaries`.

---

## 5. The place picker and geofences

- Draw the 500 m radius as a **filled circle with a visible outline**, so an admin can see what the geofence actually covers before saving. A radius typed into a field is abstract; a circle on a map is not.
- **Draw the circle in real ground metres.** A fixed pixel radius is wrong at every zoom but one.
- Let the admin drag the centre pin and watch the circle follow.
- Show nearby existing places while picking, so **overlapping geofences are visible before they are created.** Two overlapping 500 m circles produce confusing enter and exit events.
- **No satellite view on this stack.** Compensate by showing the coordinates numerically alongside the map and by making the radius circle clear, so a pin can be verified without imagery.

---

## 6. Performance

- **One map instance per screen, disposed properly.** A leaked map controller is a large memory leak.
- Dispose the controller, listeners and annotation managers in `dispose()`. Leaks here cause crashes after a few navigations.
- Do not rebuild the map widget when unrelated state changes. Keep map state out of widely-rebuilding providers.
- Set a sensible zoom range so users cannot zoom out to the whole planet and pull a large number of tiles.
- Avoid a map inside a scrolling list. Gesture conflicts are unavoidable and the memory cost is high.
- **Measure frame rate while panning, on a budget phone.** A flagship hides every problem the real users will hit.

---

## 7. Offline and failure behaviour

- MapLibre **caches tiles it has already fetched**, so recently visited areas keep working with no signal.
- **Never make the map a hard dependency of a core action.** Duty must start, GPS must record, and a visit photo must be captured even if no tile ever loads. The map is a view, not a requirement.
- With no network and no cache, show a branded placeholder reading "map unavailable offline" — and keep the data visible as a list or as coordinates.
- Handle tile errors without crashing. A failed tile is not a failed screen.
- Data use matters to employees on limited plans. Mention tile caching in onboarding.

### If OpenFreeMap becomes unavailable

Not hypothetical planning — a single-maintainer, donation-funded service deserves a written fallback.

| Option | Note |
|---|---|
| **Self-host OpenFreeMap's published extract** | They publish weekly downloads. Extract the operating region and serve it. No vendor, no key, no limits. **The primary fallback.** |
| Protomaps PMTiles | A single static file served over HTTP range requests. **Commercial terms conflicted between sources — confirm before relying on it.** |
| A commercial tile host | MapTiler and Stadia free tiers **exclude commercial use.** Paid tiers only. Check each one's terms; this is the same trap that moved us off Mapbox. |
| OpenStreetMap's public tile server | **Not an option.** Its usage policy forbids production use of this kind. |

Because MapLibre reads standard style JSON, switching tile source is a configuration change, not a rewrite — provided the style URL stayed in configuration, as section 1 requires.

---

## 8. Battery

- **Never use the map SDK's own location-tracking mode as the source of recorded location.** Tracking is owned by the background service, which runs whether or not a map is on screen. The map only *displays* the position the service already holds.
- The employee map reads from the same local store the tracking service writes to — one source of truth, one GPS consumer.
- Keep rendering paused when the map is not visible.
- **Closing the map screen must never stop tracking.** Verify explicitly; it is an easy and severe regression.

---

## 9. Accessibility and clarity

- Status must be readable without colour: icon or shape, plus the text label.
- Map controls meet the 48 dp touch target minimum.
- Provide the **list-view alternative** to the admin live map. Some admins prefer it, and a list is navigable by screen reader in a way a map is not.
- Label every map control for screen readers.
- Keep text legible against the map using a halo or a plate behind labels.

---

## 10. Traps

| Trap | Consequence | Avoidance |
|---|---|---|
| 150 widget markers over the map | Unusable frame rate | Symbol layer plus source-level clustering |
| Recreating the source on each update | Dropped frames, flicker | Update the data in place |
| Drawing 3,000 raw route points | The map stalls | Simplify for display only |
| Calculating distance from the drawn line | Understated km | Server-side, from the full point set |
| Moving the camera on data arrival | The admin loses their place | Camera moves only on user action |
| Map SDK location mode as the tracking source | Two GPS consumers, battery drain | The background service owns location |
| Closing the map stops tracking | **Silent data loss** | Verify explicitly, every release |
| Leaked map controller | Crash after several navigations | Dispose everything |
| Fixed-pixel geofence circle | Wrong radius at every zoom | Draw in ground metres |
| Hardcoding the tile style URL | A tile-source change becomes a code change | Keep it in configuration |
| Dropping attribution | Breaks the OpenStreetMap licence | Render it on every map |
| Assuming clustering works | The admin map fails at 150 employees, late | **Prove it in the Phase 2 spike** |
