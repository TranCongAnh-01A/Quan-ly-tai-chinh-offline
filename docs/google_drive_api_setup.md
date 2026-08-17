# GOOGLE DRIVE API SETUP — Hướng dẫn cấu hình Đồng bộ Đám mây

> ⚠️ Tài liệu này hướng dẫn cách cấu hình Google Cloud Console và Firebase để kích hoạt tính năng Đồng bộ Đám mây (Cloud Sync) cho ứng dụng Giản Ký.
> Nếu bạn chỉ muốn chạy ứng dụng cục bộ (Offline), bạn có thể **bỏ qua** tài liệu này.

**Cập nhật lần cuối:** 2026-08-17

---

## 1. Tổng quan

Tính năng Cloud Sync của Giản Ký sử dụng **Google Drive API** để lưu trữ các file sao lưu (JSON/ZIP) vào một thư mục ẩn an toàn của người dùng có tên là `appDataFolder`. Để làm được điều này, ứng dụng cần kết hợp sử dụng **Google Sign-In** (để xác thực người dùng) và cấp quyền truy cập **Google Drive API**.

Quy trình thiết lập bao gồm 4 bước chính:
1. Tạo dự án trên Firebase Console.
2. Đăng ký ứng dụng Android/iOS và tải file cấu hình.
3. Cấp mã SHA-1 (đối với Android).
4. Kích hoạt Google Drive API trên Google Cloud Console.

---

## Bước 1: Tạo dự án trên Firebase Console

> 💡 **Tại sao lại dùng Firebase cho ứng dụng Offline?**
> Giản Ký hoàn toàn không sử dụng database hay dịch vụ theo dõi nào của Firebase (bạn có thể kiểm chứng trong `pubspec.yaml`). Chúng ta chỉ "mượn" giao diện Firebase Console như một công cụ tiện ích để tự động sinh ra các file cấu hình `google-services.json` và `GoogleService-Info.plist`. Đây là cách chuẩn, nhanh và ít lỗi nhất để thiết lập Google Sign-In trong Flutter. Sau khi lấy được file cấu hình, ứng dụng sẽ giao tiếp trực tiếp với Google Drive API.

Firebase sẽ giúp tự động hóa quá trình tạo OAuth 2.0 Client ID bên phía Google Cloud.

1. Truy cập [Firebase Console](https://console.firebase.google.com/).
2. Nhấn vào **Add project** (Thêm dự án).
3. Đặt tên dự án (ví dụ: `GianKy-App`) và hoàn tất các bước tạo. Bạn có thể tắt Google Analytics nếu không cần thiết.

---

## Bước 2: Thêm ứng dụng Android và iOS vào Firebase

### Dành cho Android
1. Từ trang tổng quan (Dashboard) của Firebase, chọn biểu tượng **Android**.
2. Nhập **Android package name** (Tên gói). Mặc định của Giản Ký thường là `com.example.mone_jour` (hãy kiểm tra biến `applicationId` trong file `mone_jour/android/app/build.gradle`).
3. Nhập **App nickname** (Biệt danh ứng dụng) (VD: `Giản Ký Android`).
4. Bỏ trống mã SHA-1 lúc này (chúng ta sẽ thêm ở Bước 3), nhấn **Register app**.
5. Tải xuống file `google-services.json`.
6. Đặt file này vào thư mục `mone_jour/android/app/` trong mã nguồn.

### Dành cho iOS (Nếu bạn dùng máy Mac)
1. Chọn biểu tượng **iOS**.
2. Nhập **Apple bundle ID** (giống với package name của Android).
3. Tải xuống file `GoogleService-Info.plist`.
4. Đặt file này vào thư mục `mone_jour/ios/Runner/` (tốt nhất là bạn kéo thả file này vào thư mục Runner thông qua XCode để XCode tự liên kết file).

> ⚠️ **Bảo mật:** Đảm bảo rằng file `google-services.json` và `GoogleService-Info.plist` đã được thêm vào file `.gitignore` để không bị đẩy lên GitHub.

---

## Bước 3: Thêm mã SHA-1 (Dành cho Android)

Google Sign-In trên Android yêu cầu phải có mã băm SHA-1 của chứng chỉ ký ứng dụng (Keystore) để định danh thiết bị/ứng dụng của bạn.

### Cách lấy mã SHA-1 Debug (môi trường phát triển):
Mở terminal/Command Prompt và chạy lệnh sau (áp dụng cho Windows):
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
*(Đối với macOS/Linux: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`)*

### Thêm vào Firebase:
1. Vào **Project settings** (Cài đặt dự án) trên Firebase (biểu tượng bánh răng).
2. Cuộn xuống mục **Your apps**, chọn tab ứng dụng Android.
3. Bấm **Add fingerprint** (Thêm vân tay) và dán đoạn mã SHA-1 vừa lấy được.
4. (Tùy chọn) Nên làm tương tự để thêm luôn mã SHA-256.

---

## Bước 4: Kích hoạt Google Drive API

Đây là bước bắt buộc để ứng dụng có thể gọi các API liên quan đến Google Drive.

1. Từ Firebase Console, ở mục Project settings, chuyển sang tab **Integrations**. Trên card Google Play, bạn sẽ thấy link dẫn tới **Google Cloud Console**. Hoặc truy cập trực tiếp [Google Cloud Console](https://console.cloud.google.com/) và chọn đúng dự án vừa tạo.
2. Tìm kiếm mục **APIs & Services** > **Library** (Thư viện).
3. Gõ `Google Drive API` vào ô tìm kiếm.
4. Bấm vào kết quả tương ứng và nhấn nút **Enable** (Bật).

---

## Bước 5: Cấu hình Màn hình chấp thuận OAuth (OAuth Consent Screen)

Để người dùng có thể đăng nhập, bạn cần cấu hình màn hình hiển thị khi Google yêu cầu cấp quyền.

1. Trong Google Cloud Console, vào **APIs & Services** > **OAuth consent screen**.
2. Chọn **External** (Bên ngoài) để bất kỳ ai có tài khoản Google đều có thể đăng nhập.
3. Điền các thông tin bắt buộc: **App name** (Giản Ký), **User support email**, và **Developer contact information**.
4. Chuyển sang bước **Scopes** (Phạm vi truy cập). Nhấn **Add or remove scopes**.
5. Nhập vào ô tìm kiếm chuỗi: `https://www.googleapis.com/auth/drive.appdata` và tích chọn nó. (Đây là quyền cho phép app ghi dữ liệu vào thư mục ẩn, không can thiệp vào các file khác của người dùng).
6. Thêm các tài khoản email thử nghiệm (Test users) vào nếu dự án của bạn vẫn đang ở trạng thái Testing. Nếu bạn publish dự án ra công chúng (In production), có thể sẽ cần Google kiểm duyệt quyền này.

🎉 **Hoàn tất!** Giờ đây bạn đã có thể khởi chạy ứng dụng Giản Ký và thử nghiệm tính năng đồng bộ đám mây (Cloud Sync) thành công.
