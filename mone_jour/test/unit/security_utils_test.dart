import 'package:flutter_test/flutter_test.dart';
import 'package:mone_jour/core/utils/security_utils.dart';

void main() {
  group('SecurityUtils Tests', () {
    test('hashPin returns consistent SHA-256 hash', () {
      const pin = '123456';
      final hash1 = SecurityUtils.hashPin(pin);
      final hash2 = SecurityUtils.hashPin(pin);
      
      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
      expect(hash1.length, 64); // SHA-256 hex string is 64 chars
    });

    test('verifyPin correctly validates pin against hash', () {
      const pin = '123456';
      final hash = SecurityUtils.hashPin(pin);
      
      expect(SecurityUtils.verifyPin(pin, hash), isTrue);
      expect(SecurityUtils.verifyPin('654321', hash), isFalse);
    });

    test('verifyPin handles null or empty stored hash', () {
      expect(SecurityUtils.verifyPin('123456', null), isFalse);
      expect(SecurityUtils.verifyPin('123456', ''), isFalse);
    });

    test('hashSecurityAnswer normalizes string before hashing', () {
      const answer1 = '  My Answer  ';
      const answer2 = 'my answer';
      const answer3 = 'MY ANSWER';
      
      final hash1 = SecurityUtils.hashSecurityAnswer(answer1);
      final hash2 = SecurityUtils.hashSecurityAnswer(answer2);
      final hash3 = SecurityUtils.hashSecurityAnswer(answer3);
      
      expect(hash1, equals(hash2));
      expect(hash2, equals(hash3));
    });

    test('verifySecurityAnswer correctly validates regardless of case or trailing spaces', () {
      const originalAnswer = '  Hà Nội  ';
      final storedHash = SecurityUtils.hashSecurityAnswer(originalAnswer);
      
      expect(SecurityUtils.verifySecurityAnswer('Hà Nội', storedHash), isTrue);
      expect(SecurityUtils.verifySecurityAnswer('hà nội', storedHash), isTrue);
      expect(SecurityUtils.verifySecurityAnswer('HÀ NỘI', storedHash), isTrue);
      expect(SecurityUtils.verifySecurityAnswer('Hồ Chí Minh', storedHash), isFalse);
    });
  });
}
