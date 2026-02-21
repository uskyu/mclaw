# MClaw Update Hosting Files

Upload this folder to Cloudflare Pages (or any static host).

## Files

- `update.json`: consumed by the app for version check
- `update.html`: download landing page opened by the app

## Before upload

1. Edit `update.json`
   - set `latestVersion` to your app version
   - set `downloadUrl` to your hosted `update.html` URL
   - update `releaseNotes`
2. Edit `update.html`
   - replace APK/mirror links
   - update visible version and notes

## Publish flow (each release)

1. Build and upload new APK to your file host (for example Lanzou).
2. Update `update.html` links.
3. Update `update.json` version and notes.
4. Re-upload files to Cloudflare Pages.
