# Smart Money App

A full-stack personal finance management application with AI-powered receipt scanning, real-time group expense sharing, and comprehensive financial analytics.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Key Features](#key-features)
5. [Technical Highlights](#technical-highlights)
6. [Project Structure](#project-structure)
7. [Getting Started](#getting-started)
8. [API Documentation](#api-documentation)
9. [Database Schema](#database-schema)

---

## Overview

Smart Money is a cross-platform mobile application designed to help users track personal and group expenses, manage multiple wallets, and gain insights through visual analytics. The application follows an **offline-first architecture** with background synchronization, ensuring seamless user experience regardless of network connectivity.

### Business Model

- **Free Tier**: Basic features with limited wallets (max 2), current month reports
- **Premium Tier**: Unlimited wallets, AI receipt scanning, group fund management, Excel/PDF export

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mobile Client                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Flutter   │  │   SQLite    │  │   Secure Storage        │  │
│  │   (Dart)    │  │  (Offline)  │  │   (Tokens/Credentials)  │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└─────────┼────────────────┼─────────────────────┼────────────────┘
          │                │                     │
          │    REST API    │   Sync Service      │
          ▼                ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Backend Server                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  ASP.NET    │  │  SignalR    │  │   AI/OCR Service        │  │
│  │  Core 8.0   │  │   Hub       │  │   (Gemini/Groq API)     │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
│         │                │                     │                 │
│         ▼                ▼                     ▼                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              SQL Server Database                             ││
│  │    (Entity Framework Core + Identity)                        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Clean Architecture (Backend)

```
MoneyManager.API           → Controllers, Middleware, Configuration
MoneyManager.Application   → DTOs, Interfaces, Services (Business Logic)
MoneyManager.Domain        → Entities, Enums, Domain Models
MoneyManager.Infrastructure → Data Access, External Services, Migrations
```

### Feature-First Architecture (Mobile)

```
lib/
├── core/                  → Shared utilities, constants, DI
├── features/
│   ├── auth/             → Authentication module
│   ├── wallet/           → Wallet management module
│   ├── transaction/      → Transaction module
│   ├── category/         → Category module
│   ├── reports/          → Analytics & Reports module
│   ├── group/            → Group fund module
│   └── settings/         → Settings & Profile module
└── main.dart
```

---

## Technology Stack

### Mobile Application (Flutter)

| Category | Technology | Purpose |
|----------|------------|---------|
| Framework | Flutter 3.6+ | Cross-platform UI |
| Language | Dart | Application logic |
| State Management | flutter_bloc | Reactive state management with BLoC pattern |
| Dependency Injection | get_it | Service locator pattern |
| Local Database | sqflite | SQLite for offline-first storage |
| Secure Storage | flutter_secure_storage | Encrypted storage for tokens |
| HTTP Client | dio | REST API communication |
| Real-time | signalr_netcore | WebSocket for live updates |
| Charts | fl_chart | Interactive pie/bar charts |
| Navigation | go_router | Declarative routing |
| Code Generation | freezed, json_serializable | Immutable models, JSON parsing |
| Image Handling | image_picker, cached_network_image | Camera/gallery access, image caching |
| File Operations | path_provider, share_plus, open_filex | File system access, sharing |
| Networking | connectivity_plus | Network status monitoring |

### Backend (ASP.NET Core)

| Category | Technology | Purpose |
|----------|------------|---------|
| Framework | ASP.NET Core 8.0 | Web API framework |
| Language | C# 12 | Server-side logic |
| ORM | Entity Framework Core 8.0 | Database access and migrations |
| Database | SQL Server | Relational data storage |
| Authentication | ASP.NET Core Identity | User management, password hashing |
| Authorization | JWT Bearer Tokens | Stateless authentication |
| Real-time | SignalR | WebSocket communication |
| Excel Export | ClosedXML | Generate .xlsx reports |
| API Documentation | Swashbuckle (Swagger) | Interactive API docs |

### AI/ML Services

| Service | Provider | Purpose |
|---------|----------|---------|
| OCR/Receipt Scanning | Google Gemini API | Primary AI for receipt analysis |
| Fallback OCR | Groq API | Backup when Gemini quota exceeded |
| Image Processing | Google Cloud Vision | Text extraction from images |

---

## Key Features

### 1. Authentication & Security
- Email/Password authentication with ASP.NET Core Identity
- JWT-based stateless authentication (Access Token + Refresh Token)
- Automatic token refresh mechanism
- Secure credential storage on device
- Role-based access control (User/Premium/Admin)

### 2. Multi-Wallet Management
- Support for multiple wallet types (Cash, Bank, E-wallet)
- Real-time balance calculation
- Transfer between wallets
- Currency support (VND)

### 3. Transaction Management
- Income/Expense tracking with categories
- Custom category creation with icons
- Date-based transaction organization
- Receipt image attachment
- Group expense sharing

### 4. AI-Powered Receipt Scanning (Premium)
- Camera/Gallery image capture
- Automatic text extraction using AI (Gemini/Groq)
- Intelligent field parsing (amount, date, merchant, items)
- Auto-fill transaction form
- Hybrid AI provider with automatic fallback

### 5. Financial Analytics & Reports
- Interactive Pie Chart (expense by category)
- Bar Chart (income vs expense over time)
- Time-based filtering (Week/Month/Custom)
- Export to Excel (.xlsx) with formatted styling
- Summary statistics (total income, expense, balance)

### 6. Group Fund Management (Premium)
- Create groups with invite codes
- Real-time transaction sync via SignalR
- Shared expense tracking
- Member management

### 7. Budget Management
- Category-based budget limits
- 80% threshold warnings
- Visual progress indicators

### 8. Offline-First Architecture
- Full functionality without internet
- Background synchronization
- Conflict resolution with timestamp-based merge
- Incremental sync using LastUpdatedAt

---

## Technical Highlights

### Offline-First Data Synchronization

```
Sync Strategy: Pull → Merge → Push

1. PULL: Fetch server changes since last sync (WHERE LastUpdatedAt > @lastSync)
2. MERGE: Resolve conflicts using "last write wins" strategy
3. PUSH: Upload local changes (WHERE IsSynced = false)

Sync Triggers:
- App startup
- Manual refresh
- Background fetch (every 15 minutes)
- Network connectivity restored
```

### Database Design Principles

```
1. GUID Primary Keys: Client-generated IDs prevent conflicts
2. Soft Delete: IsDeleted flag instead of physical deletion
3. Sync Metadata: LastUpdatedAt, IsSynced columns on all tables
4. Audit Trail: CreatedAt, UpdatedAt timestamps
```

### State Management Pattern (BLoC)

```dart
// Event-driven architecture
UI → Event → BLoC → State → UI

// Example flow:
UserTapsLogin → LoginRequested → AuthBloc → AuthSuccess → HomeScreen
```

### Clean Code Practices

- SOLID principles throughout
- Repository pattern for data access
- Dependency injection for testability
- Feature-first folder structure
- Separation of concerns

---

## Project Structure

```
Expense-management-app-AI/
│
├── money_manager_app/              # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/          # App constants, colors, API endpoints
│   │   │   ├── di/                 # Dependency injection setup
│   │   │   ├── services/           # Shared services (API, sync, storage)
│   │   │   └── utils/              # Helper functions, extensions
│   │   │
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/           # Data sources, models, repositories
│   │   │   │   ├── domain/         # Entities, repository interfaces
│   │   │   │   └── presentation/   # Screens, widgets, BLoC
│   │   │   │
│   │   │   ├── transaction/        # Same structure
│   │   │   ├── wallet/             # Same structure
│   │   │   ├── category/           # Same structure
│   │   │   ├── reports/            # Same structure
│   │   │   ├── group/              # Same structure
│   │   │   └── settings/           # Same structure
│   │   │
│   │   └── main.dart               # Application entry point
│   │
│   ├── android/                    # Android native configuration
│   ├── ios/                        # iOS native configuration
│   └── pubspec.yaml                # Flutter dependencies
│
├── MoneyManager-master/            # .NET Backend Solution
│   ├── MoneyManager.API/
│   │   ├── Controllers/            # API endpoints
│   │   ├── Hubs/                   # SignalR hubs
│   │   └── Program.cs              # Application startup
│   │
│   ├── MoneyManager.Application/
│   │   ├── DTOs/                   # Data transfer objects
│   │   ├── Interfaces/             # Service contracts
│   │   └── Services/               # Business logic
│   │
│   ├── MoneyManager.Domain/
│   │   ├── Entities/               # Domain models
│   │   └── Enums/                  # Enumerations
│   │
│   └── MoneyManager.Infrastructure/
│       ├── Data/
│       │   ├── Context/            # DbContext
│       │   └── Configurations/     # Entity configurations
│       ├── Migrations/             # EF Core migrations
│       └── Services/               # External service implementations
│
├── Doc.txt                         # Software Requirements Specification
├── SETUP_GUIDE.md                  # Development setup instructions
└── README.md                       # This file
```

---

## Getting Started

### Prerequisites

- .NET SDK 8.0+
- Flutter SDK 3.6+
- SQL Server (LocalDB or Express)
- Android Studio / VS Code

### Backend Setup

```bash
cd MoneyManager-master
dotnet restore
dotnet ef database update --project MoneyManager.API
dotnet run --project MoneyManager.API
```

### Mobile Setup

```bash
cd money_manager_app
flutter pub get
flutter run
```

### Configuration

1. Update `appsettings.json` with your database connection string
2. Update `app_constants.dart` with your backend IP address
3. Configure firewall to allow port 5166

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.

---

## API Documentation

### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/Auth/register | User registration |
| POST | /api/Auth/login | User login, returns JWT |
| POST | /api/Auth/refresh-token | Refresh access token |
| POST | /api/Auth/forgot-password | Password reset request |

### Wallet Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/Wallet | Get all wallets |
| POST | /api/Wallet | Create wallet |
| PUT | /api/Wallet/{id} | Update wallet |
| DELETE | /api/Wallet/{id} | Soft delete wallet |
| POST | /api/Wallet/transfer | Transfer between wallets |

### Transaction Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/Transaction | Get transactions (paginated) |
| POST | /api/Transaction | Create transaction |
| PUT | /api/Transaction/{id} | Update transaction |
| DELETE | /api/Transaction/{id} | Soft delete transaction |

### Report Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/Report/summary | Get summary statistics |
| GET | /api/Report/by-category | Get breakdown by category |
| POST | /api/Report/by-time | Get time-series data |
| POST | /api/Report/export | Export to Excel |

### OCR Endpoint

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/Ocr/scan | Scan receipt image |

### Sync Endpoint

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/Sync | Full data synchronization |

---

## Database Schema

### Core Tables

| Table | Description |
|-------|-------------|
| AspNetUsers | User accounts (Identity) |
| Wallets | User wallets |
| Categories | Transaction categories |
| Transactions | Financial transactions |
| Groups | Group funds |
| GroupMembers | Group membership |
| Budgets | Budget limits |

### Key Relationships

```
User (1) ──────── (N) Wallet
User (1) ──────── (N) Category
User (1) ──────── (N) Transaction
Wallet (1) ─────── (N) Transaction
Category (1) ───── (N) Transaction
Group (1) ──────── (N) GroupMember
Group (1) ──────── (N) Transaction
User (1) ──────── (N) Budget
Category (1) ───── (N) Budget
```

---

## Performance Considerations

- **App Startup**: Target under 2 seconds
- **Database Queries**: Indexed columns for common filters
- **Image Processing**: Compressed to 1920px max, 85% quality
- **Sync Optimization**: Incremental sync reduces data transfer
- **Caching**: Network images cached locally

---

## Security Measures

1. **Authentication**: JWT tokens with expiration
2. **Authorization**: Role-based access control
3. **Data Protection**: Sensitive data in Secure Storage
4. **API Security**: All endpoints require Bearer token
5. **Password Security**: Hashed with Identity defaults (PBKDF2)
6. **Input Validation**: Server-side validation on all inputs

---

## License

This project is proprietary software developed for educational purposes.

---

## Contributors

Developed as a capstone project demonstrating full-stack mobile development with modern technologies and best practices.

