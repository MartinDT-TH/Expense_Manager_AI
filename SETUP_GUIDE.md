# 🚀 Hướng dẫn Setup & Chạy Money Manager App

## 📋 Yêu cầu hệ thống

### Backend (.NET)
- **.NET SDK 8.0** trở lên
- **SQL Server** (LocalDB hoặc SQL Server Express)
- **Visual Studio 2022** hoặc **VS Code** với C# extension

### Flutter
- **Flutter SDK 3.6.1** trở lên
- **Dart SDK** (đi kèm Flutter)
- **Android Studio** hoặc **VS Code** với Flutter extension
- **Android Emulator** hoặc thiết bị Android thật

---

## 1️⃣ Clone & Setup Backend

### Bước 1: Restore NuGet packages
```powershell
cd MoneyManager-master
dotnet restore
```

### Bước 2: Kiểm tra Connection String
📁 File: `MoneyManager.API/appsettings.json`
```json
"ConnectionStrings": {
  "DefaultConnectionString": "Server=localhost;Database=MoneyManagerDb;Trusted_Connection=True;TrustServerCertificate=True"
}
```
> ⚠️ Đổi `Server=localhost` nếu SQL Server ở máy khác

### Bước 3: Tạo Database (Migration)
```powershell
cd MoneyManager.API
dotnet ef database update
```
> Nếu chưa có EF Tools: `dotnet tool install --global dotnet-ef`

### Bước 4: Build Backend
```powershell
dotnet build
```

---

## 2️⃣ Setup Flutter

### Bước 1: Cài đặt dependencies
```powershell
cd money_manager_app
flutter pub get
```

### Bước 2: Tìm IP máy tính
```powershell
ipconfig
```
Lấy **IPv4 Address** (VD: `192.168.2.152`)

### Bước 3: Cập nhật IP trong Flutter
📁 File: `money_manager_app/lib/core/constants/app_constants.dart`
```dart
static const String pcIpAddress = '192.168.2.152';  // ← Đổi IP ở đây
```

---

## 3️⃣ Cấu hình Firewall (Windows)

Chạy PowerShell với quyền **Administrator**:
```powershell
netsh advfirewall firewall add rule name="Money Manager API" dir=in action=allow protocol=tcp localport=5166
```

---

## 4️⃣ Chạy ứng dụng

### Terminal 1 - Backend:
```powershell
cd MoneyManager-master/MoneyManager.API
dotnet run
```
> API sẽ chạy tại: `http://0.0.0.0:5166`

### Terminal 2 - Flutter:
```powershell
cd money_manager_app
flutter run
```

---

## 📦 Danh sách NuGet Packages (Backend)

### MoneyManager.API
| Package | Version | Mô tả |
|---------|---------|-------|
| Microsoft.AspNetCore.Authentication.JwtBearer | 8.0.12 | JWT Authentication |
| Microsoft.AspNetCore.OpenApi | 8.0.12 | OpenAPI/Swagger |
| Microsoft.EntityFrameworkCore.Design | 8.0.12 | EF Core Design Tools |
| Swashbuckle.AspNetCore | 6.6.2 | Swagger UI |

### MoneyManager.Infrastructure
| Package | Version | Mô tả |
|---------|---------|-------|
| **ClosedXML** | **0.105.0** | **📊 Export Excel (.xlsx)** |
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 8.0.12 | Identity với EF Core |
| Microsoft.EntityFrameworkCore.SqlServer | 8.0.12 | SQL Server Provider |
| Microsoft.EntityFrameworkCore.Tools | 8.0.12 | EF Core CLI Tools |
| Microsoft.Extensions.Configuration | 8.0.0 | Configuration |
| Microsoft.Extensions.Configuration.Json | 8.0.1 | JSON Config |
| System.IdentityModel.Tokens.Jwt | 8.15.0 | JWT Token handling |

### MoneyManager.Application
| Package | Version | Mô tả |
|---------|---------|-------|
| Microsoft.Extensions.Configuration.Abstractions | 8.0.0 | Config abstractions |
| Microsoft.Extensions.Identity.Core | 8.0.12 | Identity Core |
| System.IdentityModel.Tokens.Jwt | 8.15.0 | JWT handling |

### MoneyManager.Domain
| Package | Version | Mô tả |
|---------|---------|-------|
| Microsoft.Extensions.Identity.Stores | 8.0.12 | Identity Stores |

---

## 📦 Danh sách Flutter Packages

| Package | Version | Mô tả |
|---------|---------|-------|
| flutter_bloc | ^9.1.1 | State management |
| dio | ^5.9.0 | HTTP client |
| sqflite | ^2.4.1 | SQLite local database |
| get_it | ^9.2.0 | Dependency injection |
| shared_preferences | ^2.5.3 | Local storage |
| fl_chart | ^0.71.0 | Biểu đồ (Pie, Bar chart) |
| flutter_svg | ^2.2.0 | SVG icons |
| cached_network_image | ^3.4.1 | Cache ảnh |
| image_picker | ^1.2.0 | Chọn/chụp ảnh |
| flutter_secure_storage | ^10.0.0 | Secure storage (tokens) |
| connectivity_plus | ^7.0.0 | Kiểm tra kết nối mạng |
| equatable | ^2.0.8 | Object equality |
| go_router | ^16.1.0 | Navigation/Routing |
| uuid | ^4.5.2 | Generate UUID |
| dartz | ^0.10.1 | Functional programming |
| calendar_date_picker2 | ^1.1.9 | Date picker |
| signalr_netcore | ^1.3.7 | SignalR real-time |
| **path_provider** | **^2.1.5** | **📂 Đường dẫn file system** |
| **share_plus** | **^10.1.4** | **📤 Chia sẻ file** |
| **open_filex** | **^4.6.0** | **📄 Mở file với app mặc định** |
| intl | ^0.20.2 | Internationalization |
| crypto | ^3.0.6 | Crypto utils |
| image | ^4.5.3 | Image processing |

### Dev Dependencies
| Package | Version | Mô tả |
|---------|---------|-------|
| flutter_lints | ^5.0.0 | Lint rules |
| build_runner | ^2.4.15 | Code generation |
| json_serializable | ^6.9.5 | JSON serialization |
| freezed | ^3.0.6 | Immutable classes |

---

## ⚠️ Lưu ý quan trọng

1. 📱 **Điện thoại & PC phải cùng mạng WiFi**
2. 🔌 Điện thoại cần bật **USB Debugging**
3. 🌐 Backend đã bind `0.0.0.0:5166` (không cần đổi)
4. 🗄️ SQL Server phải đang chạy trước khi start backend
5. 📊 **ClosedXML** package dùng để export file Excel thực sự (.xlsx)
6. 📂 **path_provider, share_plus, open_filex** dùng để lưu và mở file export

---

## 🔧 Checklist nhanh

### Lần đầu setup:
- [ ] Cài .NET SDK 8.0
- [ ] Cài Flutter SDK 3.6.1+
- [ ] Cài SQL Server / LocalDB
- [ ] Clone project
- [ ] `dotnet restore` (Backend)
- [ ] `dotnet ef database update` (Tạo DB)
- [ ] `flutter pub get` (Flutter)

### Mỗi lần chạy:
- [ ] Tìm IP mới bằng `ipconfig`
- [ ] Sửa `pcIpAddress` trong `app_constants.dart`
- [ ] Mở firewall port 5166 (nếu chưa)
- [ ] Chạy `dotnet run`
- [ ] Chạy `flutter run`

---

## 🐛 Troubleshooting

### Lỗi "Connection refused"
- Kiểm tra backend đã chạy chưa
- Kiểm tra IP đúng chưa
- Kiểm tra firewall đã mở port 5166

### Lỗi "Database not found"
```powershell
dotnet ef database update
```

### Lỗi Flutter packages
```powershell
flutter clean
flutter pub get
```

### Lỗi build Android
```powershell
cd android
./gradlew clean
cd ..
flutter run
```
