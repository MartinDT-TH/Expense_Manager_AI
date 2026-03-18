# 🚀 Hướng dẫn Setup & Chạy Smart Money App

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
netsh advfirewall firewall add rule name="Smart Money API" dir=in action=allow protocol=tcp localport=5166
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

## 📴 Test đồng bộ Offline (Wallet, Category, Transaction)

App hỗ trợ offline-first: tạo/sửa/xóa Ví, Danh mục, Giao dịch khi mất mạng vẫn lưu local; khi online lại sẽ tự đồng bộ qua `sync_queue`.

### Chuẩn bị
1. Đăng nhập app, đảm bảo đã có ít nhất 1 ví và vài giao dịch (online).
2. Backend đang chạy và app từng kết nối thành công.

### Test 1: Tạo mới khi offline
1. **Tắt WiFi/3G** trên máy (hoặc chặn app khỏi mạng).
2. Tạo **Ví mới** (VD: "Ví offline") → Lưu.
3. Tạo **Danh mục mới** (nếu có màn hình tạo category) → Lưu.
4. Tạo **Giao dịch mới** (Thu/Chi) → Lưu.
5. Kiểm tra: danh sách Ví/Danh mục/Giao dịch vẫn hiển thị đầy đủ (kể cả mục vừa tạo).
6. Mở màn hình có **số mục chờ đồng bộ** (pending sync) → phải tăng (ít nhất 3 nếu tạo đủ 3 loại).

### Test 2: Online lại — đồng bộ tự động
1. **Bật lại mạng**.
2. Chờ 5–10 giây (hoặc mở lại app) để SyncService chạy auto-sync.
3. Hoặc kéo refresh / nhấn nút "Đồng bộ" nếu có.
4. Kiểm tra:
   - Số mục chờ đồng bộ về 0 (hoặc giảm đúng số đã sync).
   - Ví/Danh mục/Giao dịch tạo lúc offline vẫn còn, không mất.
   - Trên backend (Swagger/DB): có bản ghi Ví/Danh mục/Giao dịch tương ứng.

### Test 3: Không xóa dữ liệu local khi pull
1. Tắt mạng, tạo 1 Ví mới (chưa sync).
2. Bật mạng, vào màn hình danh sách Ví (trigger getWallets → pull từ server).
3. Kiểm tra: Ví tạo offline vẫn còn trong danh sách (merge, không wipe toàn bảng).

### Test 4: Sửa / Xóa khi offline
1. Tắt mạng.
2. Sửa tên một Ví hoặc một Giao dịch → Lưu.
3. Xóa một Giao dịch (hoặc soft-delete Ví nếu app hỗ trợ).
4. Bật mạng, chờ sync.
5. Kiểm tra: thay đổi đã lên server (hoặc bản ghi đã xóa trên server).

### Debug sync lỗi
- Trong debug build, lỗi sync được in ra console: `Sync failed wallet|category|transaction/...`.
- Số mục chờ lấy từ `sync_queue`; UI dùng `SyncService.pendingCount` / `refreshPendingCount()`.

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

