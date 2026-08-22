import 'dart:convert';

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
        await _emitConnected(account.email);
      }
    } catch (_) {
      // Lần đầu mở app hoặc GoogleSignIn chưa sẵn sàng → bỏ qua
    }
  }

  /// Phát trạng thái "đã kết nối" kèm mốc sao lưu.
  ///
  /// Mốc trên Drive được ưu tiên hơn mốc lưu trong SharedPreferences: prefs là
  /// của riêng từng máy, nên máy mới cài sẽ hiện "chưa sao lưu" dù Drive đang
  /// có bản backup — đúng lúc người dùng cần biết nhất.
  Future<void> _emitConnected(String email, {String? message}) async {
    final remote = await _syncService.getRemoteBackupInfo();
    final localLastSync = _prefs.getString(_lastSyncKey);

    final lastSyncTime =
        remote?.modifiedTime?.toIso8601String() ?? localLastSync;

    if (message != null) {
      emit(CloudSyncSuccess(
        message: message,
        email: email,
        lastSyncTime: lastSyncTime,
        hasRemoteBackup: remote != null,
      ));
      return;
    }

    emit(CloudSyncConnected(
      email: email,
      lastSyncTime: lastSyncTime,
      hasRemoteBackup: remote != null,
    ));
  }

  /// Báo lỗi rồi quay lại trạng thái trước đó.
  Future<void> _emitErrorThenRestore(String message, String? email) async {
    emit(CloudSyncError(message));
    await Future.delayed(const Duration(seconds: 2));

    if (email == null) {
      emit(CloudSyncInitial());
      return;
    }
    await _emitConnected(email);
  }

  Future<void> signIn() async {
    emit(CloudSyncLoading());
    try {
      final account = await _syncService.signIn();

      if (account == null) {
        // null = người dùng tự bấm hủy, không phải lỗi
        emit(CloudSyncInitial());
        return;
      }

      await _emitConnected(account.email);
    } on CloudSyncFailure catch (e) {
      await _emitErrorThenRestore(e.message, null);
    } catch (e) {
      await _emitErrorThenRestore(CloudSyncService.describeError(e), null);
    }
  }

  Future<void> signOut() async {
    emit(CloudSyncLoading());
    await _syncService.signOut();
    // Mốc sao lưu là của tài khoản vừa thoát — giữ lại sẽ hiển thị sai khi
    // đăng nhập bằng tài khoản khác.
    await _prefs.remove(_lastSyncKey);
    emit(CloudSyncInitial());
  }

  /// Backup dữ liệu (Upload gói .zip gồm dữ liệu + ảnh hóa đơn)
  Future<void> backupNow() async {
    final account = await _syncService.getSignedInAccount();
    if (account == null) {
      await _emitErrorThenRestore('Vui lòng đăng nhập trước.', null);
      return;
    }

    emit(CloudSyncLoading());
    try {
      final archive = await _exportService.buildBackupArchive();
      await _syncService.backupArchive(archive);

      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      await _emitConnected(
        account.email,
        message: 'Sao lưu lên Google Drive thành công!',
      );
    } on CloudSyncFailure catch (e) {
      await _emitErrorThenRestore(e.message, account.email);
    } catch (e) {
      await _emitErrorThenRestore(
        CloudSyncService.describeError(e),
        account.email,
      );
    }
  }

  /// Khôi phục dữ liệu từ Drive
  Future<void> restoreNow() async {
    final account = await _syncService.getSignedInAccount();
    if (account == null) {
      await _emitErrorThenRestore('Vui lòng đăng nhập trước.', null);
      return;
    }

    emit(CloudSyncLoading());
    try {
      final download = await _syncService.downloadBackup();

      if (download == null) {
        await _emitErrorThenRestore(
          'Không tìm thấy bản sao lưu nào trên Drive của bạn.',
          account.email,
        );
        return;
      }

      // Bản sao lưu đời cũ là JSON thuần (không kèm ảnh hóa đơn)
      final success = download.isLegacyJson
          ? await _importService.importFromJsonString(utf8.decode(download.bytes))
          : await _importService.importFromArchiveBytes(download.bytes);

      if (!success) {
        await _emitErrorThenRestore(
          'Bản sao lưu không đọc được hoặc đã hỏng. '
          'Dữ liệu trên máy được giữ nguyên.',
          account.email,
        );
        return;
      }

      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      await _emitConnected(
        account.email,
        message: 'Khôi phục dữ liệu thành công!',
      );
    } on CloudSyncFailure catch (e) {
      await _emitErrorThenRestore(e.message, account.email);
    } catch (e) {
      await _emitErrorThenRestore(
        CloudSyncService.describeError(e),
        account.email,
      );
    }
  }
}
