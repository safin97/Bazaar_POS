# Put Bazaar POS online

The browser app runs locally at `http://localhost:8080`. To open it from another
device over the internet, publish the contents of `build/web` to an HTTPS static
website host. Hosting the website and publishing downloadable GitHub releases
are separate operations.

## Publish the browser app

1. Build the app with `bash tool/build_web.sh`. If Google Drive is configured,
   also pass `--dart-define-from-file=.local/google-drive-web.json`.
2. Open [Cloudflare Pages](https://dash.cloudflare.com/) and go to
   **Workers & Pages → Create application**. Choose **Pages** and the direct
   upload / drag-and-drop option.
3. Name the project and upload the `build/web` folder, or the prepared
   `build/releases/bazaar-pos-web.zip`. `index.html` must be at the root of the
   uploaded content. Deploy it and use the HTTPS address Cloudflare provides.
4. For future updates, rebuild and deploy to the same project and address. Open
   **Panel settings → App updates → Check this server** in Bazaar POS, then
   load the new version after saving current work.

See [Cloudflare's direct-upload instructions](https://developers.cloudflare.com/pages/get-started/direct-upload/).
The generated web folder contains application files; it does not contain the
market database stored in your browser.

## Keep your existing market data

Each browser profile and website origin has its own local database. The online
address starts with a separate database from localhost. To move your data, sign
in as super manager on localhost and use **Settings → Backups → Create backup**.
Sign in at the online address and restore that file there. Restore replaces the
data at the destination and signs you out; use an account from the backup to
sign in again.

Devices continue to work independently. Hosting does not add shared stock,
accounts, or sales synchronization. Google Drive backups are also manual; they
do not synchronize simultaneous checkout sessions.

For Google Drive sign-in, add the new HTTPS origin to the **Web application**
OAuth client's **Authorized JavaScript origins**, then use a build configured
with that client's ID. Follow [the OAuth setup guide](google-drive-backups.md).

## Make the GitHub update button work

The updater reads published releases from `safin97/flutter-pos`. A release must
be publicly accessible, published, and marked as a stable release. A source-code
push on its own does not publish an app update.

1. Build the intended app version. Set its version in `pubspec.yaml`; keep the
   development values in `lib/core/updates/app_updates.dart` in sync.
2. Open the repository's **Releases → Draft a new release**. Use a tag matching
   the build, for example `v1.0.2+3` for app version `1.0.2+3`.
3. Attach `bazaar-pos-web.zip` for browser distributions and the appropriate
   native package for desktop/mobile users, then publish the release. Accepted
   package names are listed in the [README](../README.md#github-updates).

See [GitHub's release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
Four-part tags also work: `v1.0.0.3` means app version `1.0.0` with build `3`.
That version is older than `1.0.2+3`, so it does not trigger a downgrade.
Browser packages must also be deployed to the website host before **Load
update** can switch to the new app. Native downloads must be installed.
