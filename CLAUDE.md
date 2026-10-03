# CLAUDE.md — bien-hyper-mobile

Hypermed (medical-equipment service, sales, finance, HR) Flutter client.
This repo is a **duplicate of `bobrasta/bien-hyper`** made for the mobile
UI/UX work; the owner asked that the original not be touched directly.

## Repos and branches

| Repo | Role |
|---|---|
| `bobrasta/bien-hyper` | Original Flutter app (private). Read/fetch only from here — never commit, push, stash or run builds in its checkout. |
| `bobrasta/bien-hyper-mobile` (this) | `main` = untouched base copy; **`mobile-ui-layout`** = all mobile work. Push here. |
| `bobrasta/hypermed-api` | Laravel backend (public). Dashboard endpoints live in `DashboardController`. |
| `bobrasta/hypermed-web` | Blade web client (private). |

In a checkout of this repo, `origin` may point at `bien-hyper` and `mobile`
at this repo — check `git remote -v` before pushing.

**Keeping in sync:** when asked whether upstream has new work, `git fetch
origin` and list `<last merged>..origin/master`; also check
`hypermed-api` (backend commits often pair with app commits). Bring
upstream in with a **merge** into `mobile-ui-layout` (never rebase), then
re-check anything that touches screens already adapted for phones — a
clean textual merge can still be a logical conflict (e.g. the per-line TSh
discount changed `line_items.dart` after the phone row was written).
Last merged upstream: `3156a22` (CTO dashboard redesign, 2026-10-03).

## Mobile layout conventions

- **Shell breakpoints** (`widgets/common/app_shell.dart`): < 720 phone
  (page-title top bar, role-aware bottom tabs + "More" drawer), 720–1099
  tablet (icon rail), ≥ 1100 desktop.
- **Screen breakpoint**: `isPhoneWidth(width)` / `kPhoneBreakpoint = 600`,
  measured on the screen's own content width (LayoutBuilder), not the window.
- **Desktop layouts stay as they were** — every phone change is a branch
  taken only below the breakpoint.
- Shared phone widgets in `widgets/common/phone_layout.dart`:
  `PhonePageHeader` (title, primary action, ⋮ menu, search, swipeable
  filters, `bottom` slot), `PhoneRecordCard` (table row → card), `PhonePill`,
  `PhoneStatGrid` / `statStrip` (4–5-up KPI strips → 2 per row),
  `TitleWithActions`, `sideBySideOrStacked`, `fitOnPhone`,
  `pushPhoneDetail`, `PhoneModalBox` (in-screen modals dock as a bottom
  sheet; `scroll: false` for cards that already scroll inside).
- List + detail screens: detail opens as a pushed page, or replaces the
  list in place when it reloads data after opening; wrap the in-place form
  in `PopScope` so Android back closes the detail first.
- Bottom tabs come from the role's allowed screens (`_mobileTabs`), never a
  fixed list; `navEntryFor(key)` in `sidebar.dart` gives labels/icons.
- `AppShell(initialScreenKey: …)` opens a given screen (used by tests).

## Verifying changes

- `flutter analyze` — baseline is **56 info-level** notes (all pre-existing,
  2 of them in upstream's CTO code). New warnings/errors are not OK.
- `flutter test` — all pass except **`test/widget_test.dart` App smoke
  test, which fails on the original too** (trialNotifier never initialised).
- `test/phone_layout_audit_test.dart` opens all 58 menu screens at 390×844
  and 12 "new …" forms, failing on any overflow. It uses the test font
  (wider than real fonts), so it also guards larger Text Size settings.
- Empty-data audits miss row/content overflows: for dashboards, render with
  realistic data (stub `ApiClient.instance.dio` with an interceptor keyed by
  path) and check at 390 px **and** 1440 px. Keep sample data out of the repo.
- Screenshots: `matchesGoldenFile` + `--update-goldens`, after loading real
  fonts with `FontLoader` (TildaSans from assets, MaterialSymbols from the
  pub cache, Roboto from the Flutter SDK; google_fonts' Inter/JetBrainsMono
  must be downloaded and registered as `Inter_700`, `JetBrainsMono_regular`, …).

## Traps

- Running `flutter test`/`analyze` regenerates
  `macos/Flutter/GeneratedPluginRegistrant.swift` — restore it with
  `git checkout --` before committing.
- In widget tests, restore `FlutterError.onError` in a `finally` before any
  `expect`, or one failure hangs the remaining tests.
- `flutter_secure_storage` needs a mock method channel in tests, or screens
  that call `AuthService.getProfile()` sit on their skeleton forever.
- A `Text` in a `Row` beside a `Spacer`/buttons must be `Expanded`/`Flexible`
  with `maxLines` + `overflow` — the most common phone overflow here.
- Fixed `childAspectRatio` grids make tiles absurdly tall on tablets; prefer
  `mainAxisExtent`.

## Open items (as of 2026-10-03)

- No PR yet from `mobile-ui-layout` into `bien-hyper` master — only on request.
- Never tested on a physical device; an Android APK build was offered.
- CTO approval detail screen not exercised at phone size.
- This repo's `main` is still the original base (`2cf153e`), so the compare
  view also shows merged upstream commits.
