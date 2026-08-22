import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mone_jour/logic/settings/settings_cubit.dart';
import 'package:mone_jour/services/secure_storage_service.dart';
import 'package:mone_jour/ui/screens/auth/auth_wrapper.dart';
import 'package:mone_jour/ui/screens/auth/pin_screen.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Viewport mặc định của test là 800x600 — quá thấp cho bàn phím PIN nên
  /// Column bị overflow. Dùng kích thước gần với điện thoại thật.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap(SettingsCubit cubit) {
    return BlocProvider.value(
      value: cubit,
      child: const MaterialApp(
        home: AuthWrapper(
          child: Scaffold(body: Text('NOI DUNG APP')),
        ),
      ),
    );
  }

  testWidgets(
    'Khoa app ngay ca khi secure storage tra ve PIN CHAM hon luc dung widget',
    (tester) async {
      usePhoneViewport(tester);

      // Regression: truoc day AuthWrapper doc isPinEnabled DONG BO trong
      // initState. Secure storage tra ve muon => app vao thang khong khoa.
      final storage = MockSecureStorage();
      final gate = Completer<String?>();
      when(() => storage.read(any())).thenAnswer((_) => gate.future);
      when(() => storage.write(any(), any())).thenAnswer((_) async {});

      final cubit = SettingsCubit(prefs, secureStorage: storage);
      await tester.pumpWidget(wrap(cubit));

      // Chua doc xong PIN → chua co man hinh khoa
      expect(find.byType(PinScreen), findsNothing);

      // Secure storage tra ve: app DA CO PIN
      gate.complete('hash-cua-pin');
      await tester.pumpAndSettle();

      expect(find.byType(PinScreen), findsOneWidget);

      await cubit.close();
    },
  );

  testWidgets('Khong khoa khi nguoi dung chua cai PIN', (tester) async {
    usePhoneViewport(tester);

    final storage = MockSecureStorage();
    when(() => storage.read(any())).thenAnswer((_) async => null);
    when(() => storage.write(any(), any())).thenAnswer((_) async {});

    final cubit = SettingsCubit(prefs, secureStorage: storage);
    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.byType(PinScreen), findsNothing);
    expect(find.text('NOI DUNG APP'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('Che noi dung khi app vao nen (anh chup man hinh da nhiem)',
      (tester) async {
    usePhoneViewport(tester);

    final storage = MockSecureStorage();
    when(() => storage.read(any())).thenAnswer((_) async => 'hash-cua-pin');
    when(() => storage.write(any(), any())).thenAnswer((_) async {});

    final cubit = SettingsCubit(prefs, secureStorage: storage);
    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    // Dang o man hinh PIN -> mo khoa bang cach pop route
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(PinScreen), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    // App bi day ra nen
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    // Lop che phai xuat hien NGAY, truoc khi he dieu hanh chup anh
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await cubit.close();
  });

  testWidgets('Khong che gi khi app khong dat PIN', (tester) async {
    usePhoneViewport(tester);

    final storage = MockSecureStorage();
    when(() => storage.read(any())).thenAnswer((_) async => null);
    when(() => storage.write(any(), any())).thenAnswer((_) async {});

    final cubit = SettingsCubit(prefs, secureStorage: storage);
    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await cubit.close();
  });
}
