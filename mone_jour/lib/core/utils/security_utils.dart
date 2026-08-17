import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Tiện ích mã hóa — hash PIN và câu trả lời bảo mật bằng SHA-256.
///
/// Tại sao dùng SHA-256 thay vì lưu plaintext:
///   - SharedPreferences lưu file XML/JSON trên thiết bị, có thể đọc được
///   - Hash 1 chiều: không thể reverse từ hash → PIN gốc
///   - So sánh bằng cách hash input rồi đối chiếu với hash đã lưu
class SecurityUtils {
  /// Hash PIN bằng SHA-256.
  ///
  /// Ví dụ: "1234" → "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// So sánh PIN đầu vào với hash đã lưu.
  ///
  /// Trả về true nếu hash của [input] khớp với [storedHash].
  static bool verifyPin(String input, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    return hashPin(input) == storedHash;
  }

  /// Hash câu trả lời bảo mật (normalize: lowercase + trim trước khi hash).
  ///
  /// Normalize để người dùng không bị sai do viết hoa/thừa space.
  static String hashSecurityAnswer(String answer) {
    final normalized = answer.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// So sánh câu trả lời bảo mật với hash đã lưu.
  static bool verifySecurityAnswer(String input, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    return hashSecurityAnswer(input) == storedHash;
  }
}
