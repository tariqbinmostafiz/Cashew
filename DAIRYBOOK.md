# DairyBook (Cashew fork) — implementation notes

Branch: `dairy-implementation` (base commit `15a1ac2`). `.github/workflows/apk.yml`, Flutter 3.22.3, Java 17 and all
`pubspec.yaml` dependency versions are unchanged.

## What was added
New code lives in `budget/lib/farm/`:
- `farmTables.dart` – 6 new Drift tables (schema v47): Animals, Customers, MilkRecords, MilkSales, CustomerPayments, MilkUsageLogs.
- `farmRepo.dart` – all reads/writes (atomic via `database.transaction`).
- `farmCategories.dart` – dairy system categories (fixed pks `dairy_*`), extra wallets, one-time defaults.
- `farmStrings.dart` – English/Bengali strings (`ft(context, key)`), independent of the easy_localization CSV pipeline.
- Pages: animals, milk (day view, entry grid, usage), sales, customers (ledger, payments, statement share), monthly report, home dashboard.

## Changes to existing files (small, targeted)
- `database/tables.dart`: table list, `schemaVersionGlobal = 47`, migration: generated steps capped at v46 + `createTable` for the 6 new tables (no generated file hand-edited).
- `database/platform/native.dart`: pre-migration safety copy (`db.pre-migration-*.bak`), safe restore (validate, `db.pre-restore-*.bak`, temp file + rename).
- `widgets/importDB.dart` (validation before restore), `widgets/exportDB.dart` (file name `dairybook-*.sqlite`).
- Navigation: `navBarIconsData.dart` (milk/sales/animals; `goalsDetails` index fixed 18→15), `navigationFramework.dart` (3 pages appended at 18–20, farm init at startup), `navigationSidebar.dart`, `defaultPreferences.dart`, `settingsPage.dart` (farm tools block), `homePage.dart` (dashboard).
- `defaultCategories.dart` (dairy categories for fresh installs), Android app name `DairyBook`, translation JSON (3 nav label keys).

## Money / milk rules implemented
- Litres never go into `Transactions.amount`.
- A sale creates no money. A payment = one income Transaction (category `dairy_milk_sales`) + one `CustomerPayments` link row, created atomically; `UNIQUE(transactionFk)` prevents double attribution.
- Customer balance = opening balance + non-cancelled sales − payments.

## NOT verified (no Flutter/pub.dev access in the authoring environment)
Nothing was compiled, analyzed or run by the author. Only checked: Dart syntax of all touched files (`dart format`), the backup-validation logic against a real SQLite file.
Please run the existing `apk.yml` and send me any compiler error; expect a few small fixes.

## Known limitations / not in this release
Feed inventory, veterinary, breeding, reminders, scheduled auto-backup, CSV per module, per-cow feed use, Bengali digits in output.
Bottom bar is Home · Milk · Sales · More (animals/customers/reports/transactions are in More and on Home).
Photos are stored as files and are not part of the `.sqlite` backup. Backup restore checks header, version and table names but does not run `PRAGMA integrity_check`.
Existing installs: nav shortcuts switch to Milk/Sales after the first start (applied on next launch). Dairy category names are stored in the language active at first start.
`drift_schemas/` and `schema_versions.dart` are not regenerated for v47 (see migration note above); run `drift_dev schema dump` later if schema tooling is wanted.
