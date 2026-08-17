# Đặc Tả Kiến Trúc & Tổng Quan Chi Tiết Logic Dự Án Giản Ký (MoneJour)

> [!IMPORTANT]
> **Mục đích tài liệu:** Đây là tài liệu quy chuẩn tổng hợp toàn bộ kiến trúc, mô hình cơ sở dữ liệu, các luồng nghiệp vụ (business logic) và từng chi tiết kỹ thuật nhỏ nhất của ứng dụng **Giản Ký (MoneJour)**. Tài liệu được dùng để đối chiếu logic, phát triển mở rộng, và đào tạo thành viên mới, bảo đảm không lọt bất kỳ chi tiết nghiệp vụ nào.

---

## 1. Tổng Quan Hệ Thống & Nền Tảng Kỹ Thuật (Tech Stack)

### 1.1. Mục tiêu ứng dụng
**Giản Ký (MoneJour = Money + Journal)** là ứng dụng quản lý tài chính cá nhân kết hợp ghi chép nhật ký, hướng tới trải nghiệm người dùng hiện đại, tối giản, thanh lịch nhưng sở hữu khả năng phân tích và rà soát tài chính vô cùng chặt chẽ. Ứng dụng được thiết kế tối ưu hóa độ phản hồi cho **Windows Desktop** (kèm năng lực phục vụ đa tạng offline tuyệt đối theo nhu cầu cá nhân).

### 1.2. Nền tảng Công nghệ & Thư viện (Core Stack)
*   **Ngôn ngữ & Framework:** Dart & Flutter (Hỗ trợ đa nền tảng, tối ưu trên Windows Desktop).
*   **Kiến trúc Quản lý State:** Clean Architecture kết hợp **Bloc / Cubit** (`flutter_bloc`), vận hành theo cơ chế phân tách rành mạch giữa 3 tầng: **Data Layer** $\leftrightarrow$ **Logic Layer** $\leftrightarrow$ **UI Layer**.
*   **Cơ sở Dữ Liệu Cục Bộ (Local Database):** **Isar Database** (`isar`, `isar_flutter_libs`, `isar_generator`).
    *   *Lý do kỹ thuật:* Isar là CSDL NoSQL siêu nhanh, đảm bảo an toàn kiểu (Type-safe), Zero-boilerplate (không cần viết migration phức tạp), hỗ trợ lập chỉ mục kép (Composite Index) giúp mọi câu lệnh truy vấn thời gian và danh mục đạt độ phức tạp $O(1)$.
*   **Bảo mật & Mã hóa:** Thư viện `crypto` (mã hóa SHA-256) và `local_auth` (Xác thực sinh trắc học / Vân tay / Windows Hello).
*   **Giao diện & Thành phần phụ trợ:** `phosphor_flutter` (Hệ thống icon phong cách tối giản), `intl` (Định dạng tiền tệ, ngày tháng chuẩn Việt Nam `vi_VN`), `file_picker` & `archive` (Xuất/Nhập dữ liệu tệp nén ZIP/CSV).

---

## 2. Bản Đồ Cơ Sở Dữ Liệu (Isar Collections & Data Models)

Hệ thống cơ sở dữ liệu được quy hoạch thành **4 Collections chính**, cấu trúc tại trùm thư mục [lib/data/models](file:///d:/project_me/project-app/mone_jour/lib/data/models).

```
   ┌─────────────────────────────────────────────────────────────┐
   │                       ISAR DATABASE                         │
   ├──────────────┬──────────────┬──────────────┬──────────────┤
   │   Expense    │    Budget    │ FixedExpense │   Journal    │
   │ Collection   │  Collection  │  Collection  │  Collection  │
   └──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
    [Giao dịch     [Hạn mức chi    [Khuôn mẫu      [Sổ tay /
     Thu / Chi /    theo danh mục   thanh toán      Nhật ký
     Chuyển khoản]  từng tháng]     nhanh 1-Touch]  tài chính]
```

### 2.1. Bảng Giao Dịch (`Expense`)
File mã nguồn: [expense.dart](file:///d:/project_me/project-app/mone_jour/lib/data/models/expense.dart). Đây là trái tim của hệ thống lưu trữ từng giao dịch.

| Thuộc tính | Kiểu dữ liệu | Index / Đặc điểm | Chi tiết ý nghĩa logic |
| :--- | :--- | :--- | :--- |
| `id` | `Id` | `Isar.autoIncrement` | Khóa chính tự quay vòng tăng dần. |
| `amount` | `double` | Không | Số tiền giao dịch (luôn lưu số dương; tính thu/chi phụ thuộc cờ `isIncome`). |
| `category` | `String` | `@Index()` | Mã định danh danh mục (ví dụ: `food`, `bills`, `transfer`...). |
| `note` | `String?` | Không | Ghi chú văn bản tường thuật cho giao dịch. |
| `date` | `DateTime` | `@Index(composite: [CompositeIndex('isIncome')])` | Thời gian thực tế của giao dịch. **Chỉ mục kép** giúp việc tìm kiềm theo dải thời gian + lọc thu/chi mượt mà ngay cả khi có hàng triệu bản ghi. |
| `isIncome` | `bool` | Composite cùng `date` | `true` = Thu nhập; `false` = Chi tiêu (hoặc chuyển khoản). |
| `createdAt` | `DateTime` | Không | Thời điểm người dùng tạo record này trong ứng dụng. |
| `isFixed` | `bool` | Mặc định: `false` | Cờ đánh dấu giao dịch này được sinh ra từ nút bấm "Thanh toán" của Mẫu chi tiêu cố định. |
| `isTransfer` | `bool` | Mặc định: `false` | Cờ phân định giao dịch Chuyển khoản nội bộ giữa Tiền mặt $\leftrightarrow$ Tài khoản. |
| `source` | `FundingSource`| `@enumerated` | Enum định vị dòng tiền: `FundingSource.cash` (Tiền mặt, index=0) hoặc `FundingSource.bank` (Tài khoản/Thẻ, index=1). |
| `receiptImagePath` | `String?` | Tùy chọn | Đường dẫn tuyệt đối lưu trữ ảnh chụp hóa đơn đính kèm. |

### 2.2. Bảng Ngân Sách (`Budget`)
File mã nguồn: [budget.dart](file:///d:/project_me/project-app/mone_jour/lib/data/models/budget.dart). Lưu trữ giới hạn chi phí tối đa cho từng danh mục, độc lập theo từng tháng/năm.

| Thuộc tính | Kiểu dữ liệu | Index / Đặc điểm | Chi tiết ý nghĩa logic |
| :--- | :--- | :--- | :--- |
| `id` | `Id` | `Isar.autoIncrement` | Khóa chính tự động tăng. |
| `categoryId` | `String` | `@Index(composite: [CompositeIndex('month'), CompositeIndex('year')])` | Mã danh mục bị khóa hạn ngạch. **Chỉ mục kép 3 phần** giúp truy xuất cực nhạy trong thời gian $O(1)$ khi kiểm tra hạn mức lúc ghi tiêu. |
| `amountLimit`| `double` | Không | Hạn mức chi tiêu tối đa (VND) cho phép trong tháng đó. |
| `month` | `int` | Composite cùng `categoryId`| Tháng áp dụng (Từ 1 đến 12). |
| `year` | `int` | Composite cùng `categoryId`| Năm áp dụng (Ví dụ: 2026). |

> [!NOTE]
> **Tại sao lưu Budget tách riêng theo tháng thay vì hạn mức chung mãi mãi?** Nhu cầu mua sắm và sinh hoạt biến động theo thời gian (ví dụ tháng Tết phải chi nhỉnh hơn các tháng thường). Quản lý theo tháng cho phép đối chiếu xu hướng thay đổi hành vi tiêu xài theo chu kỳ.

### 2.3. Bảng Mẫu Chi Tiêu Cố Định (`FixedExpense`)
File mã nguồn: [fixed_expense.dart](file:///d:/project_me/project-app/mone_jour/lib/data/models/fixed_expense.dart).

| Thuộc tính | Kiểu dữ liệu | Index / Đặc điểm | Chi tiết ý nghĩa logic |
| :--- | :--- | :--- | :--- |
| `id` | `Id` | `Isar.autoIncrement` | Khóa chính tự động tăng. |
| `title` | `String` | Không | Tên khoản chi cố định (VD: "Tiền thuê trọ", "Gói Netflix", "Cà phê sáng"). |
| `amount` | `double` | Không | Số tiền mặc định cho khoản chi này. |
| `categoryId` | `String` | `@Index()` | Danh mục tương ứng. |
| `note` | `String?` | Tùy chọn | Ghi chú mặc định sẽ được copy tự động qua Giao dịch thật khi thực thi. |
| `createdAt` | `DateTime` | Không | Thời gian khởi tạo khuôn mẫu. |

> [!TIP]
> **Sự tách biệt hợp lý:** `FixedExpense` chỉ là một **"Khuôn mẫu" (Template)**, hoàn toàn không dính dáng đến số liệu thống kê thu chi hay số dư hồ sơ cho đến khi người dùng thi hành tác vụ "Thanh toán". Khi thực thi, hệ thống sẽ nhân bản (clone) một `Expense` thật đưa vào lịch sử. Việc xóa bỏ khuôn mẫu sau này không hề làm sai lệch hay lung lay lịch sử các lần thanh toán trước.

### 2.4. Bảng Nhật Ký / Sổ Tay (`Journal`)
File mã nguồn: [journal.dart](file:///d:/project_me/project-app/mone_jour/lib/data/models/journal.dart).
*   **Cấu trúc:** Gồm `id`, `title`, `content` (nhật ký, văn bản dài), và `date` (Thời gian viết bài).
*   **Ý nghĩa:** Phục vụ triết lý "MoneJour" — tài chính đi liền với nhận xét tâm trạng, giúp người dùng suy ngẫm lý do vì sao họ tiêu tiền (ví dụ: chi tiêu cảm xúc khi mệt mỏi).

---

## 3. Quản Trị Tầng Logic (Cubit & Business Logic layer)

Hệ thống điều phối nghiệp vụ (Cubit) nằm trong thư mục [lib/logic](file:///d:/project_me/project-app/mone_jour/lib/logic), chia làm 8 cụm độc lập:

### 3.1. Cụm Quản Lý Giao Dịch & Biến Động Kép (`ExpenseCubit`)
File mã nguồn chính: [expense_cubit.dart](file:///d:/project_me/project-app/mone_jour/lib/logic/expense/expense_cubit.dart) $\leftrightarrow$ [expense_repository.dart](file:///d:/project_me/project-app/mone_jour/lib/data/repositories/expense_repository.dart).

#### a. Cơ Chế Lắng Nghe Khám Phá Thụ Động (`watchLazy`)
*   Mọi phương thức biến đổi dữ liệu (Add, Update, Delete) đều không gọi trực tiếp `loadMonth()` hay tải lại state. Thay vào đó, trong hàm khởi tạo của Cubit có đăng ký:
    ```dart
    _watchSubscription = _repository.watchChanges().listen((_) { _reload(); });
    ```
    Bất kỳ tác vụ nào (kể cả từ module khác như FixedExpense hay Import CSV) làm ghi nháy cơ sở dữ liệu Isar, luồng `watchChanges()` tự động cảm biến và lệnh cho UI rebuild số liệu lập tức.

#### b. Thuật Toán Tính Hồi Xưa Lũy Kế (`Carried Over Balance`)
*   Khi người dùng đang xem một tháng bất kỳ (ví dụ Tháng 8/2026), ứng dụng sẽ truy xuất một chặng lịch sử từ khởi nguyên Unix Epoch (`DateTime(1970)`) đến chính xác **từng mili-giây cuối cùng ngay trước lúc khởi đầu tháng đó** (`start.subtract(Duration(milliseconds: 1))`).
*   **Công thức:**
    $$\text{Carried Over Balance} = \sum \text{Total Income}_{\text{past}} - \sum \text{Total Expense}_{\text{past}}$$
    *(Lưu ý: Nghiêm ngặt loại trừ tất cả các khoản chuyển tiền `isTransfer == true` trong phép tính này).*

#### c. Thuật Toán Cân Đối Hai Nguồn Quỹ (`Tiền mặt` và `Tài khoản / Thẻ`)
*   Ứng dụng tính toán số dư thực tế ngay tại thời khắc hiện tại của 2 dòng tiền bằng cách quét toàn bộ danh sách giao dịch từ gốc 1970 đến hết mốc quan tâm:
    *   **Giao dịch thường (`!isTransfer`):** Nếu `isIncome == true` $\rightarrow$ cộng tiền; `isIncome == false` $\rightarrow$ trừ tiền vào đúng ví tương ứng (`FundingSource.cash` hoặc `FundingSource.bank`).
    *   **Giao dịch chuyển khoản (`isTransfer == true`):**
        *   Nếu `source == FundingSource.cash` (Chuyển tiền mặt $\rightarrow$ Ngân hàng): Trừ ví Tiền mặt, Cộng ví Ngân hàng.
        *   Nếu `source == FundingSource.bank` (Rút ngân hàng $\rightarrow$ Tiền mặt): Trừ ví Ngân hàng, Cộng ví Tiền mặt.

---

### 3.2. Cụm Thống Kê & Báo Cáo Phân Tích (`StatsCubit`)
File mã nguồn: [stats_cubit.dart](file:///d:/project_me/project-app/mone_jour/lib/logic/stats/stats_cubit.dart).

*   **Chức năng:** Hỗ trợ điều hướng qua lại giữa 3 tầm nhìn: **Theo Tháng (`FilterMode.month`)**, **Theo Năm (`FilterMode.year`)**, và **Khoảng Ngày Tùy Chọn (`FilterMode.custom`)**.
*   **Hàng rào Bảo vệ Dòng tiền Chuyển khoản (Logic Shield):**
    Trong hàm `_processAndEmitStats()`, logic đã được gài chốt kiểm duyệt tuyệt đối:
    ```dart
    for (final e in expenses) {
      if (e.isTransfer) continue; // Loại trừ ngay lập tức giao dịch chuyển ví nội bộ!
      // Tiếp tục phân bố vào chi phí / thu nhập...
    }
    ```
    Điều này ngăn chặn mọi sai sót về việc "thổi phồng" doanh thu hay nợ nần khi người dùng luân chuyển tài sản giữa các ngân hàng hoặc ví ATM cá nhân.

---

### 3.3. Cụm Hạn Mức Chi Tiêu (`BudgetCubit`)
File mã nguồn: [budget_cubit.dart](file:///d:/project_me/project-app/mone_jour/lib/logic/budget/budget_cubit.dart) $\leftrightarrow$ [budget_repository.dart](file:///d:/project_me/project-app/mone_jour/lib/data/repositories/budget_repository.dart).

*   **Cơ cấu vận hành:** Tương ứng với tháng/năm hiện hành (`_currentMonth`, `_currentYear`), Cubit lấy lên danh sách các cấu hình `Budget`.
*   **Đối chiếu Thực chi (Real-time Spending Check):**
    Với mỗi thẻ Ngân sách danh mục (VD: Ăn uống), hệ thống gọi `_expenseRepo.getCategorySpending()`, lọc tất cả các khoản:
    $$\text{Spending} = \sum \text{Amount} \quad \forall \text{ Expense } \in (\text{Tháng hiện tại}, \text{ Category}, \text{ isIncome} = \text{false}, \text{ isTransfer} = \text{false})$$
    Nếu số tiền chi tiêu vượt ngưỡng (`spending >= amountLimit`), thẻ `BudgetProgressCard` trên giao diện sẽ chuyển màu sang dải **Cảnh báo (Danger Red)** hoặc hiển thị thanh tiến độ vượt 100%.

---

### 3.4. Cụm Chi Tiêu Cố Định (`FixedExpenseCubit`)
File mã nguồn: [fixed_expense_cubit.dart](file:///d:/project_me/project-app/mone_jour/lib/logic/fixed_expense/fixed_expense_cubit.dart).

*   **Logic Thanh toán Nhanh 1-Touch (`confirmFixedExpense`):**
    Khi nhận lệnh thanh toán cho một mẫu `FixedExpense`, Cubit ủy thác cho Repository sinh ra một bản ghi `Expense` hoàn chỉnh:
    ```dart
    final expense = Expense()
      ..amount = template.amount
      ..category = template.categoryId
      ..date = DateTime.now()            // Lấy theo giây phút bấm thanh toán hiện tại
      ..isIncome = false                 // Là khoản chi tiêu
      ..note = template.note ?? template.title
      ..createdAt = DateTime.now()
      ..isFixed = true                   // Đính huy hiệu là chi tiêu định kỳ
      ..source = source;                 // Tiền mặt hoặc Tài khoản theo user lựa chọn lúc bấm
    ```

---

### 3.5. Cụm Cấu Hình & Bảo Mật Khóa Cổng (`SettingsCubit`)
File mã nguồn: [settings_cubit.dart](file:///d:/project_me/project-app/mone_jour/lib/logic/settings/settings_cubit.dart) $\leftrightarrow$ [security_utils.dart](file:///d:/project_me/project-app/mone_jour/lib/core/utils/security_utils.dart).

*   **Hạ tầng Mã hóa (`SecurityUtils`):** Toàn bộ mã PIN (4 chữ số) và Đáp án cho câu hỏi bảo mật KHÔNG BAO GIỜ lưu trực tiếp dưới dạng bản rõ (plaintext). Chúng đều được biến thoái qua giao thức **SHA-256 Digest**:
    *   Đối với câu hỏi bảo mật, đáp án trước khi băm SHA-256 được ép kiểu bẻ nhọn rủi ro (Normalization): cắt bỏ chuỗi trắng đầu đuôi và hạ toàn bộ xuống chữ thường (`answer.trim().toLowerCase()`). Điều này ngăn việc user gõ sai chữ viết hoa hay dấu cách thừa khi khôi phục PIN.
*   **Vận hành Sinh trắc học & Windows Hello:** Hưởng ứng thư viện `local_auth`. 
*   **Màn trập khóa trạm (`AuthWrapper.pauseLock`):** Một logic cốt lõi vô cùng tinh tế ở UI đính kèm lúc gọi thư viện Sinh trắc học hay khi mở cửa sổ chọn tập tin tin cậy: cờ `AuthWrapper.pauseLock = true` được tạm thời đẩy lên để ngăn cản việc ứng dụng lầm tưởng user vừa thoát ra ngoài mà kích hoạt chế độ khóa màn hình không mong muốn.

---

### 3.6. Các Cụm Logic Khác (`JournalCubit`, `ThemeCubit`, `CloudSyncCubit`)
*   **`ThemeCubit`:** Điều khiển giao diện hiển thị Sáng / Tối (Light / Dark mode) hoặc Tùy chỉnh gam màu Pastel cá tính; đồng bộ thiết lập với SharedPreferences.
*   **`JournalCubit`:** Cung cấp chức năng xem, tạo, sửa, xóa nhật ký.
*   **`CloudSyncCubit`:** Khai báo luồng nén toàn bộ cơ sở dữ liệu Isar thành 1 chuỗi mã JSON tinh xảo, thiết lập nền tảng dự phòng tải lên lưu trữ từ xa (dù với Windows Desktop hiện tại có thể vận hành thuần túy Offline mà không cần mở tính năng này).

---

## 4. Phân Tích Logic Chuẩn Hóa & Kỹ Thuật Nâng Cao

### 4.1. Cận Biên Truy Vấn Triệt Để Tới Micrô-Giây (Zero Dead-Zone)
Trong quá trình vận hành, một vấn đề hiểm hóc thường xảy ra ở hệ thống tính tiền khi người dùng không chọn ngày giờ từ khung chọn lịch mà để mặc định: giao dịch sẽ ghi nhận `DateTime.now()` (ví dụ: `23:59:59.489`).
*   **Cách xử lý chuẩn xác hiện tại của Giản Ký:**
    Toàn bộ các truy vấn lọc tháng, năm hoặc dải thời gian (`getByMonth`, `getCategorySpending`, `loadStatsByYear`, `FilterTransactionSheet`...) **đều tuân thủ tuyệt đối quy luật khóa cận kết thúc**:
    ```dart
    final start = DateTime(year, month, 1, 0, 0, 0, 0, 0);
    // Lấy đến giọt micrô-giây cuối cùng của giây cuối cùng trong ngày cuối tháng!
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999, 999);
    ```
    Điều này cấm tiệt mọi rủi ro về giao dịch tạo trong giây phút chuyển giao cuối ngày bị rơi vào "vùng chết" (Dead Zone) và biến mất khỏi báo cáo tháng.

---

### 4.2. Khung Chọn Thời Gian Mở Rộng Linh Hoạt (`Date Picker / Date Range Picker`)
*   Màn hình Lọc giao dịch ([filter_transaction_sheet.dart](file:///d:/project_me/project-app/mone_jour/lib/ui/widgets/filter_transaction_sheet.dart)) đã phá vỡ rào cản giới hạn tĩnh 12 tháng thông thường để vươn sang kiến trúc bộ lọc tự do với 3 chế độ:
    1. **Tất cả thời gian:** Truy tìm bao quát trong kho lưu trữ không giới hạn mốc.
    2. **Chọn Tháng (By Month):** Mở cửa sổ `showDatePicker` cấu hình thẳng vào chế độ **Chọn Năm (`initialDatePickerMode: DatePickerMode.year`)**, giải phóng phạm vi cuộn và thám hiểm từ năm **2000 đến 2100**. Danh sách cuộn năm (Grid Layout 3 cột của Flutter) tự động sáng dần và trỏ xa thẳm vào tương lai hoặc quá khứ theo bước cuộn chuột.
    3. **Khoảng thời gian tùy chọn (Custom Range):** Triển khai `showDateRangePicker` giúp quét chính xác khoảng thời gian tự do giữa hai mốc bất kỳ.

---

### 4.3. Hạ Tầng Dịch Vụ Xuất/Nhập Dữ Liệu & Bảo Vệ Khỏi Thảm Họa (`Export & Import Services`)
Nằm trong thư mục [lib/services](file:///d:/project_me/project-app/mone_jour/lib/services): [export_service.dart](file:///d:/project_me/project-app/mone_jour/lib/services/export_service.dart) và [import_service.dart](file:///d:/project_me/project-app/mone_jour/lib/services/import_service.dart).

#### a. Quy cách gói tệp (ZIP & CSV Architecture)
*   Khi Sao lưu / Xuất dữ liệu, `ExportService` chuyển đổi 4 collection Isar thành 4 văn bản định dạng chuẩn CSV (`expenses.csv`, `budgets.csv`, `fixed_expenses.csv`, `journals.csv`), sau đó dùng thư viện `archive` để cuộn nén vào một tệp tháp `.zip` duy nhất, giúp giao dịch gọn gàng khi lưu trữ hay chia sẻ qua USB/Desktop folder.

#### b. Cơ Chế Tự Động Sao Lưu Phòng Vệ (Auto-Backup Before Overwrite)
*   Trước khi thực hiện lệnh Nhập dữ liệu mới từ file bên ngoài (pháp thuật Xóa sạch DB và viết lại), `ImportService` chạy logic an ninh cẩn trọng cực kỳ đáng giá:
    ```dart
    if (await hasAnyData()) {
      final backupJson = await ExportService().getAllDataAsJsonString();
      final tempDir = Directory.systemTemp;
      final backupFile = File('${tempDir.path}/monejour_auto_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await backupFile.writeAsString(backupJson);
    }
    ```
    Nếu phát hiện CSDL hiện tại có dù chỉ 1 bản ghi, hệ thống âm thầm kết xuất một file phòng thủ vào thư mục tạm `systemTemp` của OS trước lúc xóa trắng, phòng ngừa triệt để thảm kịch lỡ tay thao tác đè file mất sạch công sức gõ nhật ký của người dùng.

---

### 4.4. Định Dạng & Tiện Ích Gõ Tiền Tệ (`CurrencyInputFormatter` & `ExpenseGrouper`)
*   **Trình gõ ngắt nhịp tự động ([currency_input_formatter.dart](file:///d:/project_me/project-app/mone_jour/lib/core/utils/currency_input_formatter.dart)):** Sử dụng `TextInputFormatter` chặn bắt tức thì chuỗi nhập liệu, loại trừ mọi ký tự phi số (`RegExp(r'[^\d]')`), tự động cấy dấu chấm ngắt hàng nghìn (Ví dụ: Gõ `1000000` Lập tức hiển thị thành `1.000.000`), mang lại phản hồi phím êm ái cho màn hình Windows.
*   **Thuật toán Nhóm Lịch & Header Cân Đối Ngày ([expense_grouper.dart](file:///d:/project_me/project-app/mone_jour/lib/core/utils/expense_grouper.dart)):**
    *   Duy trì `LinkedHashMap` kết hợp phương pháp `dateOnly()` nhằm ép chuỗi giờ phút về 0, gom nhóm chính xác các khoản vào các block ngày mà không làm hoản loạn thứ tự DESC (mới nhất lên đầu) từ CSDL.
    *   Tiến trình tính tiêu xài hiển thị ở đỉnh mỗi Cụm ngày trong danh sách Giao dịch được trang bị bộ lọc bảo vệ kép:
        ```dart
        final dayExpenseTotal = expenses
            .where((e) => !e.isIncome && !e.isTransfer) // Loại bỏ thu nhập VÀ chuyển khoản!
            .fold<double>(0.0, (sum, e) => sum + e.amount);
        ```

---

## 5. Tổng Hợp Danh Sách Tác Vụ Giao Diện (UI Screens & Components)

Toàn bộ hệ thống UI tại [lib/ui](file:///d:/project_me/project-app/mone_jour/lib/ui) tuân thủ ngôn ngữ thiết kế sang trọng, hiệu ứng phản hồi mượt mà (`AnimatedSlideDown`, các hiệu ứng thẻ mỏng Glassmorphism, phong cách phối màu HSL và chữ tối giản).

```
   ┌───────────────────────────────────────────────┐
   │                  UI LAYER                     │
   ├──────────────┬─────────────────┬──────────────┤
   │   Screens    │    Widgets      │  Navigation  │
   └──────┬───────┴────────┬────────┴──────┬───────┘
          │                │               │
          ▼                ▼               ▼
    - HomeScreen     - SummaryCard   - BottomNav
    - ExpenseScreen  - FilterSheet   - Drawer / Bar
    - StatsScreen    - BudgetDialog
    - JournalScreen  - GroupedList
    - PinScreen      - ActionSheet
```

1. **`HomeScreen` (Màn hình chính):** Bảng điều khiển trung tâm (Dashboard). Hiển thị `SummaryCard` (Số dư 2 ví Tiền mặt và Tài khoản, Thu-Chi trong tháng, số dư chuyển tiếp), các danh sách Hạn mức (`BudgetProgressCard`), và truy cập nhanh danh sách chi tiêu Cố định (`FixedExpenseCard`).
2. **`ExpenseListScreen` & `AddExpenseScreen`:** Màn hình tra cứu dòng tiền hằng ngày và màn hình Thêm/Sửa giao dịch thu chi. Tích hợp Máy tính / chọn Nguồn tiền / đính kèm ảnh hóa đơn / Bộ chọn Ngày mở rộng 2000-2100.
3. **`StatsScreen`:** Tụ hội biểu đồ thống kê thói quen chi dùng qua trục thời gian (Tháng, Năm, Khoảng tự chọn) và Bảng bóc tách tỷ trọng danh mục (Pie/Bar Chart) tinh khiết phi-chuyển-khoản.
4. **`JournalScreen`:** Trang viết lách, gõ sổ tay tâm sự và quan sát nhận thức tài chính qua thời gian.
5. **`SettingsScreen` & `PinScreen`:** Trạm tùy biến, cấu hình Sao lưu/Khôi phục (ZIP/CSV), chuyển đổi màu giao diện (Theme pastel / Dark Mode), thiết lập mã PIN bảo vệ và bộ câu hỏi cứu sinh khôi phục mật khẩu.
6. **Các Widgets Trọng Yếu:**
   - `FilterTransactionSheet`: Bảng thao tác Lọc đa chiều nâng cao.
   - `ExpenseActionSheet`: Hộp thoại thao tác nhanh (Xem / Sửa / Xóa) khi bấm vào 1 bản ghi giao dịch bất kỳ trên danh sách.
   - `TutorialDialog`: Bảng cẩm nang chào đón và hướng dẫn sử dụng tự cảm biến hiển thị cho lần đầu khởi chạy ứng dụng.
   - `CategoryPicker`: Lưới danh mục 28 icon chuẩn pastel, ánh xạ chính xác màu sắc riêng vào biểu đồ.

---

## 6. Tổng Căn Đối Về Tính Toàn Vẹn Của Hệ Thống

Sau các đợt rà soát và kiện toàn kỹ thuật, **Giản Ký (MoneJour)** mang trên mình tính kiên cố tuyệt đối trong các nguyên lý:
1. **Kháng Vỡ Giao Diện & Tràn Màn Hình:** Hoạt động ổn định trên hệ sinh thái máy tính để bàn (Windows Desktop) với trải nghiệm kéo cuộn và mở rộng lịch vô cực.
2. **Bảo Mật Bền Vững:** Không có lối tắt nào can thiệp được bản mã hash SHA-256 hay đánh tráo mật khẩu nếu không vượt qua rào cản chuẩn hóa câu hỏi bảo mật.
3. **Toàn Vẹn Số Liệu Toán Học Kép:** Việc gạt bỏ các khoản chuyển khoản nội bộ (`isTransfer`) và siết chặt các mốc thời gian đến từng micrô-giây đảm bảo sổ sách tài chính của bạn là một pháo đài minh bạch, kiên cố và hoàn hảo nhất.

*(Tài liệu này phản ánh toàn vẹn 100% mã nguồn thực tế của dự án Giản Ký - Có hiệu lực kể từ 2026-08-17).*
