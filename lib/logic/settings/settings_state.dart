import 'package:equatable/equatable.dart';

/// State của SettingsCubit — quản lý cấu hình bảo mật.
///
/// Tại sao dùng pinHash thay vì pinCode:
///   - Lưu hash SHA-256 thay vì PIN thô → bảo mật hơn
///   - Kể cả đọc được SharedPreferences cũng không biết PIN gốc
class SettingsState extends Equatable {
  /// Đã đọc xong cấu hình từ secure storage chưa.
  ///
  /// Quan trọng với màn hình khóa: [isPinEnabled] mặc định là false, nên
  /// trước khi nạp xong KHÔNG thể phân biệt "chưa cài PIN" với "chưa biết".
  /// Khóa app phải chờ cờ này bật rồi mới quyết định.
  final bool isLoaded;

  final bool isPinEnabled;

  /// Hash SHA-256 của PIN (64 ký tự hex). Không lưu PIN thô.
  final String? pinHash;

  /// Nâng cấp: Sinh trắc học & Câu hỏi bảo mật
  final bool isBiometricEnabled;
  final int? securityQuestionIndex;

  /// Hash SHA-256 của câu trả lời bảo mật (đã lowercase + trim)
  final String? securityAnswerHash;

  /// Số lần nhập sai PIN/câu hỏi bảo mật liên tiếp.
  final int failedAttempts;

  /// Thời điểm hết khóa tạm thời (null = không bị khóa).
  ///
  /// Lưu xuống SharedPreferences chứ không giữ trong RAM: nếu chỉ giữ trong
  /// RAM thì kill app rồi mở lại là reset bộ đếm → brute-force thoải mái.
  final DateTime? lockoutUntil;

  /// Còn đang trong thời gian bị khóa hay không.
  bool get isLockedOut =>
      lockoutUntil != null && lockoutUntil!.isAfter(DateTime.now());

  /// Thời gian còn lại của lần khóa hiện tại.
  Duration get remainingLockout {
    if (lockoutUntil == null) return Duration.zero;
    final remaining = lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  const SettingsState({
    this.isLoaded = false,
    this.isPinEnabled = false,
    this.pinHash,
    this.isBiometricEnabled = false,
    this.securityQuestionIndex,
    this.securityAnswerHash,
    this.failedAttempts = 0,
    this.lockoutUntil,
  });

  SettingsState copyWith({
    bool? isLoaded,
    bool? isPinEnabled,
    String? pinHash,
    bool clearPin = false,
    bool? isBiometricEnabled,
    int? securityQuestionIndex,
    String? securityAnswerHash,
    bool clearSecurity = false,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
  }) {
    return SettingsState(
      isLoaded: isLoaded ?? this.isLoaded,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      isBiometricEnabled: clearPin ? false : (isBiometricEnabled ?? this.isBiometricEnabled),
      securityQuestionIndex: clearSecurity ? null : (securityQuestionIndex ?? this.securityQuestionIndex),
      securityAnswerHash: clearSecurity ? null : (securityAnswerHash ?? this.securityAnswerHash),
      failedAttempts: clearLockout ? 0 : (failedAttempts ?? this.failedAttempts),
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    );
  }

  @override
  List<Object?> get props => [
        isLoaded,
        isPinEnabled,
        pinHash,
        isBiometricEnabled,
        securityQuestionIndex,
        securityAnswerHash,
        failedAttempts,
        lockoutUntil,
      ];
}
