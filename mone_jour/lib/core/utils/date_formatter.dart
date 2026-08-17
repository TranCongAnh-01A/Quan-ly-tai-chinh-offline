import 'package:intl/intl.dart';

/// Format ngày tháng theo kiểu Việt Nam.

/// Ví dụ: "07/05/2026"
String formatDateShort(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Ví dụ: "Thứ Tư, 07 tháng 05"
String formatDateFull(DateTime date) {
  return DateFormat('EEEE, dd MMMM', 'vi_VN').format(date);
}

/// Ví dụ: "Tháng 05/2026"
String formatMonthYear(DateTime date) {
  return 'Tháng ${DateFormat('MM/yyyy').format(date)}';
}

/// Kiểm tra 2 DateTime có cùng ngày không (bỏ qua giờ phút giây).
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Trả về DateTime chỉ chứa ngày (giờ = 00:00:00).
DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
