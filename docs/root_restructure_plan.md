# Kế Hoạch Chi Tiết: Tái Cấu Trúc Thư Mục Dự Án (Đưa Flutter ra Thư Mục Gốc)

> **Mã kế hoạch:** PLAN-RESTRUCT-01  
> **Ngày lập:** 2026-08-22  
> **Trạng thái:** Đã phân tích toàn diện mã nguồn / Sẵn sàng thực thi  
> **Phạm vi tác động:** Toàn bộ cấu trúc thư mục, hệ thống mã nguồn (`lib/`, `test/`), nền tảng native (`android/`, `ios/`, `windows/`), hệ thống tài liệu (`docs/`), và cấu hình Git (`.gitignore`)

---

## 1. Bối Cảnh & Mục Tiêu

### 1.1. Hiện trạng (Current State)
Dự án hiện tại đang có cấu trúc lồng nhau (nested structure):
- Thư mục gốc kho lưu trữ: `Quan-ly-tai-chinh-offline/`
- Chứa thư mục `docs/`, `README.md`, `.gitignore` (gốc).
- Toàn bộ mã nguồn Flutter, cấu hình build, dependencies nằm sâu bên trong thư mục con `mone_jour/`.
- Tồn tại **2 file `.gitignore`** riêng biệt (`/.gitignore` và `/mone_jour/.gitignore`), dẫn đến việc cấu hình đường dẫn bị phân mảnh (ví dụ: `/.gitignore` phải viết `mone_jour/android/...`).

### 1.2. Mục tiêu (Target Objectives)
- Chuyển toàn bộ mã nguồn ứng dụng Flutter từ `mone_jour/` ra trực tiếp thư mục gốc `Quan-ly-tai-chinh-offline/`.
- Hợp nhất và tối ưu hóa file cấu hình Git `.gitignore` duy nhất tại gốc, ngăn ngừa nguy cơ rò rỉ file nhạy cảm.
- Chuẩn hóa lại toàn bộ tài liệu hướng dẫn (`README.md`, `docs/*`) để người dùng/nhà phát triển không cần thêm bước `cd mone_jour`.
- Đảm bảo các công cụ IDE (VS Code, Android Studio, Antigravity) và Flutter CLI nhận diện dự án ngay khi mở thư mục gốc.
- Xóa bỏ thư mục `mone_jour/` rỗng sau khi hoàn tất.

---

## 2. So Sánh Cấu Trúc Trước & Sau

```text
─── TRƯỚC KHI CHUYỂN (HIỆN TẠI) ───
Quan-ly-tai-chinh-offline/
├── .git/
├── .gitattributes
├── .gitignore                      <-- File ignore gốc (chứa đường dẫn mone_jour/...)
├── README.md                       <-- Hướng dẫn clone xong phải `cd mone_jour`
├── docs/                           <-- Thư mục tài liệu
│   ├── INDEX.md
│   ├── PROJECT_CONTEXT.md
│   └── ...
└── mone_jour/                      <-- Thư mục con chứa toàn bộ Flutter App
    ├── .dart_tool/
    ├── .flutter-plugins-dependencies
    ├── .gitignore                  <-- File ignore riêng của Flutter
    ├── .metadata
    ├── analysis_options.yaml
    ├── android/
    ├── assets/
    ├── build/
    ├── devtools_options.yaml
    ├── flutter_launcher_icons.yaml
    ├── ios/
    ├── lib/
    ├── pubspec.lock
    ├── pubspec.yaml
    ├── test/
    └── windows/

─── SAU KHI CHUYỂN (MỤC TIÊU) ───
Quan-ly-tai-chinh-offline/
├── .dart_tool/                     <-- Sinh lại mới hoàn toàn tại gốc
├── .flutter-plugins-dependencies
├── .git/
├── .gitattributes
├── .gitignore                      <-- File ignore chuẩn, hợp nhất duy nhất
├── .metadata
├── README.md                       <-- Hướng dẫn trực tiếp tại gốc
├── analysis_options.yaml
├── android/
├── assets/
├── build/                          <-- Sinh mới khi build tại gốc
├── devtools_options.yaml
├── docs/                           <-- Tài liệu chuẩn hóa đường dẫn
│   ├── INDEX.md
│   ├── root_restructure_plan.md    <-- File kế hoạch này
│   └── ...
├── flutter_launcher_icons.yaml
├── ios/
├── lib/
├── pubspec.lock
├── pubspec.yaml
├── test/
└── windows/
```

---

## 3. Phân Tích Chuyên Sâu Toàn Bộ Mã Nguồn & Đánh Giá Khả Năng Phát Sinh Lỗi (Deep Code Audit)

Đã thực hiện quét và đọc toàn bộ mã nguồn Dart, file cấu hình native, tài sản và dịch vụ để phát hiện mọi điểm nghẽn hoặc nguy cơ lỗi khi chuyển đổi cấu trúc:

### 3.1. Mã nguồn Dart & Package Imports (`lib/` & `test/`)
* **Kiểm tra Imports:** Toàn bộ file Dart trong `lib/` và `test/` sử dụng cú pháp chuẩn `package:mone_jour/...` hoặc relative import (`../...`).
* **Đánh giá lỗi:** **KHÔNG CÓ LỖI**. Tên package được xác định bởi thuộc tính `name: mone_jour` trong [pubspec.yaml](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/pubspec.yaml). Khi di chuyển `pubspec.yaml` và `lib/` ra thư mục gốc, Dart Package Resolver vẫn map chính xác package `mone_jour` vào `lib/`.
* **Cấu hình Assets:** [pubspec.yaml](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/pubspec.yaml) khai báo `assets/animations/`. Khi thư mục `assets/` nằm cùng cấp với `pubspec.yaml` ở gốc, cơ chế nạp Asset của Flutter hoạt động 100% bình thường.

### 3.2. Cơ sở dữ liệu Isar Database & Code Generation
* **Khởi tạo Isar ([lib/services/database_service.dart](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/lib/services/database_service.dart)):**
  ```dart
  final dir = await getApplicationDocumentsDirectory();
  _isar = await Isar.open(
    [ExpenseSchema, JournalSchema, FixedExpenseSchema, BudgetSchema],
    directory: dir.path,
    name: 'mone_jour',
  );
  ```
* **Đánh giá lỗi:**
  - *Runtime Data:* **KHÔNG CÓ LỖI**. Dữ liệu cục bộ của người dùng được lưu trong thư mục `ApplicationDocumentsDirectory` do hệ điều hành quản lý, hoàn toàn không phụ thuộc vào vị trí thư mục mã nguồn.
  - *Code Generation (`*.g.dart`):* **CÓ RỦI RO NẾU KHÔNG XÓA CACHE**. Thư mục `.dart_tool/build` cũ có thể chứa metadata đồ thị phụ thuộc (asset graph) lưu đường dẫn tuyệt đối cũ (`.../mone_jour/lib/...`).
  - *Giải pháp:* Bắt buộc xóa thư mục `.dart_tool` và chạy `dart run build_runner build --delete-conflicting-outputs` ở thư mục gốc để tái tạo chính xác 12 files schema `.g.dart`.

### 3.3. Các Dịch vụ Nhập/Xuất & Lưu trữ An toàn
* **[export_service.dart](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/lib/services/export_service.dart) & [import_service.dart](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/lib/services/import_service.dart):** Đều sử dụng `getApplicationDocumentsDirectory()` hoặc `getTemporaryDirectory()` để xử lý file backup JSON/CSV.
* **[secure_storage_service.dart](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/lib/services/secure_storage_service.dart):** Sử dụng `FlutterSecureStorage` để mã hóa mật khẩu/PIN.
* **Đánh giá lỗi:** **KHÔNG CÓ LỖI**. Toàn bộ logic lưu trữ dữ liệu đều sử dụng đường dẫn động (dynamic paths) của OS.

### 3.4. Nền tảng Windows Native (`windows/`)
* **Cấu hình CMake ([windows/CMakeLists.txt](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/windows/CMakeLists.txt)):**
  - Sử dụng các biến CMake cục bộ (`${CMAKE_CURRENT_SOURCE_DIR}/flutter`, `add_subdirectory("runner")`).
  - `set(BINARY_NAME "mone_jour")`.
* **Đánh giá lỗi:** **CÓ NGUY CƠ LỖI BUILD NẾU GIỮ CACHE CŨ**. Thư mục `build/windows/x64/` hiện tại lưu các file project Visual Studio (`flutter_assemble.vcxproj`, `CMakeCache.txt`) chứa đường dẫn cứng tuyệt đối tới thư mục `mone_jour`. Nếu không dọn dẹp trước khi build, MSBuild sẽ báo lỗi `error MSB8066` do tìm kiếm file rule ở đường dẫn cũ.
* *Giải pháp:* Xóa sạch hoàn toàn thư mục `build/` trước khi di chuyển.

### 3.5. Nền tảng Android Native (`android/`)
* **Cấu hình Gradle ([android/settings.gradle.kts](file:///d:/CODE/Project/Quan-ly-tai-chinh-offline/mone_jour/android/settings.gradle.kts)):**
  - `file("local.properties")` đọc đường dẫn Flutter SDK.
  - Plugin loader đọc `.flutter-plugins-dependencies` ở cùng cấp với `pubspec.yaml`.
* **Đánh giá lỗi:** **KHÔNG CÓ LỖI** sau khi chạy lại `flutter pub get` tại thư mục gốc để cập nhật lại `.flutter-plugins-dependencies`.

### 3.6. Cấu hình Git Tracking (`.gitignore`)
* **Đánh giá lỗi:** **NGUY CƠ BẢO MẬT & XUNG ĐỘT CAO**.
  - File `.gitignore` ở gốc hiện tại chứa:
    ```gitignore
    mone_jour/android/.gradle/
    mone_jour/android/local.properties
    mone_jour/android/key.properties
    ```
    Khi di chuyển ra gốc, các dòng này không còn khớp đường dẫn thực tế (`android/.gradle/`, `android/local.properties`), dẫn đến việc Git có thể theo dõi và vô tình đẩy các file nhạy cảm (keystore, secret keys) lên repository.
  - File `mone_jour/.gitignore` có các quy tắc bổ sung quan trọng (`google-services.json`, `GoogleService-Info.plist`, `*.env`).
* *Giải pháp:* Hợp nhất và tạo file `.gitignore` chuẩn mới tại thư mục gốc, bao quát toàn bộ các ngoại lệ.

### 3.7. Hệ thống Tài liệu & Đường dẫn Liên kết (`docs/` & `README.md`)
* **Đánh giá lỗi:** **LỖI THAM CHIẾU / DEAD LINKS**.
  - `README.md` đang hướng dẫn: `cd <tên_thư_mục>/mone_jour` -> Sẽ gây nhầm lẫn vì thư mục `mone_jour` không còn tồn tại.
  - `docs/PROJECT_CONTEXT.md` có dòng mô tả kiến trúc `mone_jour/lib/`.
  - `docs/mone_jour_setup.md` có lệnh `cd project-app/mone_jour`.
  - `docs/mone_jour_architecture_and_logic.md` có nhiều link markdown dạng `file:///d:/project_me/project-app/mone_jour/lib/...`.
  - `docs/google_drive_api_setup.md` hướng dẫn đặt file vào `mone_jour/android/app/` và `mone_jour/ios/Runner/`.
* *Giải pháp:* Thực hiện tìm kiếm và thay thế đồng loạt toàn bộ các đường dẫn cũ sang đường dẫn mới ở gốc.

---

## 4. Bảng Tổng Hợp Đánh Giá Rủi Ro

| Hạng mục | Mức độ rủi ro | Hiện tượng nếu không xử lý | Biện pháp kiểm soát & Giải pháp triệt để |
|---|---|---|---|
| **Build Cache cũ (`build/`, `.dart_tool/`)** | 🔴 Cao | Lỗi build MSBuild / CMake / Isar Generator do đường dẫn cũ bị lưu cứng trong cache. | Xóa sạch thư mục `build/` và `.dart_tool/` trước khi di chuyển; chạy lại `flutter clean` & `flutter pub get`. |
| **Bảo mật Git (`.gitignore`)** | 🔴 Cao | Lộ `local.properties`, `key.properties`, `google-services.json` do rule `.gitignore` trỏ sai thư mục `mone_jour/`. | Cập nhật `.gitignore` gốc với các đường dẫn trực tiếp (`android/...`, `ios/...`, secrets). |
| **Tài liệu & Dead Links** | 🟡 Trung bình | Người mới đọc tài liệu thực hiện lệnh `cd mone_jour` bị lỗi `No such directory`, link file không mở được. | Chỉnh sửa đồng loạt các file tài liệu trong `docs/` và `README.md`. |
| **Logic Code & Imports Dart** | 🟢 Không có | Không có lỗi phát sinh trong logic. | Giữ nguyên tên package `name: mone_jour` trong `pubspec.yaml`. |
| **Isar Database Storage** | 🟢 Không có | Không ảnh hưởng đến dữ liệu runtime. | Database lưu tại App Documents của hệ điều hành. |

---

## 5. Kế Hoạch Thực Thi Từng Bước (Execution Steps)

### Bước 1: Dọn dẹp cache tạm thời (Clean Workspace)
```powershell
# Xóa thư mục build và cache trong mone_jour trước khi di chuyển
Remove-Item -Recurse -Force mone_jour/build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force mone_jour/.dart_tool -ErrorAction SilentlyContinue
```

### Bước 2: Di chuyển toàn bộ file & thư mục từ `mone_jour/` ra gốc
- **Thư mục mã nguồn & native:** `lib/`, `test/`, `assets/`, `android/`, `ios/`, `windows/`.
- **File cấu hình dự án:** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `flutter_launcher_icons.yaml`, `devtools_options.yaml`.
- **File metadata hệ thống:** `.metadata`, `.flutter-plugins-dependencies`.

### Bước 3: Hợp nhất và Chuẩn hóa File `.gitignore` Duy Nhất Tại Gốc
Tạo file `/.gitignore` chuẩn bao gồm đầy đủ:
- Flutter & Dart artifacts (`.dart_tool/`, `.packages`, `build/`, `.flutter-plugins*`, `*.g.dart`)
- Isar Database (`*.isar`, `*.isar.lock`, `default.isar`)
- Android artifacts (`android/.gradle/`, `android/local.properties`, `android/key.properties`, `*.jks`, `*.keystore`)
- iOS & macOS artifacts (`ios/Flutter/.last_build_id`, `Pods/`, `.symlinks/`)
- Windows artifacts (`build/windows/`)
- Secrets (`google-services.json`, `GoogleService-Info.plist`, `*.env`)
- IDE settings (`.idea/`, `*.iml`, `.vscode/`)

### Bước 4: Cập nhật Toàn Bộ Tài Liệu & Links Tham Chiếu
1. **`README.md`**: Xóa bước `cd <tên_thư_mục>/mone_jour`, cập nhật lệnh chạy trực tiếp tại gốc.
2. **`docs/PROJECT_CONTEXT.md`**: Chỉnh sửa cấu trúc cây thư mục và đường dẫn `lib/...`.
3. **`docs/mone_jour_setup.md`**: Xóa lệnh `cd project-app/mone_jour`.
4. **`docs/mone_jour_architecture_and_logic.md`**: Cập nhật toàn bộ link file markdown trỏ trực tiếp vào `lib/...`.
5. **`docs/google_drive_api_setup.md`**: Đổi đường dẫn lưu file credential thành `android/app/` và `ios/Runner/`.

### Bước 5: Xóa Thư Mục `mone_jour/` Rỗng
- Kiểm tra lại xem còn sót file nào không.
- Tiến hành xóa thư mục `mone_jour/`.

### Bước 6: Khởi Tạo Lại Môi Trường & Kiểm Thử Toàn Diện
1. Tải dependencies tại thư mục gốc:
   ```powershell
   flutter pub get
   ```
2. Sinh code cho Isar Database:
   ```powershell
   dart run build_runner build --delete-conflicting-outputs
   ```
3. Phân tích tĩnh mã nguồn:
   ```powershell
   flutter analyze
   ```
4. Chạy unit tests:
   ```powershell
   flutter test
   ```
5. Khởi chạy thử ứng dụng trên Windows / Android:
   ```powershell
   flutter run
   ```

### Bước 7: Cập Nhật Mục Lục Tài Liệu (`docs/INDEX.md`)
- Đồng bộ hóa trạng thái tài liệu trong mục lục trung tâm.

---

## 6. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

- [ ] Toàn bộ thư mục `lib/`, `android/`, `ios/`, `windows/`, `assets/`, `test/` và các file `pubspec.*` nằm trực tiếp ở thư mục gốc.
- [ ] Thư mục `mone_jour/` không còn tồn tại.
- [ ] File `.gitignore` ở thư mục gốc bao quát toàn bộ các file tạm và secret keys (không còn tiền tố `mone_jour/`).
- [ ] Lệnh `flutter pub get` chạy thành công không có cảnh báo/lỗi đường dẫn.
- [ ] Lệnh `dart run build_runner build --delete-conflicting-outputs` sinh đủ các file `.g.dart` cho Isar Database.
- [ ] Lệnh `flutter analyze` đạt kết quả 0 fatal errors.
- [ ] Toàn bộ unit tests trong `test/` pass (`flutter test`).
- [ ] Ứng dụng khởi chạy thành công (`flutter run`) trên môi trường thử nghiệm.
- [ ] Toàn bộ link và hướng dẫn trong `README.md` và `docs/` đã được đồng bộ.

---

## 7. Kế Hoạch Hoàn Tác (Rollback Plan)

Nếu có sự cố không lường trước xảy ra:
1. **Nếu đã commit Git trước khi làm:** Khôi phục bằng lệnh `git reset --hard HEAD` hoặc `git checkout .`.
2. **Nếu chưa commit:** Di chuyển ngược lại toàn bộ các thư mục Flutter trở lại thư mục `mone_jour/`.
