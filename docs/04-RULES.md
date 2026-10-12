# 04 — Working Rules (binding)

These rules govern how work is done on this project. They override convenience, speed, and personal preference.
If a rule and a request conflict, stop and say so rather than silently picking one.

---

## Rule 0 — The documents are the source of truth

- Read [CLAUDE.md](../CLAUDE.md) and the relevant numbered doc **before** starting any task.
- Never contradict a locked decision in CLAUDE.md. If something needs to change, raise it and get approval, then update the doc in the same change.
- If code and docs disagree, that is a defect. **Stop and report it.** Do not quietly follow whichever one is convenient.
- When a change makes a doc out of date, update the doc as part of that change. A change that leaves docs stale is incomplete.

---

## Rule 1 — Ask permission for every step

- Work in one reviewable step at a time. State what the step is, what it touches, and what could break.
- **Wait for approval. Do not chain steps together.** Approval for step 3 is not approval for step 4.
- Approval for one thing never implies approval for a similar thing later.
- Always ask before: creating or deleting anything in Supabase, running a migration, changing RLS, adding a dependency, changing anything that costs money, renaming or deleting files, or any `git push`.
- If a step turns out to be bigger than described, stop and re-ask instead of pushing on.

---

## Rule 2 — Propose an enterprise-grade solution before coding

For every new function, before writing any code, present:

1. **The requirement**, restated in your own words, so a misread surfaces now rather than later.
2. **The chosen approach, plus at least one rejected alternative and why** it was rejected.
3. **Database impact** — tables, columns, indexes, RLS policies, migrations, and whether the change is backward compatible.
4. **Failure modes** — no internet, GPS off, app killed, battery saver, permission revoked, duplicate submit, clock skew, concurrent writes, empty and very large result sets.
5. **Security impact** — who can read this, who can write it, what a hostile employee could do with it. Cross-reference [05-SECURITY.md](05-SECURITY.md).
6. **Performance and cost at 150 employees** — rows per day, query cost, bandwidth, storage, map loads.
7. **How it will be verified**, with the exact checks to be run afterwards.

"Enterprise grade" here means: handles failure explicitly, is secure by default, is observable, scales to the stated load, and a different developer can understand it in six months.

**No code until this proposal is approved.**

---

## Rule 3 — Never assume. Cross-check everything.

Assumption is the main source of defects on this project. Before relying on any fact:

### Cross-check against the database
- List the actual tables and columns before writing a query. Do not trust memory or an older doc.
- Confirm exact column names, types, nullability, and defaults.
- Confirm the RLS policies that apply to the role doing the work, and confirm whether the table is exposed to the Data API.
- Verify every foreign key and constraint a write depends on.
- After a schema change, re-read the schema from the database to confirm what actually landed.

### Cross-check against existing code
- Search the codebase before adding anything. If a helper, model, widget, or query already exists, reuse or extend it. Do not create a second version.
- Check every call site before changing a shared function's behaviour or signature.
- Match the file layout, naming, and state-management patterns already in use.
- Confirm a new dependency is not duplicating one already present.

### Cross-check against the docs
- Verify the behaviour matches the PRD acceptance criteria.
- Verify the UI matches [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md). Never invent a colour, font size, radius, or spacing value.

### Never assume these specifically
- That the device clock is correct. **Duty-window and curfew decisions use server time, always.**
- That a GPS point is real, accurate, or in order.
- That the network is available, or that a request that timed out did not actually succeed.
- That a third party's pricing, limits, or policy is what you remember. **Verify it, or mark it `VERIFY` in the docs.**

---

## Rule 4 — Think like a senior Flutter engineer

- Correctness first, then clarity, then performance. Never cleverness.
- Handle the unhappy path in the same change as the happy path, not "later".
- Every list is paginated. Every async surface has loading, empty, and error states. No exceptions. See [03-DESIGN-SYSTEM.md](03-DESIGN-SYSTEM.md).
- Business rules live on the server, where the user cannot reach them. The client only reflects them.
- No secrets in the client. No service-role key in the app, ever.
- Keep widgets small; keep logic out of `build`. Dispose every controller, subscription, and stream.
- Think about the real device: a cheap Android phone, a weak signal, an aggressive battery killer, a half-full storage card.
- If you do not understand why existing code does something, find out before changing it.

---

## Rule 5 — Search the web for any bug or error

- On any error, exception, build failure, or unexpected behaviour: search for the exact message before attempting a fix. Do not guess.
- Prefer official sources: Supabase docs and changelog, MapLibre and the `maplibre_gl` plugin docs and GitHub issues, Cloudinary docs, Flutter and `pub.dev` docs, Android developer docs, Google Play policy pages.
- Supabase, MapLibre and Cloudinary all change often. Check the changelog for breaking changes rather than relying on memory. The `maplibre_gl` plugin is community-maintained and less mature than a commercial SDK, so check its open issues before assuming a feature exists.
- When a search informs a fix, record the source link in [CHANGELOG.md](../CHANGELOG.md).
- After two or three failed attempts at the same approach, **stop**. Re-read the error, check the logs, and try a different approach. Do not loop.

---

## Rule 6 — Double-check after implementing

Every change ends with this checklist. State the result of each item; do not just claim "done".

### Correctness
- [ ] Re-read the full diff line by line, as a reviewer who did not write it.
- [ ] Verified against the PRD acceptance criteria for that function.
- [ ] Tested the happy path on a real device or emulator.
- [ ] Tested: no internet, GPS off, permission denied, app backgrounded, app force-killed, empty data, large data.
- [ ] Analyzer and formatter are clean. No new warnings.
- [ ] No new error in the device log or the Supabase logs.

### Database
- [ ] Re-read the live schema and confirmed it matches what was intended.
- [ ] Ran the queries as an **employee** role and as an **admin** role, and confirmed each sees exactly what it should and nothing more.
- [ ] Ran the Supabase advisors and addressed what they reported.
- [ ] Confirmed the relevant indexes exist and are actually used.

### Dead and leftover code — mandatory after every change
- [ ] No commented-out code left behind.
- [ ] No unused imports, variables, functions, files, or assets.
- [ ] No unused dependency added to `pubspec.yaml`.
- [ ] No orphaned database objects: unused tables, columns, indexes, policies, or functions from a superseded approach.
- [ ] No debug `print`, `TODO`, or temporary test values shipped.
- [ ] No duplicated logic that should have reused something existing.
- [ ] No feature flag or dead branch that can no longer be reached.

### Regression
- [ ] Listed what else touches the changed code and verified each one still works.
- [ ] Confirmed existing features still function: duty toggle, tracking, live map, notifications, reports.

### Record
- [ ] [CHANGELOG.md](../CHANGELOG.md) updated.
- [ ] Affected docs updated.

---

## Rule 7 — Keep the changelog, always

Every one of these gets an entry in [CHANGELOG.md](../CHANGELOG.md), in the same step as the work:

- a new function or feature
- any code change, including a small one
- a bug found, with how to reproduce it
- a bug fixed, with the root cause and the fix
- a schema or RLS change
- a dependency added, removed, or upgraded
- a config, settings, or environment change
- a decision that changes a locked value, with the reason

An entry states **what changed, why, what it affects, and how it was verified.** "Fixed a bug" is not an acceptable entry.

---

## Rule 8 — Reporting honestly

- If a test fails, say so and show the output. Never describe unverified work as working.
- If a step was skipped, say it was skipped and why.
- If something is uncertain, label it uncertain. Mark unverified external facts as `VERIFY`.
- Never claim a check was run when it was not.
- If an approach was abandoned, say so and say what replaced it.

---

## Rule 9 — Money, data, and irreversible actions

- Anything that creates cost — a Supabase plan change, a Cloudinary paid plan, a Play Console fee — needs explicit approval with the cost stated first. **The map stack costs nothing and has no account**, so it cannot generate a bill.
- Never delete or overwrite data without showing what will be lost and getting approval.
- Treat employee location data and visit photos as personal data. Minimum access, shortest viable retention. See [05-SECURITY.md](05-SECURITY.md).
- Destructive SQL (`drop`, `truncate`, `delete` without a narrow `where`, a destructive `alter`) needs explicit approval and a stated rollback plan.
- Never commit secrets. Never push to a remote without being asked.

---

## The loop, in one picture

```
Read docs  →  Propose (Rule 2)  →  Get permission (Rule 1)
    →  Cross-check DB + code + docs (Rule 3)
    →  Implement as a senior engineer would (Rule 4)
    →  Verify + hunt dead code + regression (Rule 6)
    →  Changelog + docs (Rule 7)
    →  Report honestly (Rule 8)  →  Ask for the next step
```
