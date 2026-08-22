import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../ui/screens/auth/auth_wrapper.dart';

/// Lỗi đồng bộ đã được diễn giải thành thông báo đọc được cho người dùng.
class CloudSyncFailure implements Exception {
  final String message;

  const CloudSyncFailure(this.message);

  @override
  String toString() => message;
}

/// Thông tin bản sao lưu đang nằm trên Drive.
class RemoteBackupInfo {
  final String fileId;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  const RemoteBackupInfo({
    required this.fileId,
    this.modifiedTime,
    this.sizeBytes,
  });
}

/// HTTP client wrapper — đính kèm auth headers vào mọi request gửi đến Google API.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Service xử lý đồng bộ dữ liệu với Google Drive.
///
/// Lưu trữ file backup JSON trong thư mục ẩn `appDataFolder` (không hiển thị
/// trong Drive của người dùng), tự động ghi đè file cũ thay vì tạo file mới.
class CloudSyncService {
  /// Gói backup hiện tại: ZIP gồm dữ liệu + ảnh hóa đơn.
  static const String backupFileName = 'MoneJour_Cloud_Backup.zip';

  /// Tên file của định dạng cũ (JSON thuần, không có ảnh).
  ///
  /// Vẫn phải đọc được để người đã sao lưu bằng bản cũ không mất dữ liệu.
  static const String legacyBackupFileName = 'MoneJour_Cloud_Backup.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  /// Đăng nhập bằng Google — hiển thị giao diện chọn tài khoản
  ///
  /// Bảng chọn tài khoản của Google đẩy app ra nền, nên phải tạm dừng khóa
  /// PIN giống các luồng native khác (Share, FilePicker, ImagePicker) — nếu
  /// không thì quay lại app là bị bắt nhập PIN giữa chừng thao tác sao lưu.
  Future<GoogleSignInAccount?> signIn() async {
    AuthWrapper.pauseLock = true;
    try {
      return await _googleSignIn.signIn();
    } catch (e, stackTrace) {
      debugPrint('CloudSync signIn ERROR: $e');
      debugPrint('CloudSync signIn STACK: $stackTrace');
      return null;
    } finally {
      AuthWrapper.pauseLock = false;
    }
  }

  /// Đăng xuất khỏi Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Trả về tài khoản hiện tại nếu đã đăng nhập từ trước (tự động đăng nhập im lặng)
  Future<GoogleSignInAccount?> getSignedInAccount() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        return _googleSignIn.signInSilently();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Tạo DriveApi client có xác thực từ tài khoản đang đăng nhập.
  ///
  /// [interactive] = false thì KHÔNG bật bảng chọn tài khoản khi phiên im lặng
  /// thất bại — dùng cho các luồng chỉ đọc thông tin hiển thị. Nếu không,
  /// chỉ mở màn hình Cài đặt cũng có thể bung popup đăng nhập của Google.
  Future<drive.DriveApi> _getDriveApi({bool interactive = true}) async {
    final account = await getSignedInAccount() ??
        (interactive ? await signIn() : null);

    if (account == null) {
      throw const CloudSyncFailure('Bạn chưa đăng nhập Google.');
    }

    try {
      final headers = await account.authHeaders;
      return drive.DriveApi(GoogleAuthClient(headers));
    } catch (e) {
      throw CloudSyncFailure(_describeError(e));
    }
  }

  /// Diễn giải lỗi kỹ thuật thành thông báo người dùng hiểu được.
  ///
  /// Trước đây mọi lỗi đều thành một câu chung chung, không phân biệt được
  /// mất mạng với hết quota hay chưa cấp quyền Drive.
  static String describeError(Object error) => _describeError(error);

  static String _describeError(Object error) {
    if (error is CloudSyncFailure) return error.message;

    if (error is SocketException || error is http.ClientException) {
      return 'Không có kết nối mạng. Kiểm tra Internet rồi thử lại.';
    }

    if (error is TimeoutException) {
      return 'Kết nối tới Google Drive quá lâu. Thử lại sau.';
    }

    if (error is drive.DetailedApiRequestError) {
      switch (error.status) {
        case 401:
          return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
        case 403:
          final message = error.message ?? '';
          if (message.contains('quota') || message.contains('Quota')) {
            return 'Google Drive đã hết dung lượng trống.';
          }
          return 'Ứng dụng chưa được cấp quyền truy cập Google Drive.';
        case 404:
          return 'Không tìm thấy bản sao lưu trên Drive.';
        default:
          return 'Google Drive báo lỗi ${error.status}: ${error.message ?? ''}';
      }
    }

    return 'Lỗi không xác định: $error';
  }

  /// Tìm file backup trong appDataFolder theo tên.
  Future<RemoteBackupInfo?> _findBackup(
    drive.DriveApi driveApi,
    String name,
  ) async {
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      // trashed = false: files.list mặc định TRẢ VỀ CẢ file trong thùng rác,
      // ghi đè hay khôi phục nhầm bản đã xóa đều là chuyện không mong muốn.
      q: "name = '$name' and trashed = false",
      $fields: 'files(id, name, modifiedTime, size)',
      orderBy: 'modifiedTime desc',
    );

    final files = fileList.files;
    if (files == null || files.isEmpty) return null;

    final file = files.first;
    return RemoteBackupInfo(
      fileId: file.id!,
      modifiedTime: file.modifiedTime?.toLocal(),
      sizeBytes: int.tryParse(file.size ?? ''),
    );
  }

  /// Thông tin bản sao lưu hiện có trên Drive (gói mới ưu tiên hơn bản cũ).
  ///
  /// Dùng để hiển thị "sao lưu lần cuối" ngay cả trên máy mới cài — mốc thời
  /// gian lưu trong SharedPreferences là của riêng từng máy nên máy mới không
  /// biết gì về bản sao lưu đang có.
  Future<RemoteBackupInfo?> getRemoteBackupInfo() async {
    try {
      // Đây là luồng hiển thị, tuyệt đối không được bật popup đăng nhập
      final driveApi = await _getDriveApi(interactive: false);
      return await _findBackup(driveApi, backupFileName) ??
          await _findBackup(driveApi, legacyBackupFileName);
    } catch (e) {
      debugPrint('CloudSync backupInfo ERROR: $e');
      return null;
    }
  }

  /// Tải gói backup lên Drive (ghi đè bản cũ nếu đã có).
  ///
  /// Ném [CloudSyncFailure] kèm thông báo cụ thể khi thất bại.
  Future<void> backupArchive(List<int> bytes) async {
    try {
      final driveApi = await _getDriveApi();
      final existing = await _findBackup(driveApi, backupFileName);

      final media = drive.Media(
        Stream<List<int>>.fromIterable([bytes]),
        bytes.length,
      );

      if (existing != null) {
        await driveApi.files.update(
          drive.File(),
          existing.fileId,
          uploadMedia: media,
        );
      } else {
        await driveApi.files.create(
          drive.File()
            ..name = backupFileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }
    } catch (e) {
      debugPrint('CloudSync backup ERROR: $e');
      throw CloudSyncFailure(_describeError(e));
    }
  }

  /// Tải bản sao lưu từ Drive về.
  ///
  /// Trả về null nếu tài khoản chưa có bản sao lưu nào. [isLegacyJson] cho
  /// biết đây là định dạng JSON đời cũ hay gói .zip hiện tại.
  Future<({List<int> bytes, bool isLegacyJson})?> downloadBackup() async {
    try {
      final driveApi = await _getDriveApi();

      var isLegacy = false;
      var backup = await _findBackup(driveApi, backupFileName);

      if (backup == null) {
        backup = await _findBackup(driveApi, legacyBackupFileName);
        isLegacy = backup != null;
      }

      if (backup == null) return null;

      final media = await driveApi.files.get(
        backup.fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      return (bytes: bytes, isLegacyJson: isLegacy);
    } catch (e) {
      debugPrint('CloudSync restore ERROR: $e');
      throw CloudSyncFailure(_describeError(e));
    }
  }
}
