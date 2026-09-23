# biconcept

Interior estimate app for Windows and Android. Estimates, CRM, calendar, and project accounts sync to Appwrite.

## Versioning

`pubspec.yaml` holds the marketing version (`1.0.0+1` is name `1.0.0`, build `1`). Settings shows that value from the installed binary, plus the CI channel and git SHA baked in at build time.

To ship an update:

1. Bump `version:` in `pubspec.yaml` (raise the `+build` if you only need a new Android `versionCode`).
2. Tag and push: `git tag v1.0.1 && git push origin v1.0.1`
3. Codemagic (or GitHub Actions **Release**) builds the Android APK and Windows zip, then publishes a GitHub Release with `latest.json`.
4. In the app, Settings → **Check for update** / **Update app**.

Do not run both Codemagic release workflows and GitHub Actions **Release** on the same tag — they race to the same GitHub Release. Pick one.

If the GitHub repo is private, save a token with Contents read (the same GitHub token already used for data sync works). Public repos do not need a token.

## CI/CD

### Codemagic

`codemagic.yaml` at the repo root is the source of truth.

1. Sign in at [codemagic.io](https://codemagic.io) with GitHub and add this repository.
2. Open the app → **Codemagic YAML** (not Workflow Editor) so these workflows load.
3. Create the **variable groups** below (Team or Application → Environment variables). Mark secrets as **Secret**. Create the groups even if they are empty — a missing group name fails the build. `CI — analyze and test` does not import groups.

| Group | Variables | Used by |
|---|---|---|
| `appwrite` | `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_DATABASE_ID`, `APPWRITE_DEEP_LINK_SCHEME`, `RAZORPAY_KEY_ID`, `APPWRITE_API_KEY` (secret, tables write) | Android / Windows / web / schema |
| `github_credentials` | `GH_TOKEN` (secret, `repo` scope) | Upload APK/zip to GitHub Releases |
| `android_signing` | `CM_KEYSTORE` (base64 of `.jks`), `CM_KEYSTORE_PASSWORD`, `CM_KEY_PASSWORD`, `CM_KEY_ALIAS` | Signed Play/release APK |

**Workflows**

| Workflow | Trigger | What it does |
|---|---|---|
| **CI — analyze and test** | Push / PR to `main` | `flutter pub get`, `analyze`, `test` (Flutter 3.47.0) |
| **Android release APK** | Tag `v*.*.*` or Start build | Release APK, optional GitHub Release |
| **Windows release zip** | Tag `v*.*.*` or Start build | Windows zip, optional GitHub Release |
| **Web release** | Tag `v*.*.*` or Start build | `build/web.zip` |
| **Appwrite schema push** | Push to `main` when schema files change | `appwrite push tables --all --force` |

To ship:

1. Bump `version:` in `pubspec.yaml`.
2. `git tag v1.1.7 && git push origin v1.1.7`
3. Codemagic builds Android + Windows. In-app **Settings → Updates** reads the GitHub Release.

Keystore (optional). Local debug signing still works without it:

```bash
base64 -w 0 android/app/upload-keystore.jks > keystore.b64
```

Paste that into `CM_KEYSTORE`. Gradle reads `android/key.properties` only when Codemagic writes it.

### GitHub Actions

Still available as a fallback:

- **CI** — `flutter analyze` and `flutter test` on pull requests and `main`
- **Release** — on `v*.*.*` tags (or workflow dispatch), publishes Android APK + Windows zip to GitHub Releases
- **Appwrite** — pushes table schema from `appwrite.config.json` when that file changes on `main`
- **GitHub Pages** — on push to `main` (or workflow dispatch), builds Flutter web to https://manoz2201.github.io/Biconcept_inc/

Add that hostname (and `/Biconcept_inc`) under Appwrite Console → **Platforms** so web login works.

```bash
gh secret set APPWRITE_API_KEY
gh secret set CLOUDFLARE_ACCOUNT_ID
gh secret set CLOUDFLARE_API_TOKEN
```

`CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` are copied onto the `workers-ai-proxy` function (never `--dart-define` — that would ship the token in the web bundle). After setting them, run **Actions → Appwrite → Run workflow**. Settings → agent parameters is only a local override when those secrets are missing.

Local schema deploy:

```bash
appwrite client --key "$APPWRITE_API_KEY"
appwrite push tables --all --force
```

## Phase 1 — Auth, RBAC, invites

Single-firm multi-user access sits in front of the existing CRM. Calendar and estimates are unchanged; staff now sign in with Appwrite Account.

### Generate Dart code

Providers and models in this checkout are handwritten so the app analyzes on Dart 3.13. When `riverpod_generator` supports this SDK:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Environment

Copy `.env.example` and pass the values at build time:

```bash
flutter run --dart-define=APPWRITE_ENDPOINT=https://sgp.cloud.appwrite.io/v1 ^
  --dart-define=APPWRITE_PROJECT_ID=6a86a3d4001d87aa9809 ^
  --dart-define=APPWRITE_DATABASE_ID=6a86ad9300190bcdd0df
```

Deep links use the `biconcept://` scheme (`verify`, `invite`, `reset-password`). Add that scheme (and your web hostname) under Appwrite Console → **Platforms** so verification and invite redirects are allowed.

### Appwrite resources (already created on this project)

**Teams**

| Team ID | Roles |
|---|---|
| `firm_staff` | `admin`, `architect`, `accountant`, `super_admin` |
| `clients` | `client` |
| `vendors` | `vendor` |

**Tables** (same database as CRM: `6a86ad9300190bcdd0df`)

- `users` — profile + role. Read/create/update: `Role.users()`. Delete: `Role.team('firm_staff', ['admin'])`.
- `audit_logs` — append-only. Read: firm admins. Create: any signed-in user. No update/delete.

Keep `clients`, `estimates`, `company`, and `catalog` as they are.

**Function `validate-email`** (Node 18)

- Package: `@emailcheck/email-validator-js` (BSL 1.1 — confirm a commercial license before production).
- Source: `functions/validate-email`.
- Execute: `Role.users()`.
- Redeploy: `appwrite push function --function-id validate-email --activate --force`

The Flutter app only does a local syntax check (`email_validator`). MX / disposable / suggestion checks run inside this function.

### Bootstrap the first super admin

1. Create an Appwrite account for yourself (Console → Auth → Users, or sign in once from the app).
2. Add that user to team `firm_staff` as **owner** (required so they can send invites).
3. In table `users`, insert a row: `accountId` = Auth user id, `role` = `super_admin`, `emailVerified` = true, `isActive` = true.
4. Sign in from the app. Settings → **Team members** to invite architects, accountants, vendors, and clients.

Invites use `teams.createMembership`. Appwrite sends the email. The invitee opens `biconcept://invite?userId&secret&membershipId&teamId` and finishes **Register**.

Client-side RBAC (`UserRole` + `PermissionGate`) is UX only. Table permissions and team memberships enforce access on the server.

Riverpod providers are written by hand. `build_runner` / `riverpod_generator` currently cannot analyze this repo on Dart 3.13 (dot-shorthand AST). Re-run generation when the analyzer catches up:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Sessions live in `flutter_secure_storage` only. Never log passwords, tokens, or recovery secrets.

## Phase 2 — Public catalog and enquiries

Public pages (`/`, `/services`, `/portfolio`, `/team`, `/about`, `/contact`) do not require a session. Staff CRM is at `/app`. After sign-in the app opens `/app`.

Models and Riverpod providers stay handwritten (same Dart 3.13 `build_runner` limitation as Phase 1).

### Appwrite resources

**Tables** (database `6a86ad9300190bcdd0df`)

| Table | Read | Create | Update | Delete |
|---|---|---|---|---|
| `services` | `Role.any()` | `Role.team('firm_staff', ['admin'])` | same | same |
| `portfolio_items` | `Role.any()` | admin team role | same | same |
| `team_members` | `Role.any()` | admin team role | same | same |
| `enquiries` | admin + architect team roles | `Role.any()` | admin + architect | admin only |

`isActive` columns are optional with default `true` (Appwrite rejects required + default on booleans).

**Storage**

Cloud plan on this project allows **one bucket**. Portfolio covers, galleries, and team photos all use `portfolio_images`:

- permissions: `read("any")`
- fileSecurity: true
- max size: 10 MB
- extensions: jpg, jpeg, png, webp
- encryption: false
- antivirus: true

Set `APPWRITE_TEAM_PHOTOS_BUCKET=portfolio_images` if you later split buckets. Uploads still call `Permission.read(Role.any())` on each file.

**Function `validate-email`**

Execute is `any` + `users` so the public enquiry form can run MX / disposable checks. The Flutter app still never ships `@emailcheck/email-validator-js`.

### SEO

`flutter_easy_seo` (Apache 2.0) wraps public pages. `EasySEOManager.instance.init` runs in `main.dart`. Regenerating `sitemap.xml` / HTML snapshots is a CI or scheduled-function step after catalog edits — not done at runtime in the CRM.

### Enquiry rate limit

The contact form keeps a 60-second cooldown in `SharedPreferences` (`enquiry.lastSubmitAt`). Pair this with an Appwrite rate limit on the `enquiries` table if abuse appears.

## Phase 3 — Client portal, service requests, quotations

Staff still land on `/app`. Clients land on `/client/dashboard`. Hitting `/admin/*` or `/app` as a client redirects to the portal; staff hitting `/client/*` go to `/admin/requests` (accountants to `/admin/quotations`).

### Cloud plan limits

This Appwrite project is on a **12-table** plan. `service_requests` and `service_request_messages` were created. A dedicated `quotations` table is **not** available (`table_limit_exceeded`). Adding a large `quotationsJson` column on `service_requests` also failed (`column_limit_exceeded`).

**Workaround:** quotation documents are stored as rows in `service_request_messages` with `senderRole = quotation`. The JSON payload lives in `message` (varchar 4000). Chat UIs skip those rows. Numbering still uses Appwrite `$sequence` on that row: `QT-{year}-{sequence padded to 3}`. When the plan allows a 13th table, migrate to `quotations` without changing the Dart repository interface.

The plan also allows **one storage bucket**. Client files reuse `portfolio_images` (`Env.clientUploadsBucket`). Bucket permissions are `read("users")` + `create("users")`, `fileSecurity: true`, 25 MB, extra office/CAD extensions. **Public catalog images keep working via file-level `Permission.read(Role.any())`** set at upload. Client attachments use document-style file permissions (`Role.user(clientId)` + `Role.team('firm_staff')`), never `Role.any()`.

### Tables

| Table | Notes |
|---|---|
| `service_requests` | Row security on. `clientId` is the **Auth user id** (needed for `Role.user(clientId)`). |
| `service_request_messages` | Request chat + quotation records. Realtime: `databases.{db}.tables.service_request_messages.rows`. |
| `chat_messages` | Direct local-first chat. Row security. Sender + receiver only. |

Every `createRow` for these tables passes document permissions including `Permission.read(Role.user(clientId))` and `Permission.read(Role.team('firm_staff'))`.

### PDF

Flutter generates PDFs with `pdf` + `printing` (`QuotationPdfService`). Optional Appwrite Function `generate-quotation-pdf` is in `functions/generate-quotation-pdf` (Node 18, pdfkit). Deploy when the function quota allows; the app falls back to local PDF if execution fails.

### Audit events

`service_request_created`, `service_request_status_changed`, `service_request_assigned`, `enquiry_converted_to_request`, `quotation_created`, `quotation_sent`, `quotation_viewed`, `quotation_approved`, `quotation_rejected`, `quotation_revision_requested`, `quotation_revision_created`, `message_sent`.

### Phase 4 — Projects, tasks, timesheets, documents, change requests

The cloud plan still cannot host seven extra tables. Phase 4 uses one row-secured `projects` table. Scalar fields live on the row. Milestones, tasks, timesheets, documents, change requests, and the activity feed live in `workspaceJson` (`mediumtext`). Repository interfaces stay split so a later migration to dedicated tables does not change the UI.

Project numbers: optional Function `functions/generate-project-number` (`PRJ-{year}-{sequence}`). The app falls back to Appwrite `$sequence` on the project row, same idea as quotation numbers. Deploy only if you want the Function path; create still works without it.

Project files reuse `portfolio_images` (`Env.clientUploadsBucket`) with file-level permissions (`Role.user(clientId)` + staff). Upload cap for project files is 50 MB. Do **not** use `Role.any()` on project files.

| Surface | Route |
|---|---|
| Staff list / detail | `/admin/projects`, `/admin/projects/:id` (`Permission.projectView`) |
| Convert from approved request | Admin request detail → **Convert to Project** (`Permission.projectConvert`) |
| Timesheets | `/admin/timesheets`, `/admin/timesheets/approval` |
| Change requests | `/admin/change-requests` |
| Client | `/client/projects`, `/client/projects/:id` |

Task views on a project: Kanban (drag between columns), list, and calendar. Progress is `completed milestone weights / total weights × 100`.

Audit events include `project_created`, `project_status_changed`, `service_request_converted_to_project`, `milestone_*`, `task_*`, `timesheet_*`, `document_*`, and `change_request_*`.

### Phase 5 — Vendors, RFQs, purchase orders, bills

The plan still cannot host nine extra tables. Phase 5 uses two row-secured tables:

- `vendors` — profile scalars plus `workspaceJson` for rates, ratings, quotes, POs, bills, payments, and project assignments
- `rfqs` — RFQ scalars plus `workspaceJson` for invited recipients

Vendor quotes live on the **vendor** row, not the RFQ row, so a vendor who can read an invited RFQ never sees another vendor's prices. RFQ document permissions add `Role.user(vendorUserId)` only for invited portal accounts.

Files reuse `portfolio_images` (`Env.clientUploadsBucket`) with a 25 MB KYC/bill cap. Do **not** use `Role.any()` on vendor files.

Optional Functions: `functions/generate-rfq-number`, `functions/generate-po-number`. Create still stamps `RFQ|PO-{year}-{sequence}` from `$sequence` when the Function is missing.

| Surface | Route |
|---|---|
| Staff vendors | `/admin/vendors` (`Permission.vendorView`) |
| RFQs / compare / award | `/admin/rfqs` |
| Purchase orders | `/admin/purchase-orders` |
| Bills / payments | `/admin/vendor-bills`, `/admin/vendor-payments/new` |
| Project assignment | `/admin/projects/:id/vendors` |
| Vendor portal | `/vendor/dashboard` (`Permission.vendorPortalAccess`) |

Vendor users land on `/vendor/dashboard` after login. Link a vendor profile to the Auth user via `userId` so portal quotes, POs, and bills stay scoped to that row.

### Phase 6 — Invoices, GST, payments, and accounting

The plan still cannot host eight extra tables. Phase 6 uses two row-secured tables:

- `invoices` — invoice scalars plus `itemsJson` and `workspaceJson` for payments, credit notes, and debit notes
- `finance` — singleton row `$id: firm` for GST settings, with `workspaceJson` for tax rates, expenses, ledger, GST returns, bank lines, and FY number series

Client-visible money lives on the **invoice** row so `Permission.read(Role.user(clientId))` keeps one client from seeing another. Expenses and the ledger stay on the staff-only finance row.

Invoice numbers follow Rule 46(b): `INV/YYYY-YY/NNNN` (16 characters). The series resets on 1 April via a counter in `finance.workspaceJson`. Optional Functions `generate-invoice-number`, `generate-credit-note-number`, and `generate-debit-note-number` can stamp the same format from `$sequence`. Create still works without them.

Files reuse `portfolio_images` (25 MB). No `financial_documents` bucket. Do **not** use `Role.any()` on invoice or expense files.

Razorpay: Key ID is `--dart-define=RAZORPAY_KEY_ID=…` only. The Key Secret belongs in Function env (`create-razorpay-order`, `verify-razorpay-signature`, `razorpay-webhook`). The app records manual / UPI / bank payments without those Functions. Do not put the secret in Flutter.

GST: intra-state = CGST + SGST (`taxable × rate / 200` each). Inter-state = IGST (`taxable × rate / 100`). Round-off is stored separately. Amount in words uses Indian numbering.

| Surface | Route |
|---|---|
| Accountant dashboard | `/admin/accounting` |
| Invoices / payments / notes | `/admin/invoices`, `/admin/payments`, `/admin/credit-notes` |
| Expenses | `/admin/expenses`, `/admin/expenses/approval` |
| Ledgers | `/admin/ledger/general`, `/admin/ledger/client/:id` |
| GST | `/admin/gst/settings`, `/admin/gst/gstr1`, `/admin/gst/gstr3b` |
| Client invoices | `/client/invoices`, `/client/payments` |

Issued invoices cannot be edited. Use a credit note. Ledger rows are append-only. Filing a GST return or closing a financial year locks that period.

### Phase 7 — GST audit, TDS, e-invoice, e-way bill, forecasting

The plan cannot host thirteen extra collections. Phase 7 uses one row-secured table:

- `compliance` — singleton `$id: firm` with `workspaceJson` for ITC ledger, ITC reversals, GSTR-2B imports, TDS, GST TDS, e-invoices, e-way bills, GSTR-9, GSTR-9C, budgets, and forecasts

GSTR-2B JSON still uploads to `portfolio_images` (25 MB, staff-only file permissions). There is no `gst_documents` bucket.

IRP and E-way bill Client ID / Secret / username / password stay in Function env (`generate-einvoice-irn`, `generate-ewaybill`). The Flutter settings screen only stores sandbox/production hint and auto-generate. Credentials are never written to Appwrite rows.

Matching, TDS rates, GST TDS, e-way validity, GSTR-9 drafts, and Form 16A PDFs run in Dart so the screens work without Functions. Optional Functions: `gstr2b-reconcile`, `generate-einvoice-irn`, `generate-ewaybill`, `tds-calculate`, `generate-tds-certificate`, `gst-tds-calculate`.

Rules encoded in `compliance_math.dart`:

- ITC claim requires a GSTR-2B match
- Rule 37 / 42 / 43 reversals
- TDS 194C 1%/2%, 194J 2%/10%, 194I 2%/10% with statutory thresholds
- GST TDS 2% above ₹2,50,000
- E-invoice IRN via Function; cancel within 24 hours
- E-way bill above ₹50,000; 1 day / 200 km (ODC 1 day / 20 km); 180-day goods rule
- GSTR-9C self-certification above ₹5 crore

| Surface | Route |
|---|---|
| Audit dashboard | `/admin/audit` |
| ITC / GSTR-2B / GSTR-9 | `/admin/audit/itc-ledger`, `/admin/audit/gstr2b`, `/admin/audit/gstr9` |
| TDS / GST TDS | `/admin/tds`, `/admin/gst-tds` |
| E-invoice / e-way bill | `/admin/e-invoices`, `/admin/e-way-bills` |
| Budgets / forecasts | `/admin/budgets`, `/admin/forecasts` |

Do not run `dart run build_runner` — providers stay handwritten.

### Phase 8 — Platform operations

The plan cannot host twelve extra collections or two new buckets. Phase 8 uses one row-secured table:

- `platform` — singleton `$id: firm` with `workspaceJson` for currencies, exchange-rate history, payment schedules, notification preferences/log, integration configs/sync logs, branding, backup jobs/history, analytics events, and KPI metrics

Logos and backup zip files reuse `portfolio_images` (25 MB, staff-only file permissions). There is no `branding_assets` or `backups` bucket.

OAuth secrets, FCM server keys, and backup AES keys stay in Function env (`integration-sync`, `send-push-notification`, `create-backup`). Flutter never stores those fields. Integration `config` is stripped of `clientSecret`, `accessToken`, `refreshToken`, `apiKey`, and similar keys before save.

Push uses the existing local notification plugin. The inbox, preferences, quiet hours, and deep links (`biconcept://invoices/:id`, `biconcept://payment-schedules/:id`, `biconcept://notifications`) work without Firebase. Optional Function: `send-push-notification`.

Money is a value object (`amount` + `Currency`). Exchange rates are units of base (INR) per 1 foreign unit. Historical rates stay in the packed workspace. The base currency cannot be deactivated.

Payment schedules use `PS/YYYY-YY/NNNN`. Approval requires typing `APPROVE`. Restore requires typing `RESTORE`. Processing marks linked vendor bills paid in the vendor workspace; no bank API is called from Flutter.

Optional Functions: `sync-exchange-rates`, `process-payment-schedule`, `integration-sync`, `create-backup`, `restore-backup`, `compute-kpi-metrics`, `send-push-notification`. Screens work undeployed.

Caching is in-memory with per-key TTLs (not Hive). Offline actions queue in memory. Tally export is XML generated in Dart.

| Surface | Route |
|---|---|
| Currencies / converter | `/admin/currencies`, `/admin/currency-converter` |
| Payment schedules | `/admin/payment-schedules`, `/admin/payment-schedules/approval`, `/admin/payment-schedules/batch` |
| Integrations | `/admin/integrations` |
| Branding | `/admin/branding` |
| Backups | `/admin/backups`, `/admin/backups/restore` |
| Analytics / KPIs | `/admin/analytics`, `/admin/analytics/kpis`, `/admin/analytics/cohorts` |
| Notifications | `/notifications`, `/notifications/preferences` |

Do not run `dart run build_runner` — providers stay handwritten.

### Phase 9 — intelligence (packed `intelligence` table)

AI, OCR, site photos, WhatsApp, predictive alerts, and multi-firm records live in one TablesDB row (`intelligence` / `$id: firm`) as `workspaceJson`. Conceptual collections (`ai_conversations`, `ai_suggestions`, `site_photos`, `ocr_documents`, `whatsapp_messages`, `tenants`, `tenant_subscriptions`, embeddings) are packed JSON — the Cloud plan cannot host a new collection per feature.

The default tenant is `default_firm` (BiConcept, Pro). Existing Phase 1–8 tables are **not** migrated with a `tenantId` column. Isolation is enforced in the intelligence repository (`currentTenantId`). Only `UserRole.superAdmin` can list extra tenant records or switch firms. Do not add `tenantId` to invoices, projects, or other live tables.

Uploads reuse `portfolio_images` (25 MB). There are no `ai_documents` or `site_photos` buckets. Voice is a dictate/paste dialog — audio is not stored and `speech_to_text` / ML Kit / OpenAI / WhatsApp client SDKs are not added. Secrets (OpenAI, WhatsApp token, Vision) stay in Function env only. WhatsApp settings persist phone number ID and webhook URL.

Optional Functions (screens work undeployed with local heuristics): `ai-quotation-suggest`, `ai-cost-estimate`, `ai-timeline-predict`, `ai-lead-score`, `ai-ocr-extract`, `ai-image-analyze`, `ai-natural-language-query`, `ai-embed-document`, `ai-semantic-search`, `whatsapp-send-template`, `whatsapp-webhook`, `tenant-provision`, `tenant-usage-tracker`.

Plan limits: AI 100/day Basic, 1000/day Pro, unlimited Enterprise. OCR 50/500/unlimited per month. WhatsApp 100/1000/unlimited per month.

| Surface | Route |
|---|---|
| AI assistant / suggest / search / NLP | `/ai/assistant`, `/ai/quotation-suggest`, `/ai/cost-estimate`, `/ai/timeline-predict`, `/ai/lead-score`, `/ai/semantic-search`, `/ai/natural-language-query` |
| Site photos | `/projects/:id/photos`, `/image-analysis` |
| OCR | `/ocr/upload`, `/ocr/documents` |
| WhatsApp | `/whatsapp/messages`, `/whatsapp/settings` |
| Multi-firm | `/multi-firm/dashboard`, `/tenant-switcher` |
| Predictive | `/predictive/risk`, `/predictive/alerts`, `/predictive/projects/:id/health` |

Do not run `dart run build_runner` — providers stay handwritten.

### Phase 10 bridge


## Local-first chat

Direct messages are **local-first**. The UI never reads Appwrite rows for rendering. Every send, realtime event, and catch-up write lands in the local store first; screens watch Drift-shaped tables `local_messages`, `conversations`, and `sync_state`.

| Surface | Route |
|---|---|
| Staff | `/chat`, `/chat/:conversationId` (`Permission.messageView`) |
| Client | `/client/chat` (Messages tab). `/client/messages` is still the service-request inbox. |

### Sync

- **Outbox:** pending rows upload to Appwrite `chat_messages` (`rowId` = client UUID v4 `localId`, max 36 chars).
- **Realtime:** `databases.{db}.tables.chat_messages.rows`
- **Catch-up:** on launch, `connectivity_plus` reconnect, and pull-to-refresh (`createdAt` cursor)
- **Status:** `pending` → `sent` → `delivered` → `read`. After **5** failed attempts the row is `failed` and a Retry button resets it. Backoff is 1s, 2s, 4s, 8s, 16s, then 60s if retries continue.
- **Permissions:** document-level `Role.user(sender)` + `Role.user(receiver)` only (`directMessagePermissions`)
- **Attachments:** bytes saved locally, uploaded to `portfolio_images` with the same sender/receiver file permissions, then `localPath` is replaced by `fileId`

Dart 3.13 still breaks `build_runner` / Drift codegen in this repo, so providers stay handwritten. Table SQL is in `lib/features/chat/data/local/tables/`. Do not run `dart run build_runner` for this feature. Service-request `MessageThread` is unchanged.

