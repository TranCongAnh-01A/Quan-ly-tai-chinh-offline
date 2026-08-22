import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

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
  static const String backupFileName = 'MoneJour_Cloud_Backup.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  /// Đăng nhập bằng Google — hiển thị giao diện chọn tài khoản
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e, stackTrace) {
      debugPrint('CloudSync signIn ERROR: $e');
      debugPrint('CloudSync signIn STACK: $stackTrace');
      return null;
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

  /// Tạo DriveApi client có xác thực từ tài khoản đang đăng nhập
  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await getSignedInAccount() ?? await signIn();
    if (account == null) return null;

    final headers = await account.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Lấy File ID nếu file backup đã tồn tại trong appDataFolder
  Future<String?> _getExistingBackupFileId(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$backupFileName'",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('CloudSync getFileId ERROR: $e');
      return null;
    }
  }

  /// Sao lưu dữ liệu JSON lên Google Drive (ghi đè file cũ nếu đã tồn tại)
  Future<bool> backupData(String jsonData) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final existingFileId = await _getExistingBackupFileId(driveApi);
      final bytes = utf8.encode(jsonData);
      final stream = Stream<List<int>>.fromIterable([bytes]);
      final media = drive.Media(stream, bytes.length);

      if (existingFileId != null) {
        // Ghi đè lên file cũ
        final driveFile = drive.File();
        await driveApi.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // Tạo file mới trong appDataFolder
        final driveFile = drive.File()
          ..name = backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return true;
    } catch (e) {
      debugPrint('CloudSync backup ERROR: $e');
      return false;
    }
  }

  /// Tải dữ liệu JSON từ Google Drive về
  Future<String?> restoreData() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final existingFileId = await _getExistingBackupFileId(driveApi);
      if (existingFileId == null) return null;

      final drive.Media fileMedia = await driveApi.files.get(
        existingFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (var data in fileMedia.stream) {
        dataStore.addAll(data);
      }

      return utf8.decode(dataStore);
    } catch (e) {
      debugPrint('CloudSync restore ERROR: $e');
      return null;
    }
  }
}
