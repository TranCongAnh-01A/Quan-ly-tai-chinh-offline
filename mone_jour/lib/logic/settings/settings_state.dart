import 'package:equatable/equatable.dart';

/// State của SettingsCubit — quản lý cấu hình bảo mật.
///
/// Tại sao dùng pinHash thay vì pinCode:
///   - Lưu hash SHA-256 thay vì PIN thô → bảo mật hơn
///   - Kể cả đọc được SharedPreferences cũng không biết PIN gốc
class SettingsState extends Equatable {
  final bool isPinEnabled;

  /// Hash SHA-256 của PIN (64 ký tự hex). Không lưu PIN thô.
  final String? pinHash;

  /// Nâng cấp: Sinh trắc học & Câu hỏi bảo mật
  final bool isBiometricEnabled;
  final int? securityQuestionIndex;

  /// Hash SHA-256 của câu trả lời bảo mật (đã lowercase + trim)
  final String? securityAnswerHash;

  const SettingsState({
    this.isPinEnabled = false,
    this.pinHash,
    this.isBiometricEnabled = false,
    this.securityQuestionIndex,
    this.securityAnswerHash,
  });

  SettingsState copyWith({
    bool? isPinEnabled,
    String? pinHash,
    bool clearPin = false,
    bool? isBiometricEnabled,
    int? securityQuestionIndex,
    String? securityAnswerHash,
    bool clearSecurity = false,
  }) {
    return SettingsState(
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      isBiometricEnabled: clearPin ? false : (isBiometricEnabled ?? this.isBiometricEnabled),
      securityQuestionIndex: clearSecurity ? null : (securityQuestionIndex ?? this.securityQuestionIndex),
      securityAnswerHash: clearSecurity ? null : (securityAnswerHash ?? this.securityAnswerHash),
    );
  }

  @override
  List<Object?> get props => [
        isPinEnabled,
        pinHash,
        isBiometricEnabled,
        securityQuestionIndex,
        securityAnswerHash,
      ];
}
