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
