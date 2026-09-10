# Backups and Google Drive setup

The super manager can open **Settings → Backups** to create a `.json` backup of
all markets on this device: inventory, sales, staff accounts, logos, preferences
and audit history. The file includes account password hashes, so keep it private.
There is a 100 MB limit. This is a manual backup feature.

**Restore backup** first validates the file and then asks for confirmation.
Restoring replaces the complete local database in one transaction; it does not
merge records. Save a current backup first. You are signed out after restoring
and must use an account and password from the restored backup.

## Connect a Google account

The app supports direct Google Drive connection on the localhost/web app and
macOS, Windows and Linux desktop builds. Android/iOS can create a local backup
and upload it through the Google Drive app; direct mobile Google sign-in is not
implemented. No Gmail inbox permissions are requested.

The account connection cannot work until the app owner configures Google OAuth.
It uses `openid`, `email`, and `https://www.googleapis.com/auth/drive.appdata`.
Backups go into the app's private application-data folder. They are not shown as
ordinary files in My Drive; use **Restore from Google Drive** inside the app to
choose among the 20 newest backups. Older backups are not deleted automatically.
See Google's [application-data folder guide](https://developers.google.com/workspace/drive/api/guides/appdata).

1. Open [Google Cloud Console](https://console.cloud.google.com/) with your Google
   account. Use the project selector at the top to create a project named
   **Bazaar POS**, or select your existing app project.
2. Open **APIs & Services → Library**, search for **Google Drive API**, open it
   and select **Enable**.
3. Open **Google Auth Platform → Branding → Get started**. Set the app name to
   **Bazaar POS**, choose your support email, select **External** to allow Gmail
   accounts, and enter your contact email. Review Google's policy and finish
   creating the configuration if you agree.
4. Under **Audience → Test users → Add users**, add your Gmail address and any
   other accounts that will test backups. Keep the app in **Testing** while
   setting it up.
5. Under **Data Access → Add or remove scopes**, select `openid`,
   `https://www.googleapis.com/auth/userinfo.email` (Google's email scope), and
   `https://www.googleapis.com/auth/drive.appdata`, then save.
6. Open **Clients → Create client** twice, using the settings below. Both clients
   must belong to this same Google Cloud project. Download each client's JSON
   configuration and keep track of which file is Desktop and which is Web.

| Version | Application type | Suggested client name | Authorized JavaScript origins |
| --- | --- | --- | --- |
| Mac | Desktop app | Bazaar POS Desktop | Not applicable |
| Browser | Web application | Bazaar POS Web | `http://localhost` and `http://localhost:8080` |

These menu paths follow Google's [consent setup](https://developers.google.com/workspace/guides/configure-oauth-consent)
and [client creation guide](https://developers.google.com/workspace/guides/create-credentials).
Downloaded Google JSON files contain nested `installed` or `web` configuration;
they are not directly usable as Flutter `--dart-define-from-file` files. Copy the
values into the flat templates below, or provide their local file paths to have
the configuration completed without pasting secrets into chat.

### Browser / localhost preview

Use the **Web application** OAuth client. Under **Authorized JavaScript origins**,
add both `http://localhost` and `http://localhost:8080`, as recommended in Google's
[local testing setup](https://developers.google.com/identity/oauth2/web/guides/get-google-api-clientid).
Open the app at `http://localhost:8080` when testing. Add your exact HTTPS origin
for hosted builds. This uses Google's popup token flow; leave **Authorized redirect
URIs** empty and do not use the Web client secret. See the official
[token flow setup](https://developers.google.com/identity/oauth2/web/guides/use-token-model).

Copy the Web template into the Git-ignored local directory:

```sh
mkdir -p .local
cp config/google-drive-web.example.json .local/google-drive-web.json
```

Replace `REPLACE_WITH_WEB_CLIENT_ID` with the downloaded Web file's
`web.client_id`, then build and serve:

```sh
bash tool/serve.sh --dart-define-from-file=.local/google-drive-web.json
```

For a hosted build, use
`bash tool/build_web.sh --dart-define-from-file=.local/google-drive-web.json`
and deploy `build/web` to an origin registered on the Web client. Keep passing
the configuration on later builds. If the client ID is omitted, Drive remains
unconfigured and local backups still work.

### Desktop

Create a **Desktop app** OAuth client. Desktop sign-in opens the system browser
and receives Google's callback on a random loopback port, with OAuth state and
PKCE validation. The macOS build includes client/server network entitlements for
this loopback flow. See Google's [installed-app OAuth guide](https://developers.google.com/identity/protocols/oauth2/native-app).

Copy the Desktop template into the Git-ignored local directory:

```sh
mkdir -p .local
cp config/google-drive-desktop.example.json .local/google-drive-desktop.json
```

Replace `REPLACE_WITH_DESKTOP_CLIENT_ID` with the downloaded Desktop file's
`installed.client_id` and `REPLACE_WITH_DESKTOP_CLIENT_SECRET` with its
`installed.client_secret`. If Google did not provide a Desktop secret, use an
empty string for that value. Then:

```sh
flutter run -d macos --dart-define-from-file=.local/google-drive-desktop.json
# Or build the configured app for distribution:
flutter build macos --dart-define-from-file=.local/google-drive-desktop.json
flutter build windows --dart-define-from-file=.local/google-drive-desktop.json
```

Use an installed-app client for desktop; never put a confidential Web/server
client secret in the app. Google treats installed applications as public clients.
Client configuration is separate from each user's Google account password.
The app must be rebuilt and reopened after changing these values; hot reload
does not replace compile-time configuration.

### If connection fails

- **Google Drive needs OAuth configuration:** rebuild with the correct local
  configuration file. An already installed build will still have its old values.
- **Origin is not allowed:** match the browser's scheme, hostname and port to an
  authorized JavaScript origin. `localhost` and `127.0.0.1` are different hosts.
- **Access blocked while testing:** add the signing-in Google account under
  **Audience → Test users**.
- **Invalid client or redirect URI on Mac:** confirm that the build uses the
  **Desktop app** client, including its Desktop secret if supplied by Google.

## Use it

Choose **Connect Google account**, select your account and grant backup access.
Then choose **Back up to Google Drive**. **Restore from Google Drive** downloads
the chosen backup and asks for the same full-replacement confirmation as a local
restore. An upload is reported as successful only after Drive acknowledges it.

Tokens stay in memory, expire, and are excluded from database backups. Reconnect
after restarting the app or when the session expires. **Disconnect** clears the
local session and asks Google to revoke the app's access. There is no scheduled
backup or cross-device database synchronization.

## Regression checks

```sh
flutter analyze
flutter test test/market_currency_display_test.dart test/market_backup_ui_test.dart test/backup_test.dart test/google_drive_backups_test.dart
```

OAuth consent and real Drive uploads need a configured Google client and a test
Google account to verify end to end.
