import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/security_utils.dart';
import '../../services/secure_storage_service.dart';
import 'settings_state.dart';

/// Cubit quản lý cài đặt bảo mật (PIN, Biometric, Câu hỏi bảo mật).
///
/// Tại sao inject SharedPreferences thay vì getInstance() mỗi lần:
///   - Tránh tạo Future không cần thiết mỗi lần gọi method
///   - SharedPreferences.getInstance() cache sẵn nhưng vẫn là async call
///   - Inject 1 lần trong constructor → sync access, dễ test
class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  // ── Key mới (lưu hash SHA-256) ──
  static const String _pinHashKey = 'monejour_pin_hash';
  static const String _biometricKey = 'monejour_biometric_enabled';
  static const String _securityQuestionIndexKey = 'monejour_security_question_index';
  static const String _securityAnswerHashKey = 'monejour_security_answer_hash';
  static const String _failedAttemptsKey = 'monejour_pin_failed_attempts';
  static const String _lockoutUntilKey = 'monejour_pin_lockout_until';

  /// Số lần sai được phép trước khi bắt đầu khóa tạm thời.
  static const int maxAttemptsBeforeLockout = 5;

  /// Thời gian khóa tăng dần theo số lần sai tính từ lần thứ 5.
  /// Lần sai thứ 5 → 30 giây, thứ 6 → 1 phút, ... từ thứ 9 trở đi → 30 phút.
  static const List<Duration> lockoutSteps = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  // ── Key cũ (chỉ dùng cho migration từ plaintext) ──
  static const String _legacyPinKey = 'monejour_pin_code';
  static const String _legacySecurityAnswerKey = 'monejour_security_answer';

  SettingsCubit(this._prefs, {SecureStorageService? secureStorage}) 
      : _secureStorage = secureStorage ?? const SecureStorageService(),
        super(const SettingsState()) {
    _loadSettings();
  }

  /// Tải cài đặt từ SharedPreferences + tự động migrate plaintext → hash.
  ///
  /// Luồng migration (chỉ chạy 1 lần sau khi update app):
  ///   1. Kiểm tra key cũ còn tồn tại không (plaintext)
  ///   2. Nếu có → hash giá trị cũ → lưu vào key mới → xóa key cũ
  ///   3. Các lần sau chỉ đọc từ key mới (hash)
  Future<void> _loadSettings() async {
    try {
      // Migration: chuyển plaintext → hash nếu cần
      await _migrateLegacyPin();
      await _migrateLegacySecurityAnswer();

      final pinHash = await _secureStorage.read(_pinHashKey);
      final isBiometricEnabled = _prefs.getBool(_biometricKey) ?? false;
      final securityQuestionIndex = _prefs.getInt(_securityQuestionIndexKey);
      final securityAnswerHash =
          await _secureStorage.read(_securityAnswerHashKey);
      final lockoutMillis = _prefs.getInt(_lockoutUntilKey);

      emit(state.copyWith(
        isLoaded: true,
        failedAttempts: _prefs.getInt(_failedAttemptsKey) ?? 0,
        lockoutUntil: lockoutMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lockoutMillis),
        isPinEnabled: pinHash != null && pinHash.isNotEmpty,
        pinHash: pinHash,
        isBiometricEnabled: isBiometricEnabled,
        securityQuestionIndex: securityQuestionIndex,
        securityAnswerHash: securityAnswerHash,
      ));
    } catch (e) {
      // Secure storage lỗi (VD: keystore hỏng sau khi khôi phục backup).
      // Vẫn phải bật isLoaded, nếu không màn hình khóa sẽ chờ mãi.
      debugPrint('SettingsCubit load ERROR: $e');
      emit(state.copyWith(isLoaded: true));
    }
  }

  /// Migration: chuyển PIN plaintext (key cũ) sang SHA-256 hash (key mới).
  Future<void> _migrateLegacyPin() async {
    final legacyPin = _prefs.getString(_legacyPinKey);
    if (legacyPin != null && legacyPin.isNotEmpty) {
      final hash = SecurityUtils.hashPin(legacyPin);
      await _secureStorage.write(_pinHashKey, hash);
      await _prefs.remove(_legacyPinKey);
    }
  }

  /// Migration: chuyển security answer plaintext sang SHA-256 hash.
  Future<void> _migrateLegacySecurityAnswer() async {
    final legacyAnswer = _prefs.getString(_legacySecurityAnswerKey);
    if (legacyAnswer != null && legacyAnswer.isNotEmpty) {
      final hash = SecurityUtils.hashSecurityAnswer(legacyAnswer);
      await _secureStorage.write(_securityAnswerHashKey, hash);
      await _prefs.remove(_legacySecurityAnswerKey);
    }
  }

  /// Thiết lập PIN mới — hash trước khi lưu.
  Future<void> setPin(String pin) async {
    final hash = SecurityUtils.hashPin(pin);
    await _secureStorage.write(_pinHashKey, hash);
    emit(state.copyWith(
      isPinEnabled: true,
      pinHash: hash,
    ));
  }

  /// Thiết lập câu hỏi bảo mật — hash answer trước khi lưu.
  Future<void> setSecurityQuestion(int questionIndex, String answer) async {
    final hash = SecurityUtils.hashSecurityAnswer(answer);
    await _prefs.setInt(_securityQuestionIndexKey, questionIndex);
    await _secureStorage.write(_securityAnswerHashKey, hash);
    emit(state.copyWith(
      securityQuestionIndex: questionIndex,
      securityAnswerHash: hash,
    ));
  }

  /// Bật/tắt sinh trắc học.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricKey, enabled);
    emit(state.copyWith(
      isBiometricEnabled: enabled,
    ));
  }

  /// Xóa toàn bộ cài đặt bảo mật (PIN + Biometric + Câu hỏi).
  Future<void> removePin() async {
    await _secureStorage.delete(_pinHashKey);
    await _prefs.remove(_biometricKey);
    await _prefs.remove(_securityQuestionIndexKey);
    await _secureStorage.delete(_securityAnswerHashKey);
    await _prefs.remove(_failedAttemptsKey);
    await _prefs.remove(_lockoutUntilKey);
    emit(state.copyWith(
      isPinEnabled: false,
      clearPin: true,
      clearSecurity: true,
      clearLockout: true,
    ));
  }

  /// Ghi nhận 1 lần nhập sai PIN (hoặc sai câu trả lời bảo mật).
  ///
  /// Từ lần sai thứ [maxAttemptsBeforeLockout] trở đi thì khóa tạm thời với
  /// thời gian tăng dần — PIN chỉ có 4 chữ số nên nếu không chặn thì dò hết
  /// 10.000 khả năng là chuyện vài phút.
  Future<void> registerFailedAttempt() async {
    final attempts = state.failedAttempts + 1;
    await _prefs.setInt(_failedAttemptsKey, attempts);

    if (attempts < maxAttemptsBeforeLockout) {
      emit(state.copyWith(failedAttempts: attempts));
      return;
    }

    final stepIndex = (attempts - maxAttemptsBeforeLockout)
        .clamp(0, lockoutSteps.length - 1);
    final lockoutUntil = DateTime.now().add(lockoutSteps[stepIndex]);

    await _prefs.setInt(_lockoutUntilKey, lockoutUntil.millisecondsSinceEpoch);

    emit(state.copyWith(
      failedAttempts: attempts,
      lockoutUntil: lockoutUntil,
    ));
  }

  /// Xóa bộ đếm sau khi mở khóa thành công.
  Future<void> resetFailedAttempts() async {
    await _prefs.remove(_failedAttemptsKey);
    await _prefs.remove(_lockoutUntilKey);

    emit(state.copyWith(clearLockout: true));
  }
}
