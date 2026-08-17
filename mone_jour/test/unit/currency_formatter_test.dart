import 'package:flutter_test/flutter_test.dart';
import 'package:mone_jour/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formatVND formats zero correctly', () {
      expect(formatVND(0), equals('0 ₫'));
    });

    test('formatVND formats positive integers correctly', () {
      expect(formatVND(1000), equals('1.000 ₫'));
      expect(formatVND(1000000), equals('1.000.000 ₫'));
      expect(formatVND(50000), equals('50.000 ₫'));
    });

    test('formatVND formats negative amounts correctly', () {
      expect(formatVND(-250000), equals('-250.000 ₫'));
    });

    test('formatVND rounds decimals to nearest integer', () {
      // formatVND uses .round() trước khi format
      expect(formatVND(1000.6), equals('1.001 ₫'));
      expect(formatVND(1000.4), equals('1.000 ₫'));
    });

    test('formatVND handles large numbers', () {
      expect(formatVND(999999999), equals('999.999.999 ₫'));
    });
  });
}
