# Giản Ký (MoneJour) - Quản lý tài chính cá nhân & Nhật ký

**Giản Ký** là một ứng dụng quản lý chi tiêu cá nhân kết hợp ghi chú nhật ký dành cho người Việt. Ứng dụng được xây dựng trên nền tảng Flutter với triết lý **Offline-first** (100% hoạt động mượt mà không cần internet) và đề cao tối đa quyền riêng tư của người dùng.

## ✨ Tính năng nổi bật

- 🔒 **Bảo mật & Offline-first**: Mọi dữ liệu thu/chi và nhật ký đều được lưu trữ hoàn toàn cục bộ trên thiết bị của bạn bằng cơ sở dữ liệu Isar (NoSQL). Ứng dụng không thu thập, theo dõi hay gửi dữ liệu của bạn về bất kỳ máy chủ bên thứ ba nào.
- 📊 **Quản lý thu chi thông minh**: Theo dõi chi tiêu theo danh mục, thiết lập hạn mức (ngân sách) cho từng khoản, và hỗ trợ ghi chép nhanh các khoản chi cố định (template).
- 📝 **Nhật ký cá nhân**: Trình soạn thảo văn bản phong phú để bạn tự do ghi chú lại cảm xúc và sự kiện mỗi ngày.
- ☁️ **Đồng bộ Google Drive**: Tùy chọn sao lưu (backup) và khôi phục (restore) dữ liệu thông qua thư mục ẩn của tài khoản Google Drive cá nhân. Dữ liệu hoàn toàn nằm trong quyền kiểm soát của bạn.
- 🔐 **Khóa bảo vệ đa lớp**: Hỗ trợ mã PIN, sinh trắc học (Vân tay/Face ID), và câu hỏi bảo mật để chống truy cập trái phép.
- 🌙 **Giao diện hiện đại**: Hỗ trợ Dark/Light Mode với ngôn ngữ thiết kế Material 3 đẹp mắt.

## 🛠 Công nghệ sử dụng (Tech Stack)

- **Framework**: Flutter (Dart)
- **Cơ sở dữ liệu**: Isar Database
- **State Management**: flutter_bloc (Cubit)
- **Đồ thị/Biểu đồ**: fl_chart
- **Đồng bộ đám mây**: Google Drive API & Google Sign-In

## 🚀 Hướng dẫn cài đặt nhanh

1. Đảm bảo bạn đã cài đặt Flutter SDK (v3.19.0 trở lên) và Dart (v3.3.0 trở lên).
2. Clone repository này về máy:

   ```bash
   git clone <đường_dẫn_repo_của_bạn>
   cd <tên_thư_mục>
   ```

3. Cài đặt các gói phụ thuộc (dependencies):

   ```bash
   flutter pub get
   ```

4. Chạy trình tạo mã tự động (bắt buộc để tạo model cho Isar Database):

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. Khởi chạy ứng dụng (trên máy ảo hoặc thiết bị thật):

   ```bash
   flutter run
   ```

## 📦 Build bản phát hành (Android)

Mặc định bản release được ký bằng **debug key** để `flutter run --release` chạy
được ngay — bản này **không đăng lên Play Store được**.

Để ký bằng khóa thật, tạo file `android/key.properties` (file này đã được
`.gitignore`, tuyệt đối không commit):

```properties
storePassword=<mật_khẩu_keystore>
keyPassword=<mật_khẩu_key>
keyAlias=<tên_alias>
storeFile=<đường_dẫn_tới_file_.jks>
```

Có file này thì `flutter build appbundle --release` tự động ký bằng khóa thật.

## 📚 Tài liệu chi tiết

Để tìm hiểu sâu hơn về kiến trúc dự án, cách thiết lập cấu hình nâng cao, hoặc cách đóng góp mã nguồn, vui lòng xem trong thư mục `docs/`:

- [Bản đồ Tài liệu (INDEX)](docs/INDEX.md)
- [Hướng dẫn thiết lập chi tiết](docs/mone_jour_setup.md)
- [Hướng dẫn cấu hình Google Drive API (để bật tính năng Cloud Sync)](docs/google_drive_api_setup.md)
- [Cẩm nang cho người mới & Hướng dẫn đóng góp (ONBOARDING)](docs/ONBOARDING.md)

## 🤝 Đóng góp (Contributing)

Dự án này là mã nguồn mở. Mọi đóng góp dưới hình thức báo lỗi (issues), đóng góp ý tưởng, hoặc mã nguồn (pull requests) đều được hoan nghênh nồng nhiệt! Xin vui lòng đọc file [ONBOARDING](docs/ONBOARDING.md) trước khi bắt đầu.
