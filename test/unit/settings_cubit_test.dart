import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mone_jour/logic/settings/settings_cubit.dart';
import 'package:mone_jour/services/secure_storage_service.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late SettingsCubit cubit;
  late MockSecureStorage mockSecureStorage;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockSecureStorage = MockSecureStorage();

    when(() => mockSecureStorage.read(any())).thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(any(), any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(any())).thenAnswer((_) async {});
    
    cubit = SettingsCubit(prefs, secureStorage: mockSecureStorage);
    // Allow loadSettings to complete
    await Future.delayed(Duration.zero);
  });

  tearDown(() {
    cubit.close();
  });

  group('isLoaded — chong race khi khoa app luc khoi dong', () {
    test('State ban dau chua isLoaded, chi bat sau khi doc xong secure storage', () async {
      // Secure storage cham (VD: keystore khoi tao lan dau)
      final slowStorage = MockSecureStorage();
      final gate = Completer<String?>();
      when(() => slowStorage.read(any())).thenAnswer((_) => gate.future);
      when(() => slowStorage.write(any(), any())).thenAnswer((_) async {});

      final slowCubit = SettingsCubit(prefs, secureStorage: slowStorage);

      // Chua doc xong: isPinEnabled = false NHUNG isLoaded cung = false,
      // nghia la "chua biet" chu khong phai "chua cai PIN".
      expect(slowCubit.state.isLoaded, isFalse);
      expect(slowCubit.state.isPinEnabled, isFalse);

      gate.complete('hash-cua-pin');
      await Future.delayed(Duration.zero);

      expect(slowCubit.state.isLoaded, isTrue);
      expect(slowCubit.state.isPinEnabled, isTrue);

      await slowCubit.close();
    });

    test('isLoaded van bat khi secure storage nem loi', () async {
      final failingStorage = MockSecureStorage();
      when(() => failingStorage.read(any())).thenThrow(Exception('keystore hong'));
      when(() => failingStorage.write(any(), any())).thenAnswer((_) async {});

      final failingCubit = SettingsCubit(prefs, secureStorage: failingStorage);
      await Future.delayed(Duration.zero);

      // Neu isLoaded ket mai o false, man hinh khoa se cho vo han
      expect(failingCubit.state.isLoaded, isTrue);

      await failingCubit.close();
    });

    test('isLoaded duoc giu nguyen qua cac thao tac khac', () async {
      expect(cubit.state.isLoaded, isTrue);

      await cubit.setPin('1234');
      expect(cubit.state.isLoaded, isTrue);

      await cubit.removePin();
      expect(cubit.state.isLoaded, isTrue);
    });
  });

  group('Gioi han so lan nhap sai PIN', () {
    test('Duoi nguong thi chi tang bo dem, chua khoa', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout - 1; i++) {
        await cubit.registerFailedAttempt();
      }

      expect(cubit.state.failedAttempts, SettingsCubit.maxAttemptsBeforeLockout - 1);
      expect(cubit.state.isLockedOut, isFalse);
    });

    test('Cham nguong thi khoa tam thoi', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout; i++) {
        await cubit.registerFailedAttempt();
      }

      expect(cubit.state.isLockedOut, isTrue);
      expect(cubit.state.remainingLockout.inSeconds, greaterThan(0));
      expect(
        cubit.state.remainingLockout,
        lessThanOrEqualTo(SettingsCubit.lockoutSteps.first),
      );
    });

    test('Sai cang nhieu lan thi khoa cang lau', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout; i++) {
        await cubit.registerFailedAttempt();
      }
      final firstLockout = cubit.state.remainingLockout;

      await cubit.registerFailedAttempt();
      final secondLockout = cubit.state.remainingLockout;

      expect(secondLockout, greaterThan(firstLockout));
    });

    test('Thoi gian khoa co tran, khong vuot buoc cuoi cung', () async {
      for (var i = 0; i < 30; i++) {
        await cubit.registerFailedAttempt();
      }

      expect(
        cubit.state.remainingLockout,
        lessThanOrEqualTo(SettingsCubit.lockoutSteps.last),
      );
    });

    test('Bo dem duoc luu xuong prefs — kill app khong reset', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout; i++) {
        await cubit.registerFailedAttempt();
      }

      // Mo lai app: cubit moi doc lai tu cung SharedPreferences
      final revived = SettingsCubit(prefs, secureStorage: mockSecureStorage);
      await Future.delayed(Duration.zero);

      expect(revived.state.failedAttempts, SettingsCubit.maxAttemptsBeforeLockout);
      expect(revived.state.isLockedOut, isTrue);

      await revived.close();
    });

    test('Mo khoa thanh cong thi xoa bo dem', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout; i++) {
        await cubit.registerFailedAttempt();
      }
      expect(cubit.state.isLockedOut, isTrue);

      await cubit.resetFailedAttempts();

      expect(cubit.state.failedAttempts, 0);
      expect(cubit.state.isLockedOut, isFalse);

      // Va khong song lai sau khi mo app lan sau
      final revived = SettingsCubit(prefs, secureStorage: mockSecureStorage);
      await Future.delayed(Duration.zero);
      expect(revived.state.isLockedOut, isFalse);
      await revived.close();
    });

    test('Go bo PIN thi cung xoa trang thai khoa', () async {
      for (var i = 0; i < SettingsCubit.maxAttemptsBeforeLockout; i++) {
        await cubit.registerFailedAttempt();
      }

      await cubit.removePin();

      expect(cubit.state.isLockedOut, isFalse);
      expect(cubit.state.failedAttempts, 0);
    });

    test('Lockout da het han thi khong con tinh la bi khoa', () async {
      // Gia lap prefs con sot lai moc khoa trong qua khu
      SharedPreferences.setMockInitialValues({
        'monejour_pin_failed_attempts': 5,
        'monejour_pin_lockout_until':
            DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      });
      final stalePrefs = await SharedPreferences.getInstance();

      final staleCubit = SettingsCubit(stalePrefs, secureStorage: mockSecureStorage);
      await Future.delayed(Duration.zero);

      expect(staleCubit.state.isLockedOut, isFalse);
      expect(staleCubit.state.remainingLockout, Duration.zero);

      await staleCubit.close();
    });
  });

  test('Initial state is correct', () {
    expect(cubit.state.isPinEnabled, false);
    expect(cubit.state.isBiometricEnabled, false);
  });

  test('setPin updates state and secure storage', () async {
    await cubit.setPin('1234');
    expect(cubit.state.isPinEnabled, true);
    verify(() => mockSecureStorage.write(any(), any())).called(1);
  });

  test('setBiometricEnabled updates state and prefs', () async {
    await cubit.setBiometricEnabled(true);
    expect(cubit.state.isBiometricEnabled, true);
    expect(prefs.getBool('monejour_biometric_enabled'), true);
  });

  test('removePin clears settings', () async {
    await cubit.setPin('1234');
    await cubit.removePin();
    expect(cubit.state.isPinEnabled, false);
    verify(() => mockSecureStorage.delete(any())).called(greaterThan(0));
  });
}
