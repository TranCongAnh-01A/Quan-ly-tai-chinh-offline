import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mone_jour/logic/settings/settings_cubit.dart';
import 'package:mone_jour/services/secure_storage_service.dart';
import 'package:mone_jour/ui/screens/auth/pin_screen.dart';
import 'package:mone_jour/ui/screens/auth/widgets/pin_widgets.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorage storage;

  setUp(() {
    storage = MockSecureStorage();
    when(() => storage.read(any())).thenAnswer((_) async => 'hash-cua-pin');
    when(() => storage.write(any(), any())).thenAnswer((_) async {});
    when(() => storage.delete(any())).thenAnswer((_) async {});
  });

  /// Tao cubit va cho no doc xong cau hinh.
  ///
  /// Phai dung runAsync: trong testWidgets moi Future chay duoi fake async,
  /// `await Future.delayed(...)` se treo mai vi khong ai advance dong ho.
  Future<SettingsCubit> makeCubit(WidgetTester tester) async {
    late SettingsCubit cubit;
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      cubit = SettingsCubit(prefs, secureStorage: storage);
      await Future.delayed(Duration.zero);
    });
    return cubit;
  }

  Widget wrap(SettingsCubit cubit) {
    return BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: PinScreen(mode: PinMode.verify)),
    );
  }

  testWidgets('Khong tran layout tren man hinh thap (800x600)', (tester) async {
    // Viewport mac dinh cua flutter_test — truoc day Column bi overflow.
    // Neu tran, framework nem FlutterError khi paint va test tu fail.
    SharedPreferences.setMockInitialValues({});
    final cubit = await makeCubit(tester);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.byType(PinNumpad), findsOneWidget);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets('Khong tran layout tren man hinh rat thap (400x400)',
      (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final cubit = await makeCubit(tester);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets('Dang bi khoa: hien dem nguoc va chan nut Quen ma PIN',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'monejour_pin_failed_attempts': 5,
      'monejour_pin_lockout_until':
          DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch,
    });
    final cubit = await makeCubit(tester);

    await tester.pumpWidget(wrap(cubit));
    await tester.pump();

    expect(find.text('Nhập sai quá nhiều lần'), findsOneWidget);
    expect(find.textContaining('Thử lại sau'), findsOneWidget);

    // Ban phim bi tat
    final numpad = tester.widget<PinNumpad>(find.byType(PinNumpad));
    expect(numpad.enabled, isFalse);

    // Nut "Quen ma PIN?" cung bi vo hieu hoa
    final forgotButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Quên mã PIN?'),
    );
    expect(forgotButton.onPressed, isNull);

    // Thao man hinh de dispose() huy timer dem nguoc
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
  });

  testWidgets('Khong bi khoa: ban phim hoat dong binh thuong', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final cubit = await makeCubit(tester);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    final numpad = tester.widget<PinNumpad>(find.byType(PinNumpad));
    expect(numpad.enabled, isTrue);
    expect(find.text('Nhập sai quá nhiều lần'), findsNothing);

    await cubit.close();
  });
}
