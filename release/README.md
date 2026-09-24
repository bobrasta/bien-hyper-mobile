# Releasing Hypermed desktop

1. Bump nothing by hand — the version comes from the tag.
2. Tag and push, with release notes as the tag message (shown in the app's
   "What's new"):

       git tag -a v1.4.0 -m "Faster machine list. New vendor fee receipts."
       git push origin v1.4.0

3. `.github/workflows/release.yml` builds the Windows installer (Inno Setup,
   on a Windows runner) and the Linux tarball, writes `latest.json`, uploads
   all three to the VPS updates folder, and attaches them to a GitHub Release.
4. Every running app picks it up within 4 hours (or at next start / via
   Settings → Preferences → App updates → Check for updates).

**Forcing an update**: set `release/min_version.txt` to the new version before
tagging. Any app older than that shows a blocking "Update required" screen
(use this after breaking API changes).

**Building locally (Linux)**:

    flutter build linux --release --build-name=1.4.0
    tool/package_linux.sh 1.4.0

## One-time setup

GitHub repo → Settings → Secrets and variables → Actions:

| Name | Kind | Value |
|---|---|---|
| `VPS_HOST` | secret | VPS hostname/IP |
| `VPS_USER` | secret | SSH user that owns the updates folder |
| `VPS_SSH_KEY` | secret | private key for that user (dedicated deploy key) |
| `VPS_UPDATES_DIR` | secret | absolute path served at `UPDATE_BASE_URL` |
| `UPDATE_BASE_URL` | variable | e.g. `https://app.hypermed.co.tz/updates` |
| `API_BASE_URL` | variable | optional; baked into builds (else the default in `api_client.dart`) |

Without the VPS secrets the workflow still builds and creates the GitHub
Release, it just skips the VPS upload.
