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
    // Migration: chuyển plaintext → hash nếu cần
    await _migrateLegacyPin();
    await _migrateLegacySecurityAnswer();

    final pinHash = await _secureStorage.read(_pinHashKey);
    final isBiometricEnabled = _prefs.getBool(_biometricKey) ?? false;
    final securityQuestionIndex = _prefs.getInt(_securityQuestionIndexKey);
    final securityAnswerHash = await _secureStorage.read(_securityAnswerHashKey);

    emit(state.copyWith(
      isPinEnabled: pinHash != null && pinHash.isNotEmpty,
      pinHash: pinHash,
      isBiometricEnabled: isBiometricEnabled,
      securityQuestionIndex: securityQuestionIndex,
      securityAnswerHash: securityAnswerHash,
    ));
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
    emit(state.copyWith(
      isPinEnabled: false,
      clearPin: true,
      clearSecurity: true,
    ));
  }
}
