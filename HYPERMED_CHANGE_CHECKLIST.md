# Hypermed Change Request — Progress Checklist

Tracking implementation of `hypermed_claude_code_prompt.md` (14-section spec covering approvals, notifications, machine lifecycle, and more). Each section is checked off only once hypermed-api + Flutter + hypermed-web are ALL done and verified against real data — a partial implementation stays unchecked with a note on exactly what's missing.

**Audit completed 2026-09-20** by direct code inspection (the original 4 parallel research agents all hit a session rate limit and were abandoned partway through — findings below are from reading the actual current code directly, not from their partial output). Every verdict below cites the real file/behavior found, not a guess.

## 🚩 Two real bugs found during the audit, not just missing features

- **Self-approval is currently possible.** `PerDiemController`'s `approveTeamLead()`/`approve()`/`reject()`/`rejectTeamLead()` check only role authority (`hasTeamLeadAuthority()`/`hasCtoApprovalAuthority()`), never whether the actor is also the request's own `user_id`. A team_leader or CTO who submits their own per-diem request can currently approve it themselves. `markPaid()` has a *partial* self-check but only against `payment_initiated_by`, not the original requester.
- **Rejection reason is optional, not required.** `rejectTeamLead()`/`reject()` both validate `rejection_reason` as `nullable`. `cancel()` doesn't accept a reason field at all.

## Foundation

- [ ] **Section 4 — Searchable select (combobox)** — NOT STARTED. No reusable searchable/combobox widget exists in `lib/widgets/common/` (Flutter) or as a JS pattern in Blade. `HospitalController::index()` has no `q`/search param at all — only `type`/`region`/`zone` filters, full-list pagination.
- [ ] **Section 3 — Ticket resolve requires a report file** — NOT STARTED. `ServiceTicketController::resolve()` requires only `resolution_notes` (string) + optional `parts_used`; no file/attachment requirement anywhere in validation.

## Machine lifecycle

- [ ] **Section 13 — Machine lifecycle (In Stock/Allocated/Installed), ownership transfer** — NOT STARTED. `machines` table has no `lifecycle_stage`, no `owner`, no `machine_transfers` table. `hospital_id` is a **non-nullable** foreign key (`constrained()->cascadeOnDelete()`), so "in a store, not yet at a hospital" can't even be represented in the current schema without a migration. The existing `pending_installation`/`pending_signoff` `status` values (added 2026-08-26, `MachineRegistrationService`) cover a narrower slice of this — Sales-Order-delivered machines only — not the general Receive/Allocate/Handover model this section wants.
- [ ] **Section 12 — Machine "Service Costs" tab + replacement flag** — NOT STARTED. Machine detail tabs today are exactly `['Overview', 'Service History', 'Revenue', 'Documents', 'Notes']` — no Service Costs tab. No `purchase_cost` column on `machines`. No configurable replacement-threshold setting found.

## Installation workflow

- [ ] **Section 6 — Installation tickets covering multiple machines + handover wizard** — NOT STARTED. Confirmed no `service_ticket_machines` (or similar) link table in any migration — `service_tickets.machine_id` is still strictly one machine per ticket.
  - Note: a narrower "register a single new machine inline on Create Service Ticket" shipped 2026-09-18 (commit `2891699` api / `a404321` Flutter / `48e744a` web) — real and useful, but not the same as this section's multi-machine requirement. Doesn't count toward this checkbox.

## Travel plans / approvals / notifications

- [ ] **Section 8 — CTO day-by-day travel plan editing** — PARTIALLY DONE. The day-by-day data model already exists and is used at creation time: `PerDiemLine` (region/district/site_name/activity/labor_cost/per_diem_cost/transport_fare), summed server-side into the request total in `PerDiemController::store()`. What's missing: no edit/update route for an existing request at all (only approve/reject/pay/cancel exist in `routes/api.php`), no revision-history model, no technician edit-grant mechanism, no payment-adjustment concept for after "Money is Out".
- [ ] **Section 9 — Mandatory reason on rejection/cancellation** — NOT STARTED (see bug flagged above). Also: the spec's "CTO can cancel even after approval" case has no code path at all today — `cancel()` only allows `pending_team_lead`/`pending_cto` statuses, full stop, regardless of who's asking.
- [ ] **Section 11 — Stage-by-stage notifications (in-app + email)** — MOSTLY DONE for in-app, further along than any other section. `PerDiemController` already fires a notification at nearly every transition (submit → team lead, team-lead-approve → CTO, CTO-approve → finance, payment-initiated → Director, paid → requester, plus both rejection paths → requester), and `NotificationTemplateService` + the "Notification Wording" settings page already cover all of these per-diem templates. Confirmed gaps: (1) no requester-facing notification specifically when payment is initiated (stage 4, "awaiting Director") — only the Director is notified at that point; (2) no email channel at all for this flow, only in-app; (3) not architecturally centralized — each notification is hand-called per controller action, not event/listener-driven as the spec asks.
- [ ] **Section 1 — Approvals: own requests only, no self-approval** — PARTIALLY DONE / bug found (see flagged above). `PerDiemController::index()` correctly scopes to `user_id = $user->id` for anyone without team-lead or accountant authority — so a plain technician's own view is already correct. But anyone who *does* hold that authority sees every request unfiltered, including their own, with no self-approval block anywhere.

## Self-service / UI

- [ ] **Section 7 — Technician self-service (My Reports, My Travel Plans)** — NOT STARTED. No matches anywhere in the Flutter codebase for either concept; technicians currently have no way to see their own submitted per-diem/travel-plan requests at all (Approvals' `index()` scoping from Section 1 would technically support this today if a screen were built to consume it).
- [ ] **Section 2 — Dashboard: bigger map, legend as a separate card** — NOT STARTED. Confirmed the status legend (`_legendRow` for Operational/Needs Service/Down/Technician En Route) renders **inside** `_MapPanel` today, not separately. The existing Machines/Alerts/Technicians pills are a *different* thing than what the spec wants added (those are data-layer toggles the spec says should stay put) — a Satellite/Terrain/Light-Dark map-style switcher doesn't exist yet and would need building.
- [ ] **Section 5 — Downloads for every role** — SPLIT: **Flutter already done** (`sidebar.dart:135`, `if (key == 'downloads') return true;` — deliberately universal, well-commented, exactly matches the spec). **Blade not started at all** — zero references to "download" anywhere in `Nav.php`, no controller, no view. Bigger gap than the spec assumed (it isn't just missing for technicians on web, it doesn't exist on web at all).
- [ ] **Section 10 — Ticket list ordering** — NOT STARTED. `ServiceTicketController::index()` is `$query->latest()->paginate($perPage)` — plain newest-first, no active/resolved split, no priority ordering, no overdue-first logic. Matches the spec's "Problem" description exactly.

## Wrap-up

- [ ] **Section 14 — Final parity checklist** — this file serves that purpose; will be filled in as each section above is actually finished.

---

## Suggested next step

Given the audit, the two flagged bugs (self-approval, optional rejection reason) are small, high-value, and self-contained — worth doing first regardless of build order, since they're real gaps in money-approval integrity today, not just missing spec features. After that, the spec's own suggested build order (Section 4 → 3 → 13/12 → 6 → 8/9/11 → the rest) still holds.

## Assumptions carried from the spec (confirm before building the section they affect)

1. Section 9: mandatory reason applies to travel plans only for now.
2. Section 13: ownership passes at signed handover after installation, not at delivery.
3. Section 11: push notifications stay mobile-only if already implemented; no new push infrastructure.
4. Section 12: 50% threshold is a configurable Setting, default 0.5.
