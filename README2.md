# Smart Money – Technical README (v2)

This document mirrors the current `README.md` (v3) and adds a concise checklist of gaps/fixes needed to harden the product.

## 1. Overview
Smart Money is an offline-first personal finance suite:
- Flutter client (`money_manager_app`) for wallets, transactions, budgets, reports, and group spending.
- ASP.NET Core 8 backend (`MoneyManager-master`) with SQL Server, Identity, JWT, SignalR, and hybrid OCR (Gemini/Groq).
- Premium: OCR receipt scan, exports, ad-free; Free: limited wallets + ads.

## 2. Architecture
- **Client**: Feature-first (data/domain/presentation per feature) with GetIt DI, BLoC state, SQLite cache, sync queue (wallet → category → transaction → budget → group), SignalR client for groups, imperative `Navigator` routing.
- **Server**: Layered solution (API → Application → Domain → Infrastructure); EF Core; SignalR GroupHub; JWT auth; Swagger.
- **Startup (client)**: `main.dart` → `di.initDependencies()` → Ads init → `AuthBloc(AppStarted)` → Splash → Login or Home; on auth, `SyncService.initialize()` + sync banner.

## 3. Tech Stack
- **Mobile**: Flutter/Dart 3.6, flutter_bloc, get_it, dio, sqflite, flutter_secure_storage, signalr_netcore, google_mobile_ads, in_app_purchase, image_picker, fl_chart, share_plus/open_filex, connectivity_plus, uuid.
- **Backend**: ASP.NET Core 8, C# 12, EF Core 8, SQL Server, Identity + JWT, SignalR, Swashbuckle, Gemini/Groq OCR.

## 4. Core Features
- Auth: email/password, refresh, email verification, Google sign-in, optional 2FA/OTP, session expiry handling.
- Wallets/Categories: CRUD, seeded system categories, balances, offline queue.
- Transactions: calculator add flow, wallet/category/group selection, receipt upload (Cloudinary), OCR autofill (premium), offline temp IDs.
- Budgets: recurring/date-ranged, category/overall, warnings/exceeded, analytics/history/suggestions.
- Groups: invite/join/leave, roles, members, group transactions, real-time SignalR updates.
- Reports: summary, by-category, by-time, quick/monthly, export (Excel/PDF).
- Sync: auto/periodic on connectivity, pending banner/toasts, FK-safe ordering.
- Monetization: ads + frequency limiter; in-app purchases for premium.

## 5. Data & API
- Client: ApiClient (Dio) with JWT injection + refresh; exceptions mapped to AppException; AuthEventBus for global errors.
- Storage: SQLite tables mirror server (wallets, categories, transactions, budgets, groups, group_members, user, notifications, user_settings, sync_queue).
- Server endpoints (high level): Auth, User, Wallet, Category, Transaction (incl. OCR, group), Budget, Group, Report, Sync, Subscription; SignalR hub `/hubs/group`.

## 6. State & Navigation
- BLoCs per feature (`AuthBloc`, `WalletBloc`, `TransactionBloc`, `BudgetBloc`, `GroupBloc`, `ReportBloc`, `ProfileBloc`, `CategoryBloc`).
- Theme via `ThemeService` (ChangeNotifier).
- Navigation: imperative `Navigator.push`; GoRouter is a dependency but unused.

## 7. Setup (quick)
- **Backend**: `.NET 8` → `dotnet restore` → `dotnet ef database update --project MoneyManager.API` → `dotnet run --project MoneyManager.API` (set connection string + OCR keys).
- **Client**: Flutter 3.24+ → `flutter pub get` → set `pcIpAddress/baseUrl` in `lib/core/constants/app_constants.dart` → `flutter run`. Emulator uses `10.0.2.2`.

## 8. Gaps / To Fix (Action List)
1) **Secrets in client**: Cloudinary apiKey/apiSecret hardcoded in `cloudinary_service.dart` — move to backend-signed upload or env-configured secure storage.  
2) **Navigation**: GoRouter is unused; either remove dependency or adopt for structured routing and deep links.  
3) **Notifications**: `NotificationService` is stubbed (flutter_local_notifications commented); implement or remove.  
4) **Tests**: No automated tests for blocs/repos/sync; add unit/widget tests and API contract tests.  
5) **i18n**: Messages largely Vietnamese; add localization (intl l10n) and language toggle.  
6) **Security**: Verify token refresh race handling on client; ensure HTTPS/issuer/audience validation in API (currently disabled in Program.cs).  
7) **Sync robustness**: Add conflict resolution UI and backoff/retry; ensure temp ID replacement covers all FK cases (budgets/groups not in order list).  
8) **Performance**: Optimize large transaction lists (pagination UI) and image upload compression strategy.  
9) **Config management**: Document required appsettings (Gemini/Groq keys, Google client IDs) and avoid dev defaults in production.  
10) **Ads/Premium**: Guard ad display when premium; verify purchase restore flows on iOS/Android.  
11) **Data export**: Ensure client surfaces report export endpoints; currently only backend listed.  
12) **AppConstants**: Warn users to set `pcIpAddress` per environment; consider using flavor-based configs.  
13) **Backend CORS/HTTPS**: Confirm CORS policy and enforce HTTPS in production.  
14) **Logging/Monitoring**: Add crash/analytics on client and structured logging on API (Serilog/Application Insights).  
15) **Privacy**: Remove or encrypt locally cached user table if multiple accounts can sign in on same device.
16) **Limit wallet**: litmit below 3 wallet for freemium user


## 9. Key Files (unchanged)
- Client: `lib/main.dart`, `core/di/injection_container.dart`, `core/network/api_client.dart`, `core/database/local_database.dart`, `core/sync/sync_queue_processor.dart`, `core/services/sync_service.dart`, `features/transaction/presentation/screens/add_transaction_screen.dart`.
- Server: `MoneyManager.API/Program.cs`, `Controllers/*`, `Infrastructure/Data/Context/MoneyManagerDbContext.cs`, `Infrastructure/Data/Migrations/*`, `API/Hubs/GroupHub.cs`.

## 10. Summary
Smart Money couples a Flutter offline-first app with a .NET 8 API and SignalR. The current stack is production-capable but needs the above fixes (secrets, navigation clarity, notifications, tests, security hardening) before release.
