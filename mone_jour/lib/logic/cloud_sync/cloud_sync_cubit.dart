import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';

import 'cloud_sync_state.dart';

class CloudSyncCubit extends Cubit<CloudSyncState> {
  final CloudSyncService _syncService;
  final ExportService _exportService;
  final ImportService _importService;
  final SharedPreferences _prefs;

  CloudSyncCubit(
    this._syncService,
    this._exportService,
    this._importService,
    this._prefs,
  ) : super(CloudSyncInitial()) {
    _checkSignInSilently();
  }

  static const String _lastSyncKey = 'last_cloud_sync_time';

  Future<void> _checkSignInSilently() async {
    try {
      final account = await _syncService.getSignedInAccount();
      if (account != null) {
        final lastSync = _prefs.getString(_lastSyncKey);
        emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
      }
    } catch (_) {
      // Lần đầu mở app hoặc GoogleSignIn chưa sẵn sàng → bỏ qua
    }
  }

  Future<void> signIn() async {
    emit(CloudSyncLoading());
    final account = await _syncService.signIn();
    if (account != null) {
      final lastSync = _prefs.getString(_lastSyncKey);
      emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
    } else {
      emit(CloudSyncError("Đăng nhập thất bại hoặc bị hủy."));
      await Future.delayed(const Duration(seconds: 2));
      emit(CloudSyncInitial());
    }
  }

  Future<void> signOut() async {
    emit(CloudSyncLoading());
    await _syncService.signOut();
    emit(CloudSyncInitial());
  }

  /// Backup dữ liệu (Upload JSON)
  Future<void> backupNow() async {
    final account = await _syncService.getSignedInAccount();
    if (account == null) {
      emit(CloudSyncError("Vui lòng đăng nhập trước."));
      emit(CloudSyncInitial());
      return;
    }

    emit(CloudSyncLoading());
    try {
      final jsonString = await _exportService.getAllDataAsJsonString();
      final success = await _syncService.backupData(jsonString);
      
      if (success) {
        final now = DateTime.now().toString();
        await _prefs.setString(_lastSyncKey, now);
        emit(CloudSyncSuccess(
          message: "Sao lưu lên Google Drive thành công!",
          email: account.email,
          lastSyncTime: now,
        ));
      } else {
        emit(CloudSyncError("Lỗi khi sao lưu dữ liệu."));
        await Future.delayed(const Duration(seconds: 2));
        final lastSync = _prefs.getString(_lastSyncKey);
        emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
      }
    } catch (e) {
      emit(CloudSyncError("Đã xảy ra lỗi: $e"));
      await Future.delayed(const Duration(seconds: 2));
      final lastSync = _prefs.getString(_lastSyncKey);
      emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
    }
  }

  /// Khôi phục dữ liệu (Download JSON)
  Future<void> restoreNow() async {
    final account = await _syncService.getSignedInAccount();
    if (account == null) {
      emit(CloudSyncError("Vui lòng đăng nhập trước."));
      emit(CloudSyncInitial());
      return;
    }

    emit(CloudSyncLoading());
    try {
      final jsonString = await _syncService.restoreData();
      if (jsonString == null) {
        emit(CloudSyncError("Không tìm thấy bản sao lưu nào trên Drive của bạn."));
        await Future.delayed(const Duration(seconds: 2));
        final lastSync = _prefs.getString(_lastSyncKey);
        emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
        return;
      }

      final success = await _importService.importFromJsonString(jsonString);
      if (success) {
        final now = DateTime.now().toString();
        await _prefs.setString(_lastSyncKey, now);
        emit(CloudSyncSuccess(
          message: "Khôi phục dữ liệu thành công!",
          email: account.email,
          lastSyncTime: now,
        ));
      } else {
        emit(CloudSyncError("Lỗi khi ghi dữ liệu vào máy."));
        await Future.delayed(const Duration(seconds: 2));
        final lastSync = _prefs.getString(_lastSyncKey);
        emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
      }
    } catch (e) {
      emit(CloudSyncError("Đã xảy ra lỗi: $e"));
      await Future.delayed(const Duration(seconds: 2));
      final lastSync = _prefs.getString(_lastSyncKey);
      emit(CloudSyncConnected(email: account.email, lastSyncTime: lastSync));
    }
  }
}
