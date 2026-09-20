# Hypermed Change Request — Progress Checklist

Tracking implementation of `hypermed_claude_code_prompt.md` (14-section spec covering approvals, notifications, machine lifecycle, and more). Each section is checked off only once hypermed-api + Flutter + hypermed-web are ALL done and verified against real data — a partial implementation stays unchecked with a note on exactly what's missing.

**Audit completed 2026-09-20** by direct code inspection (the original 4 parallel research agents all hit a session rate limit and were abandoned partway through — findings below are from reading the actual current code directly, not from their partial output). Every verdict below cites the real file/behavior found, not a guess.

## ✅ Two real bugs found during the audit — FIXED 2026-09-20

- **Self-approval was possible — now blocked.** New `abortIfSelfActioning()` guard added to `approveTeamLead()`/`rejectTeamLead()`/`approve()`/`reject()`/`initiatePayment()`/`markPaid()` in `PerDiemController` — 403s if the actor is the request's own `user_id`. `cancel()` deliberately excluded (cancelling your own not-yet-approved request is ordinary self-service, not self-approval). Verified via tinker: same-user approve → 403, different approver → 200.
- **Rejection/cancellation reason was optional — now required.** `rejection_reason`/`cancellation_reason` are `required|string|min:10` across `rejectTeamLead()`, `reject()`, and the rewritten `cancel()` (which now also persists `cancelled_by`/`cancelled_at`/`cancellation_reason`, mirroring the `paid_by`/`paid_at` pattern). All three layers updated together: hypermed-api (`1af9126`, deployed to production — Railway deploy `c9ac62bf` **SUCCESS**), Flutter (`1484de8` — shared `_RejectReasonDialog` gets an opt-in `minLength` param, other reject flows unaffected), hypermed-web (`d5e9369` — reject modal textarea gets `required minlength="10"`).
- Scope note: the broader "CTO can cancel after full approval" gap (Section 9) and full mandatory-reason UX across all reject/cancel flows are still open — this fix closed the two integrity gaps, not the full spec sections they sit under.

## Foundation

- [x] **Section 4 — Searchable select (combobox)** — DONE 2026-09-21, both platforms.
  - **Foundation**: backend `q` search mode on `HospitalController::index()` (ILIKE name/short_code, capped at 50, `23b7ee4`); `MachineModelNormalizer` service wired into `MachineController::store()`/`update()` (case/space/hyphen/punctuation-insensitive canonicalization, verified via tinker) + `machines:model-duplicates-report` dry-run artisan command (0 near-duplicates found in current 6-model data). Flutter's reusable `AppSearchableSelectField<T>` (`widgets/common/app_dropdown.dart`) and hypermed-web's vanilla-JS `gwSearchableSelect` (`public/js/combobox.js` + `GET /hospitals/search`) — both with client-side and debounced server-side modes, keyboard nav, clear button, "Create new" row.
  - **Every call site the spec names, converted on both platforms**: Machines page hospital filter (replacing Flutter's `_PickerDialog` unconstrained-Column bug and web's 500-hospital `<select>`, both explicitly named); Add/Edit Machine Hospital + Model fields; Create Service Ticket (Hospital, Machine, Assign Technician) + its inline "register new machine" panel; New Task / Task Board "Assign to" (create, filter, and inline reassign); Customers hospital filter + Add/Edit Contact; Inventory items (Requisitions, Stock Movements, Quotations line items) and Parts Used (service ticket Add Part, technician-dashboard Add Part, cannibalization source machine). Per-diem/travel plan forms checked on both platforms — genuinely no select/dropdown fields exist there (all free text), nothing to convert.
  - **Bugs found and fixed along the way** (each needed for the converted field to actually work, not scope creep): `ContactController::update()` silently dropped `hospital_id` entirely — a contact's hospital could never be changed via the API (`a5e3161`, hypermed-api). Flutter's Add/Edit Contact sent `hospital_name`, which the backend never validated — every Add Contact was silently 422ing (`e594b19`). A Blade `@json(collect()->map(fn ($x) => [...multi-line array...]))` call doesn't compile ("Unclosed '['") — hit twice (`ServiceTicketsController`, `QuotationsController`), fixed by precomputing the slim option array server-side instead of inline in the view; single-line `@json(collect()->map())` calls are unaffected.
  - **Deliberately left as plain selects**: ticket type/priority, movement type, equipment type, FROM/TO location (a handful of warehouses — not a growing list at real scale), hospital type/region (Tanzania's ~26 regions), part category/unit-of-measure, a static-const supplier list. All short, fixed enums per the spec's own carve-out.
  - **Verification**: Flutter — `flutter analyze` clean project-wide throughout (no live UI/browser session run this pass). hypermed-web — every touched view Blade-compiled, rendered with realistic fixture data via `php artisan tinker`, and had its actual emitted `<script>` blocks extracted and syntax-checked with `node --check`; the hospital search endpoint was also verified end-to-end against real production data with a real login token. Backend pieces verified via transaction-rolled-back tinker calls against real data.
  - **Real remaining scope, honestly**: existing-duplicates cleanup stayed report-only per spec (no merge UI — 0 duplicates found, none needed yet). No live browser/device testing was done for either platform's UI this pass — `flutter analyze` and Blade-render/`node --check` are static/server-side checks, not a substitute for actually clicking through the combobox in a running app.
- [ ] **Section 3 — Ticket resolve requires a report file** — NOT STARTED. `ServiceTicketController::resolve()` requires only `resolution_notes` (string) + optional `parts_used`; no file/attachment requirement anywhere in validation.

## Machine lifecycle

- [ ] **Section 13 — Machine lifecycle (In Stock/Allocated/Installed), ownership transfer** — NOT STARTED. `machines` table has no `lifecycle_stage`, no `owner`, no `machine_transfers` table. `hospital_id` is a **non-nullable** foreign key (`constrained()->cascadeOnDelete()`), so "in a store, not yet at a hospital" can't even be represented in the current schema without a migration. The existing `pending_installation`/`pending_signoff` `status` values (added 2026-08-26, `MachineRegistrationService`) cover a narrower slice of this — Sales-Order-delivered machines only — not the general Receive/Allocate/Handover model this section wants.
- [ ] **Section 12 — Machine "Service Costs" tab + replacement flag** — NOT STARTED. Machine detail tabs today are exactly `['Overview', 'Service History', 'Revenue', 'Documents', 'Notes']` — no Service Costs tab. No `purchase_cost` column on `machines`. No configurable replacement-threshold setting found.

## Installation workflow

- [ ] **Section 6 — Installation tickets covering multiple machines + handover wizard** — NOT STARTED. Confirmed no `service_ticket_machines` (or similar) link table in any migration — `service_tickets.machine_id` is still strictly one machine per ticket.
  - Note: a narrower "register a single new machine inline on Create Service Ticket" shipped 2026-09-18 (commit `2891699` api / `a404321` Flutter / `48e744a` web) — real and useful, but not the same as this section's multi-machine requirement. Doesn't count toward this checkbox.

## Travel plans / approvals / notifications

- [ ] **Section 8 — CTO day-by-day travel plan editing** — PARTIALLY DONE. The day-by-day data model already exists and is used at creation time: `PerDiemLine` (region/district/site_name/activity/labor_cost/per_diem_cost/transport_fare), summed server-side into the request total in `PerDiemController::store()`. What's missing: no edit/update route for an existing request at all (only approve/reject/pay/cancel exist in `routes/api.php`), no revision-history model, no technician edit-grant mechanism, no payment-adjustment concept for after "Money is Out".
- [ ] **Section 9 — Mandatory reason on rejection/cancellation** — PARTIALLY DONE. Per-diem's reject/cancel reasons are now required (min:10) end-to-end — see fix above. Still missing: the spec's "CTO can cancel even after approval" case has no code path at all today — `cancel()` only allows `pending_team_lead`/`pending_cto` statuses, full stop, regardless of who's asking; and mandatory reasons haven't been extended to other reject/cancel flows in the app (stock-out, expense, PO) beyond per-diem.
- [ ] **Section 11 — Stage-by-stage notifications (in-app + email)** — MOSTLY DONE for in-app, further along than any other section. `PerDiemController` already fires a notification at nearly every transition (submit → team lead, team-lead-approve → CTO, CTO-approve → finance, payment-initiated → Director, paid → requester, plus both rejection paths → requester), and `NotificationTemplateService` + the "Notification Wording" settings page already cover all of these per-diem templates. Confirmed gaps: (1) no requester-facing notification specifically when payment is initiated (stage 4, "awaiting Director") — only the Director is notified at that point; (2) no email channel at all for this flow, only in-app; (3) not architecturally centralized — each notification is hand-called per controller action, not event/listener-driven as the spec asks.
- [ ] **Section 1 — Approvals: own requests only, no self-approval** — PARTIALLY DONE. `PerDiemController::index()` correctly scopes to `user_id = $user->id` for anyone without team-lead or accountant authority — so a plain technician's own view is already correct. No-self-approval is now enforced for per-diem (see fix above). Still missing: the "self-view" list UI for technicians (Section 7 territory) and the equivalent no-self-approval guard hasn't been audited/applied to the other approval chains (stock-out, expense, PO) yet.

## Self-service / UI

- [ ] **Section 7 — Technician self-service (My Reports, My Travel Plans)** — NOT STARTED. No matches anywhere in the Flutter codebase for either concept; technicians currently have no way to see their own submitted per-diem/travel-plan requests at all (Approvals' `index()` scoping from Section 1 would technically support this today if a screen were built to consume it).
- [ ] **Section 2 — Dashboard: bigger map, legend as a separate card** — NOT STARTED. Confirmed the status legend (`_legendRow` for Operational/Needs Service/Down/Technician En Route) renders **inside** `_MapPanel` today, not separately. The existing Machines/Alerts/Technicians pills are a *different* thing than what the spec wants added (those are data-layer toggles the spec says should stay put) — a Satellite/Terrain/Light-Dark map-style switcher doesn't exist yet and would need building.
- [ ] **Section 5 — Downloads for every role** — SPLIT: **Flutter already done** (`sidebar.dart:135`, `if (key == 'downloads') return true;` — deliberately universal, well-commented, exactly matches the spec). **Blade not started at all** — zero references to "download" anywhere in `Nav.php`, no controller, no view. Bigger gap than the spec assumed (it isn't just missing for technicians on web, it doesn't exist on web at all).
- [ ] **Section 10 — Ticket list ordering** — NOT STARTED. `ServiceTicketController::index()` is `$query->latest()->paginate($perPage)` — plain newest-first, no active/resolved split, no priority ordering, no overdue-first logic. Matches the spec's "Problem" description exactly.

## Wrap-up

- [ ] **Section 14 — Final parity checklist** — this file serves that purpose; will be filled in as each section above is actually finished.

---

## Suggested next step

The two flagged bugs (self-approval, optional rejection reason) are fixed and deployed as of 2026-09-20. Section 4 (searchable select) is done as of 2026-09-21. Next per the spec's own suggested build order: Section 3 (file upload for ticket resolve) → 13/12 (machine lifecycle/costs) → 6 (installation tickets) → 8/9/11 (travel plans/reasons/notifications) → the rest.

## Assumptions carried from the spec (confirm before building the section they affect)

1. Section 9: mandatory reason applies to travel plans only for now.
2. Section 13: ownership passes at signed handover after installation, not at delivery.
3. Section 11: push notifications stay mobile-only if already implemented; no new push infrastructure.
4. Section 12: 50% threshold is a configurable Setting, default 0.5.
