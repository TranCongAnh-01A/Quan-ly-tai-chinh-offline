import 'package:intl/intl.dart';

/// Singleton formatter — tránh tạo mới NumberFormat mỗi lần gọi.
final NumberFormat _vndFormatter = NumberFormat('#,###', 'vi_VN');

/// Format số tiền VND với dấu chấm phân cách hàng nghìn.
///
/// Ví dụ: 1500000 → "1.500.000 ₫"
///         -250000 → "-250.000 ₫"
String formatVND(double amount) {
  return '${_vndFormatter.format(amount.round())} ₫';
}
