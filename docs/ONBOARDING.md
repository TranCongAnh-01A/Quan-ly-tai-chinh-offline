# ONBOARDING & CONTRIBUTING — Hướng dẫn Đóng góp

Chào mừng bạn đến với dự án **Giản Ký (MoneJour)**! Rất vui vì bạn có hứng thú tìm hiểu và đóng góp cho mã nguồn này.

> **Cập nhật lần cuối:** 2026-08-17

---

## 1. Môi trường Phát triển
- **Flutter SDK:** Phiên bản `3.19.0` trở lên.
- **Dart SDK:** Phiên bản `3.3.0` trở lên.
- Luôn chạy lệnh sinh code cho Isar Database mỗi khi tải mã nguồn về hoặc có thay đổi trong thư mục `models`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

## 2. Quy ước Viết Code (Coding Conventions)
- **Tên biến/hàm (Dart):** Sử dụng `camelCase`.
- **Tên file/thư mục:** Sử dụng `snake_case`.
- **Cấu trúc thư mục (Architecture):** Ứng dụng sử dụng mô hình State Management **Cubit**.
  - `lib/ui/`: Chỉ chứa giao diện (Widget, Screen). KHÔNG chứa logic nghiệp vụ ở đây.
  - `lib/logic/`: Chứa các file Cubit quản lý trạng thái của ứng dụng.
  - `lib/data/`: Chứa Models và Repositories (tương tác trực tiếp với Isar Database).
  - `lib/services/`: Chứa các dịch vụ độc lập như Cloud Sync, Export/Import.

## 3. Luồng Làm việc với Git (Git Workflow)
Nếu bạn muốn đóng góp tính năng mới hoặc sửa lỗi, vui lòng tuân thủ quy trình sau:
1. **Fork** repository này về tài khoản GitHub của bạn.
2. **Tạo branch mới** từ nhánh `main`:
   - Tính năng mới: `feature/ten-tinh-nang`
   - Sửa lỗi: `bugfix/ten-loi`
3. **Quy tắc Commit:** Ghi chú rõ ràng về việc bạn đã thay đổi gì. Khuyến khích sử dụng [Conventional Commits](https://www.conventionalcommits.org/).
   - Ví dụ: `feat: Thêm biểu đồ cột cho giao diện thống kê`
   - Ví dụ: `fix: Sửa lỗi crash khi tạo giao dịch không có ghi chú`
4. **Push branch** lên fork của bạn và tạo một **Pull Request (PR)** hướng vào nhánh `main` của repository gốc.

## 4. Tài liệu Bắt buộc Cần Đọc
Trước khi chỉnh sửa một module nào đó, hãy đọc lướt qua các tài liệu sau để nắm rõ tư duy thiết kế hiện tại:
- [Bối cảnh Dự án (Tech Stack chi tiết)](./PROJECT_CONTEXT.md)
- [Kiến trúc & Logic Code (Cubit & Isar)](./explain/mone_jour_architecture_and_logic.md)

Cảm ơn bạn rất nhiều vì đã chung tay phát triển dự án này! 🚀
