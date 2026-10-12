# 10 — Cloudinary Best Practices

Visit photos are hosted on **Cloudinary**, not Supabase Storage. This document covers how, and the two settings that must not be got wrong.

**Cloudinary's docs and plan limits change. Verify against the current official docs before implementing.** Do not rely on remembered API names or credit figures.

---

## 0. Why Cloudinary is here

Chosen as part of a deliberate stay-free strategy. Supabase Free allows only 1 GB of file storage, and this app generates roughly 1.1 GB of photos per month at 50 employees — the entire allowance in month one, with no way to reclaim it, because visit photos are the proof that a visit happened.

The secondary benefit is real: **on-the-fly derivatives.** The admin's visit list loads a small thumbnail instead of a full 200 KB photo, which protects both the bandwidth budget and the admin's patience.

**If the project ever moves to Supabase Pro, Cloudinary becomes redundant** — Pro includes 100 GB of file storage and image transformations. Revisit this choice at that point rather than carrying two vendors out of habit.

---

## 1. The two mandatory settings

Neither is Cloudinary's default. Getting either wrong fails **silently** — nothing errors, and the data is simply exposed.

### 1.1 Delivery type must be `authenticated`

| Type | Original | Derivatives (thumbnails) |
|---|---|---|
| `upload` (**the default**) | **Public** | **Public** |
| `private` | Signature required | **Public** — not acceptable |
| **`authenticated`** | Signature required | **Signature required** |

`private` is a trap for this project specifically: it protects the original but leaves derived versions publicly accessible, and derivatives are exactly what the thumbnails are. A thumbnail of an employee's location is the same privacy breach as the full photo.

**Delivery type is set at upload time via the `type` parameter**, not only in the dashboard preset. Cloudinary's documentation is explicit that delivery types must be set at upload using `type`.

**So the Edge Function sets `type: 'authenticated'` on every signed upload.** This is deliberately better than relying on a preset checkbox: it lives in code that can be read, reviewed and tested, rather than in a dashboard setting that someone could change later with nothing to flag it. If the preset also exposes a Delivery type field, set it there too as defence in depth — but the Edge Function is the control that matters.

Converting already-uploaded public assets to `authenticated` changes their URLs, so getting this right before the first real photo is far cheaper than fixing it afterwards.

### If `authenticated` turns out to be unavailable on the Free plan

Unconfirmed as of 2026-10-13 — this is PRD **Q9**, and it must be settled by an **empirical test**, not by reading a pricing page: upload one asset with `type: 'authenticated'`, then try to open it while signed out. If it opens, the control is not working.

Documented fallback: **`private` delivery combined with the account-level "Strict transformations" setting.** Cloudinary's docs pair exactly these two to prevent unauthorised creation of derived assets. Strict transformations closes the derivative hole that makes plain `private` unsafe for this project, because transformations can then only be produced through signed URLs or eager transformations.

Note that **token-based authentication and environment-level ACLs are premium features.** Our design uses signature-based signed URLs, which is a different and more widely available mechanism — but this is part of what Q9 must confirm.

### Account-level setting: enable Strict transformations

Worth enabling regardless of which delivery type is used. It stops anyone from generating arbitrary derived assets against the account, which is both a privacy control and a **credit-burn control** — an open account can have its transformation quota consumed by a stranger.

**Enable it before building the URL-generation code**, so that code is written against the stricter rules from the start rather than retrofitted.

### 1.2 Uploads must be signed

An **unsigned** upload needs only the cloud name and the upload preset name. Both are trivially recoverable from a decompiled APK, and the app is public by definition. Anyone could then upload anything into the company's account — filling the storage quota, or worse, hosting illegal content under the company's name.

The correct flow:

```
App                     Supabase Edge Function            Cloudinary
 |                              |                              |
 |-- request signature -------->|                              |
 |   (authenticated user)       |                              |
 |                              |  signs params with the       |
 |                              |  API SECRET, server-side     |
 |<-- signature + timestamp ----|                              |
 |                                                             |
 |-- upload photo + signature -------------------------------->|
 |<-- public_id, version --------------------------------------|
 |                                                             |
 |-- save public_id to Postgres (via Edge Function) ---------->|
```

### 1.3 Key handling

| Credential | Where it lives | Ships in the app? |
|---|---|---|
| Cloud name | Build-time config | Yes — it is not a secret |
| Upload preset name | Build-time config | Yes — harmless once uploads are signed |
| **API key** | Edge Function secret | **No** |
| **API secret** | Edge Function secret | **Never. Not once, not for testing.** |

The API secret in the app would make every other control here pointless. See [05-SECURITY.md](05-SECURITY.md).

---

## 2. The credits model

Free is **25 credits per month**, and credits are **summed across three resource types**. It is not "25 GB of storage".

| Resource | 1 credit buys |
|---|---|
| Storage | 1 GB stored |
| Image bandwidth | 1 GB delivered |
| Transformations | 1,000 transformations |

### Why this matters here

**Storage is a running snapshot, not a monthly allowance.** It accumulates every month and never resets. Photos cannot be deleted without destroying visit proof, so storage grows monotonically.

| Month | Stored | Bandwidth + transforms | Credits used |
|---|---|---|---|
| 6 | ~7 GB | ~6 | ~13 of 25 |
| 12 | ~13 GB | ~8 | ~21 of 25 |
| 18 | ~20 GB | ~8 | **~28 — over the limit** |

**Expect roughly 12–18 months on the free plan.** That is not a failure; it is the known horizon of this decision. The monitored trigger is 20 of 25 credits — see section 7 of [01-PRD.md](01-PRD.md).

### Keeping credits down

- **Compress on the device** before upload: longest edge 1280 px, target about 200 KB. The single biggest lever on storage.
- **Serve thumbnails, not originals**, everywhere except the full-screen photo view. A 40 px list thumbnail costs a fraction of the bandwidth.
- **Use a small, fixed set of named transformations.** Each distinct transformation is generated once and then cached; arbitrary per-request sizes multiply the transformation count for no benefit.
- Deliver modern formats and automatic quality where available, so bytes drop without visible quality loss.
- **Do not use Cloudinary as a general CDN** for app assets. Icons and illustrations ship inside the app.

---

## 3. Upload pipeline

- Uploads go through the **offline queue**, exactly like GPS points. A visit photographed with no signal uploads later, and the queue survives app restart and force-kill. See [08-FLUTTER-SUPABASE-BEST-PRACTICES.md](08-FLUTTER-SUPABASE-BEST-PRACTICES.md).
- **Make uploads idempotent.** The queue retries, and a timeout does not mean the upload failed. Derive a deterministic `public_id` from the visit's client-generated id, so a retry overwrites rather than creating a second photo and double-counting storage.
- **Postgres is the source of truth for whether a visit exists.** The photo is an attachment to the visit row, never the other way round. A visit whose photo upload failed is still a valid visit, flagged as pending.
- Save the `public_id` through an Edge Function rather than a direct client write, so the row and the signature logic stay on one trusted path.
- Validate before upload: content type is an image, size is within a hard cap, dimensions are sane.
- Strip EXIF on the device, except the coordinates deliberately recorded on the `visits` row. **Never treat EXIF as the source of location truth** — it is trivially editable.
- **Camera capture only.** The gallery must be unreachable from the visit flow, or a photo from last month can be submitted as today's proof.

---

## 4. Delivery and display

- Every photo URL is **signed and short-lived**, generated server-side on request. A URL that does not expire is a permanent public link to an employee's location.
- Generate signed URLs in the Edge Function, in batches for a list view rather than one round trip per row.
- The admin visit list requests a small square derivative. Only the full-screen view requests a larger one.
- Cache derivatives on the device, so scrolling a list twice does not pay for the bandwidth twice.
- Handle a failed image load without breaking the layout: show a placeholder and a retry, per [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md).
- **Never embed a signed URL in an exported PDF or Excel report.** It would expire, and before expiring it would be a live link to employee location data sitting in a file that has left the company. Reports record that a photo exists; they do not carry it.

---

## 5. Two systems, one dataset

Splitting photos from their rows creates obligations a single-vendor setup would not have. Each of these is a real task, not a note.

| Obligation | Why |
|---|---|
| **Deletion must span both systems.** | When an employee leaves, or when photo retention expires, rows go from Postgres and assets go from Cloudinary. A delete that clears only one side leaves either orphaned photos accruing cost, or rows pointing at nothing. |
| **Cloudinary is covered by no Supabase backup.** | And Supabase Free has no reliable backup regardless. The weekly attendance export required by the PRD covers the records that matter most; photos are the accepted less-recoverable half. |
| **Reconciliation.** | A scheduled job should find `visits` rows whose asset is missing, and Cloudinary assets with no matching row. Both kinds of drift happen in practice, from failed uploads and partial deletes. |
| **Two credential sets to rotate.** | Document the rotation procedure for both before launch, not during an incident. |

---

## 6. Traps

| Trap | Consequence | Avoidance |
|---|---|---|
| Default `upload` delivery type | **Every employee photo is publicly readable** | Edge Function sets `type: 'authenticated'` on every upload |
| Assuming the preset alone sets delivery type | Silently public assets | Delivery type is set at upload via the `type` parameter |
| Using plain `private` instead of `authenticated` | Thumbnails stay public, so the breach remains | `authenticated`, or `private` **plus** strict transformations |
| Unsigned upload preset | Anyone can fill the account from a decompiled APK | Signed uploads via an Edge Function |
| API secret in the app | Total account compromise | Server-side only, never in the client |
| Non-deterministic `public_id` on retry | Duplicate photos, double storage cost | Derive it from the visit's client id |
| Arbitrary per-request transformation sizes | Transformation credits burn fast | A small fixed set of named derivatives |
| Serving originals in list views | Bandwidth credits burn fast | Thumbnails everywhere but full-screen |
| Signed URL embedded in an export | A live link to employee location leaves the company, then breaks | Reports never carry photos |
| Deleting rows without deleting assets | Orphaned photos, growing cost, privacy exposure | One deletion path covering both systems |
| Assuming storage resets monthly | The credit limit arrives unexpectedly | Storage is cumulative; monitor it |

---

## 7. Pre-launch checklist

- [ ] Delivery type is `authenticated`, set on the upload preset
- [ ] **A photo URL opened while signed out is refused.** Attempted and verified.
- [ ] **A thumbnail URL opened while signed out is refused.** Attempted and verified — this is the `private` trap.
- [ ] Upload preset is signed; an unsigned upload attempt is rejected. Attempted and verified.
- [ ] API secret is absent from the app, from git history, and from any log
- [ ] Device-side compression confirmed at roughly 200 KB on a real photo
- [ ] Retry of a queued upload produces one asset, not two
- [ ] Deletion path removes both the Postgres row and the Cloudinary asset
- [ ] Credit usage checked, and the 20-of-25 trigger has a named owner
- [ ] Rotation procedure documented for the Cloudinary key and secret
