import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:mone_jour/services/cloud_sync_service.dart';
import 'package:mone_jour/services/export_service.dart';
import 'package:mone_jour/services/import_service.dart';

void main() {
  group('ImportService.isValidBackup', () {
    test('Chấp nhận backup có dấu nhận dạng của app', () {
      final data = jsonDecode(jsonEncode({
        'appId': ExportService.backupAppId,
        'version': ExportService.backupFormatVersion,
        'exportedAt': '2026-08-22T10:00:00.000',
        'expenses': <dynamic>[],
      }));

      expect(ImportService.isValidBackup(data), isTrue);
    });

    test('Chấp nhận backup đời cũ (chưa có metadata) nếu có bảng dữ liệu', () {
      final data = jsonDecode(jsonEncode({
        'expenses': [
          {'id': 1, 'amount': 1000},
        ],
        'journals': <dynamic>[],
      }));

      expect(ImportService.isValidBackup(data), isTrue);
    });

    test('TỪ CHỐI file JSON lạ — đây là thứ từng xóa sạch dữ liệu', () {
      // Regression: trước đây mọi Map đều được nhận, clear() chạy trước khi
      // kiểm tra nên chọn nhầm file là mất trắng, mà app vẫn báo thành công.
      expect(ImportService.isValidBackup(jsonDecode('{"foo": 1}')), isFalse);
      expect(ImportService.isValidBackup(jsonDecode('{}')), isFalse);
    });

    test('TỪ CHỐI nội dung không phải object JSON', () {
      expect(ImportService.isValidBackup(jsonDecode('[1,2,3]')), isFalse);
      expect(ImportService.isValidBackup(jsonDecode('"chuoi"')), isFalse);
      expect(ImportService.isValidBackup(null), isFalse);
    });

    test('TỪ CHỐI khi các bảng có tên đúng nhưng sai kiểu', () {
      final data = jsonDecode(jsonEncode({'expenses': 'khong-phai-list'}));

      expect(ImportService.isValidBackup(data), isFalse);
    });
  });

  group('ImportService.backupCreatedAt', () {
    test('Đọc được mốc thời gian của backup mới', () {
      final data = <String, dynamic>{'exportedAt': '2026-08-22T10:30:00.000'};

      expect(ImportService.backupCreatedAt(data), DateTime(2026, 8, 22, 10, 30));
    });

    test('Backup đời cũ không có mốc thì trả null', () {
      expect(ImportService.backupCreatedAt(<String, dynamic>{}), isNull);
    });
  });

  group('CloudSyncService.describeError', () {
    test('Mất mạng', () {
      final message = CloudSyncService.describeError(
        const SocketException('failed host lookup'),
      );

      expect(message, contains('kết nối mạng'));
    });

    test('Token hết hạn (401)', () {
      final message = CloudSyncService.describeError(
        drive.DetailedApiRequestError(401, 'Invalid Credentials'),
      );

      expect(message, contains('hết hạn'));
    });

    test('Hết dung lượng Drive (403 + quota)', () {
      final message = CloudSyncService.describeError(
        drive.DetailedApiRequestError(403, 'The user has exceeded their quota'),
      );

      expect(message, contains('dung lượng'));
    });

    test('403 không phải quota thì báo thiếu quyền', () {
      final message = CloudSyncService.describeError(
        drive.DetailedApiRequestError(403, 'Insufficient permission'),
      );

      expect(message, contains('quyền'));
    });

    test('Lỗi client HTTP', () {
      final message = CloudSyncService.describeError(
        http.ClientException('connection closed'),
      );

      expect(message, contains('kết nối mạng'));
    });

    test('CloudSyncFailure giữ nguyên thông báo', () {
      final message = CloudSyncService.describeError(
        const CloudSyncFailure('Bạn chưa đăng nhập Google.'),
      );

      expect(message, 'Bạn chưa đăng nhập Google.');
    });

    test('Lỗi lạ vẫn có thông báo, không rỗng', () {
      final message = CloudSyncService.describeError(Exception('gi do'));

      expect(message, isNotEmpty);
    });
  });
}
