# SRS Gap Analysis (Smart Money App)

Scope: Step 0 audit only (no code changes). Stack target: BLoC + sqflite, auth endpoints `/api/Auth/*`.

## 1) Project Structure (current)
- `lib/core/` for constants, database, DI, network, services, theme, utils
- `lib/features/<feature>/data|domain|presentation/` with BLoC, repositories, datasources
- DI via `lib/core/di/injection_container.dart`

## 2) Current Mapping: SRS → Existing Modules

### 2.1 Auth + Token (SRS §2)
- API client: `lib/core/network/api_client.dart` (Dio + interceptor attaches single token)
- Auth remote datasource: `lib/features/auth/data/datasources/auth_remote_datasource.dart`
  - Uses `/auth/login`, `/auth/register`, `/user/me` (lowercase, missing SRS endpoints)
- Auth local datasource: `lib/features/auth/data/datasources/auth_local_datasource.dart` (SQLite `user` table)
- Auth models: `lib/features/auth/data/models/user_model.dart` (includes `AuthResponseModel`)
- Auth bloc: `lib/features/auth/presentation/bloc/auth_bloc.dart` (events: check/login/register/logout)
- Token storage: `flutter_secure_storage` used in `ApiClient` with key `AppConstants.tokenKey`

### 2.2 Role/Freemium/Entitlements (SRS §3, §5)
- User entity has `role` + `isPremium`: `lib/features/auth/domain/entities/user.dart`
- App constants: `AppConstants.maxFreeWallets = 2` in `lib/core/constants/app_constants.dart`
- No `EntitlementService` or `RoleGuard` found

### 2.3 SQLite / Offline-first (SRS §4, §6)
- DB schema: `lib/core/database/local_database.dart` (version 5)
  - Tables: `wallets`, `categories`, `transactions`, `budgets`, `groups`, `group_members`, `user`, `sync_queue`
  - Columns include `id`, `last_updated_at`, `is_synced`, `is_deleted` (not uniform across all tables)
  - Indexes: transactions wallet/category/date, budgets category, categories parent, group members group, transactions group
- Local datasources:
  - Wallet: `lib/features/wallet/data/datasources/wallet_local_datasource.dart`
  - Category: `lib/features/category/data/datasources/category_local_datasource.dart`
  - Group: `lib/features/group/data/datasources/group_local_datasource.dart`
  - Auth: `lib/features/auth/data/datasources/auth_local_datasource.dart`
- Transactions and reports: remote-only repositories
  - `lib/features/transaction/data/repositories/transaction_repository_impl.dart`
  - `lib/features/reports/data/repositories/report_repository_impl.dart`

### 2.4 Sync Engine (SRS §6)
- Wallet repository has a `syncWallets()` method (push unsynced + pull full refresh)
- No centralized `SyncService`, `SyncBloc/Cubit`, or `sync_metadata` table
- `sync_queue` table exists but not wired to logic

### 2.5 Feature Gating (SRS §5)
- Wallet UI: `lib/features/wallet/presentation/widgets/add_wallet_dialog.dart` (no gating)
- Transactions: OCR service exists in `lib/core/services/ocr_service.dart`, but gating is not enforced in UI/repo
- Reports: remote-only + no local computed report
- Group: local/remote exist but no premium gating for create
- Export: `ReportRepository.exportReport` hits remote, no gating
- Ads: no config-based enable/disable in UI

## 3) Gaps & Priority Fixes

### P0 — Auth endpoint + token refresh correctness
- **Gap:** Auth endpoints are `/auth/*` (lowercase) vs required `/api/Auth/*` endpoints.
- **Gap:** No refresh token model/storage; interceptor only deletes access token on 401.
- **Gap:** No `forgot-password` flow, no `AuthResponse` fields for access/refresh/expiry.
- **Gap:** AuthBloc lacks `ForgotPasswordSubmitted`, `AppStarted` event; no profile fetch after login/register.

### P0 — Offline-first for Transactions/Reports
- **Gap:** Transactions are remote-only; no local datasource or offline-first insert.
- **Gap:** Reports are remote-only; should be computed locally from SQLite.
- **Gap:** Soft delete for transactions is missing in repository flows.

### P1 — Sync Engine (incremental, last_updated_at)
- **Gap:** No `sync_metadata` table or `lastSyncAt` stored in DB.
- **Gap:** No incremental pull/push by `last_updated_at`, no merge rules.
- **Gap:** Wallet sync currently deletes all local wallets on pull.

### P1 — Entitlements + Role Guard
- **Gap:** No `EntitlementService` or `RoleGuard`.
- **Gap:** UI and repositories do not enforce gating consistently.
- **Gap:** No DEV flags `DEV_AUTO_PREMIUM` / `DEV_FORCE_FREE`.

### P2 — SQLite schema consistency
- **Gap:** Not all tables use `last_updated_at` + `is_synced` + `is_deleted` consistently.
- **Gap:** `user` table lacks `last_updated_at`, `is_synced`, `is_deleted`.
- **Gap:** `categories` uses `created_at/updated_at` rather than single `last_updated_at`.

## 4) Proposed Incremental Refactor Plan (small PRs)
1. **Auth contracts + token refresh**
   - Add request/response models; update endpoints.
   - Add refresh-token flow in `ApiClient` interceptor.
   - Expand AuthBloc events/states and fetch profile after auth.
2. **Entitlements + RoleGuard**
   - Add `EntitlementService`, `RoleGuard`, and dev flags.
   - Enforce gating in repositories + BLoCs (not just UI).
3. **SQLite migrations + schema normalization**
   - Add missing columns and indexes.
   - Introduce `sync_metadata` table.
4. **Offline-first Transactions**
   - Add local datasource + repository merge.
   - Soft delete + `is_synced` handling.
5. **Reports from SQLite**
   - Add local report queries and gating by plan.
6. **Sync Engine**
   - Add SyncCubit/Service with pull-merge-push, scheduled background sync.

## 5) Checklist (Step 0 Output)
- [x] Folder structure + feature layout mapped
- [x] BLoC/repository/datasource scan
- [x] Network client and token storage reviewed
- [x] SQLite schema/migrations reviewed
- [x] Gaps and priority fixes listed


