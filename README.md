<<<<<<< HEAD
# flutter-pos
to market
=======
# Bazaar POS

A Flutter supermarket point of sale for **iOS, Android, macOS and Windows**, with an additional **localhost browser preview**. Each installation has independent offline data.

## Open the local preview

While the preview server is running, open **http://localhost:8080**. Use this same address and browser profile each time; `127.0.0.1`, another port, or another profile has separate browser storage.

To build and start it again:

```sh
./tool/serve.sh
```

The welcome screen shows only the store branding, language selector, and username/password sign-in form. Enter username **`safin97`** and the password supplied by the store owner, then select **Sign in**. This account has **super manager** access. The password is not printed in this README or stored as plaintext in the app.

A one-time migration provisions this account for both fresh installations and existing local databases. Existing inventory, sales, branding and other staff accounts are retained. Subsequent starts respect account edits and password changes rather than resetting them. New installations include editable sample inventory with no fabricated sales. Store details and team accounts are managed after signing in.

Open only one tab per browser profile. The browser preview holds an exclusive Web Lock to avoid conflicting edits. Browser data is stored in IndexedDB and can be removed by clearing site data. It is a development preview: browser writes use SQLite's asynchronous IndexedDB cache, so the native app provides stronger durability guarantees. The local server must remain running to reload the browser app.

## Included workflows

- Responsive login-only welcome screen; desktop sidebar and mobile drawer.
- English, Arabic, and **Kurdish Badini in Arabic script**, with RTL layout, persistent language selection and bundled Noto fonts.
- Product search, category filtering, barcode entry, cart quantities, cash checkout, change calculation, and external card terminal payment recording.
- Inventory and category creation, editing and deletion; translated names, local photos and selectable icons, barcodes unique within each market, unit labels, costs, prices, stock counts and low-stock alerts.
- Staff creation, editing, password reset, account enable/disable and deletion, with permissions enforced in the data layer.
- Sales history, date filters, receipt reprinting, CSV export, seven-day sales chart, gross profit, item counts, seller/item breakdowns and stock alerts. Voided receipts are excluded from report totals.
- Manager sale voiding with a mandatory reason, exactly-once stock restoration for existing catalog items, and a retained receipt/audit history.
- Super admins and each market’s admin can edit its store name, logo, tagline, contact details, tax rate, receipt header/footer, cashier visibility and 58/80 mm receipt width. Saved receipts retain their market details, custom logo, seller, line costs and totals.
- PDF receipt generation and OS print dialogs using bundled fonts, without downloading fonts at runtime.
- Independent markets on the same device, each with its own categories, products, staff, sales, branding and audit log. Existing data migrates into the original market without resetting it.
- USD (US dollar), IQD and EUR as per-market currencies; dollar amounts display with a dollar sign and cents.
- Local SQLite transactions, an audit log, salted PBKDF2 password hashes and short sign-in throttling.

## UI previews

![Welcome screen](docs/previews/welcome-desktop.png)

![Point of sale](docs/previews/register-desktop.png)

## Set up two markets and admins

1. Sign in as `safin97`, open **Markets**, and choose **Add market**. Enter its name and choose **USD — US dollar ($)**, IQD or EUR. The original market and its records remain available.
2. **Manage market** selects that market and opens **Settings**. Upload its logo and edit the name, address, phone and receipt header/footer, then save.
3. Open **Team** and add an **Admin**, **Market owner** or **Cashier** account. When the super admin selects the **Admin** role for a new account, a **Market** dropdown lets them assign any existing market; owners and cashiers use the current market. Usernames are unique across this device so the login form stays username/password only.
4. Repeat for another market. Admins and staff are assigned to their market when created; they enter that market automatically at login. Only the super admin can switch markets or create another market.
5. Each admin can use **Categories** to add/edit category names, photos and icons, and **Inventory** to add products and their photos/icons. A category containing products cannot be deleted until those products are reassigned or removed.

Choose the market currency before adding inventory or making sales. Currency is fixed after that so existing prices and receipts are not silently reinterpreted. This is per-market currency support; there is no exchange-rate conversion or mixed USD/IQD tender within a sale.

A market owner opens **Overview** with revenue, gross profit, receipt count and item count. Select a date period and expand **Sales by staff** to see each seller’s items and receipts. **Sales history** supports search, PDF receipt printing/saving and CSV export including market, item count, cost and gross profit. Gross profit subtracts item costs and discounts and excludes tax; it does not include rent, wages or other operating expenses.

## Role permissions

| Action | Cashier | Admin | Market owner | Super admin |
| --- | --- | --- | --- | --- |
| Checkout | Yes | Yes | — | Yes |
| Own receipts and receipt reprint | Yes | Yes | Yes | Yes |
| All market sales, profit, seller reports and CSV | — | Yes | Yes | Yes |
| Products, categories, photos, icons and stock | — | Yes | — | Yes |
| Discount and void a sale | — | Yes | — | Yes |
| Add/edit/delete cashier accounts | — | Yes | — | Yes |
| Add/edit/delete admin and owner accounts | — | — | — | Yes |
| Market branding, receipts and audit log | — | Yes | — | Yes |
| Create or switch markets | — | — | — | Yes |

Permissions apply only within the account’s assigned market. When adding or editing a **Cashier** in **Team & access**, admins and super admins can select **Extra permissions**: all-market sales/profit reports and CSV export; inventory/category management (including prices, costs and photos); checkout discounts; and sale voiding/restocking. All are off by default. Voiding applies only to visible receipts: grant reporting access too to include other sellers’ receipts. These options never grant staff management, market switching or branding access.

A market owner is a read-only reporting role. Super manager accounts are hidden from Team & access for every role, and the super manager role is omitted from its role summaries and account editor. Accounts cannot delete/disable themselves or change their own role. Admins cannot promote users or edit another admin, owner or super admin. Switching markets clears the unsaved register cart and open forms. Posted transactions are retained; **Void & restock** reverses a sale without deleting its receipt history. Staff/product deletion retains historical receipt snapshots.

## Run native apps

Requires Flutter 3.47+ / Dart 3.13+. Dependencies are pinned in `pubspec.lock`.

```sh
flutter pub get
flutter devices
flutter run -d macos
flutter run -d windows  # on a Windows host
flutter run -d <ios-or-android-device-id>
```

Build commands:

```sh
flutter build apk --release
flutter build appbundle --release
flutter build ios --release --no-codesign
flutter build macos --release
flutter build windows --release
```

- **Android:** install Android Studio/SDK, accept SDK licenses, configure your signing key for release distribution.
- **iOS/macOS:** install full Xcode and run its first-launch setup. Plugin builds may also need CocoaPods. iOS device distribution needs your Apple signing team and provisioning.
- **Windows:** build on Windows with Visual Studio's Desktop development with C++ workload.
- macOS sandbox entitlements include user-selected file access and printing.
- Editable in-app branding changes the welcome screen, navigation and receipts. OS launcher names/icons are build-time assets; changing those requires rebuilding the app.

On the development Mac used to create this project, the Android SDK, full Xcode and CocoaPods were unavailable. Native binaries could not be verified there. The web release build and Flutter tests can be verified without these platform SDKs.

## Validation

```sh
flutter analyze
flutter test
# Browser storage, startup, authentication and checkout regression tests:
# Install Chrome, or set CHROME_EXECUTABLE to a Chrome/headless-shell binary.
./tool/test_web.sh
# Optional visual preview capture (writes docs/previews/*.png):
flutter test test/layout_test.dart --dart-define=CAPTURE_PREVIEWS=true
```

Browser tests exercise the real SQLite WASM/IndexedDB adapter and confirm the login screen appears. They also cover ID generation, staff creation, login, checkout, USD receipts, category/photo persistence within a sale, market separation and owner access in JavaScript.

Tests cover login-only UI, administrator provisioning, one-time account migration, authentication, role permissions, market isolation, legacy migration, separate branding/receipt snapshots, category and photo persistence, stock/payment validation, tax/discount rounding, transaction rollback, voiding, restart persistence, translations, responsive layouts, catalog editing, owner reports and multilingual PDF generation.

## Data and operating boundaries

Native data is stored in `bazaar_pos.sqlite` in the platform application-support directory. SQLite commits the stock updates, receipt and audit record in one transaction. Money uses integer hundredths, and tax rounds once on the discounted order subtotal. Quantities are **whole packs/units**; weighted quantities and scales are not implemented. Currency is fixed once inventory or sales exist so reports never mix denominations. Initial sample prices are illustrative.

The data layer lives in `lib/data/pos_store.dart`; platform storage adapters are in `lib/data/database_native.dart` and `database_web.dart`. Markets, categories, products, staff and sales have persistent market identifiers, and mutations validate the active market and role. Records have separate SQLite tables with JSON payloads. The UI keeps a local in-memory view of these tables; very large catalogs/ledgers would benefit from query pagination and background database work.

Role checks protect normal application workflows. A person with filesystem or browser developer-tool access can inspect or alter this local, unencrypted database; use OS account/device protection for a live checkout station. There is no cloud synchronization, remote account recovery, payment processor connection, automatic backup, camera scanner, cash-drawer driver, or direct Bluetooth/USB ESC/POS integration. Keyboard-style barcode scanners work through the search field (send Enter). Card payments must be completed on a separate terminal. Voiding a recorded sale does not send a monetary refund.

Badini translations are provided in `lib/core/strings.dart`; have a native Badini speaker review business terminology before rollout. Flutter's system Material calendar/picker controls use Arabic when Badini is selected; application labels and RTL layout use Badini. Product names can be edited independently in all three languages.

## References and asset licenses

- [Flutter platform setup](https://docs.flutter.dev/platform-integration)
- [Flutter internationalization](https://docs.flutter.dev/ui/internationalization)
- [SQLite package and native/web support](https://pub.dev/packages/sqlite3)
- [Printing package](https://pub.dev/packages/printing)
- [SQLite web runtime release](https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.5.2)
- Noto font licenses are included at `assets/fonts/LICENSE.txt`.

Product illustrations: Twemoji graphics by Twitter, Inc. and other contributors, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), from [Twemoji v16.0.1](https://github.com/jdecked/twemoji/tree/v16.0.1). The bundled images are unchanged; the full license is in `assets/products/LICENSE-GRAPHICS`.

The default app logo and launcher icons use the shopping cart PNG supplied by the store owner, originally named `vecteezy_3d-shopping-cart-icon-on-transparent-background-png_16774483.png`. The bundled copy is `assets/branding/shop-logo.png`; native and web icon assets are resized from that same supplied artwork. A custom logo uploaded in Settings takes precedence inside the app.

Panel settings is available to signed-in staff for device language and app updates.
For web releases, run `bash tool/build_web.sh` (also used by `tool/serve.sh`).
It embeds a build ID and publishes `app-update.json`; Check for updates compares
that manifest on the same server, then offers a confirmed reload. Saved local data
is retained. Finish sales and save edits before reloading. Native apps currently
require installing a new release manually; no native update server is configured.
>>>>>>> 4eac19c (Initial Flutter POS project)
