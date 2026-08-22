import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/receipt_storage.dart';
import 'logic/budget/budget_cubit.dart';
import 'logic/expense/expense_cubit.dart';
import 'logic/fixed_expense/fixed_expense_cubit.dart';
import 'logic/journal/journal_cubit.dart';
import 'logic/stats/stats_cubit.dart';
import 'data/repositories/journal_repository.dart';
import 'logic/theme/theme_cubit.dart';
import 'logic/settings/settings_cubit.dart';
import 'services/database_service.dart';
import 'ui/screens/splash/splash_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/cloud_sync_service.dart';
import 'services/export_service.dart';
import 'services/import_service.dart';
import 'logic/cloud_sync/cloud_sync_cubit.dart';

/// Entry point — khởi tạo locale + Isar database trước khi chạy app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đặt handler TRƯỚC mọi khởi tạo, nếu không thì lỗi xảy ra trong lúc khởi
  // tạo sẽ không đi qua đây.
  FlutterError.onError = (FlutterErrorDetails details) {
    // presentError giữ nguyên hành vi mặc định (in lỗi + stack ra log).
    // Nếu chỉ debugPrint như trước thì ở bản release lỗi bị nuốt hoàn toàn.
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT_ASYNC_ERROR: $error');
    debugPrint('STACK_TRACE: $stack');
    return true;
  };

  await _bootstrap();
}

/// Khởi tạo các thành phần bắt buộc rồi chạy app.
///
/// Nếu mở database thất bại thì trước đây app đứng ở màn hình trắng, không
/// thông báo gì. Giờ hiện màn hình lỗi có nút thử lại.
Future<void> _bootstrap() async {
  try {
    // Khởi tạo locale tiếng Việt cho DateFormat (intl package)
    await initializeDateFormatting('vi_VN', null);

    // Khởi tạo database
    await DatabaseService.initialize();

    // Cache đường dẫn thư mục documents cho ảnh hóa đơn (xem ReceiptStorage)
    await ReceiptStorage.initialize();

    final prefs = await SharedPreferences.getInstance();

    runApp(MoneJourApp(prefs: prefs));
  } catch (e, stackTrace) {
    debugPrint('STARTUP_ERROR: $e');
    debugPrint('STACK_TRACE: $stackTrace');
    runApp(StartupErrorApp(error: e));
  }
}

/// Màn hình hiển thị khi app không khởi tạo được.
class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Không mở được ứng dụng',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dữ liệu của bạn vẫn còn trên máy. '
                  'Hãy thử lại, nếu vẫn lỗi thì khởi động lại ứng dụng.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _bootstrap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Root widget — cấu hình theme + BlocProviders + navigation.
class MoneJourApp extends StatelessWidget {
  final SharedPreferences prefs;

  // ignore: prefer_const_constructors_in_immutables
  MoneJourApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeCubit(prefs)..loadTheme(),
        ),
        BlocProvider(
          create: (_) => ExpenseCubit()..loadMonth(),
        ),
        BlocProvider(
          create: (_) => FixedExpenseCubit()..loadTemplates(),
        ),
        BlocProvider(
          create: (_) => BudgetCubit()..loadBudgets(),
        ),
        BlocProvider(
          create: (_) => JournalCubit(JournalRepository())..loadJournals(),
        ),
        BlocProvider(
          create: (_) => StatsCubit()..loadStatsByMonth(DateTime.now().month, DateTime.now().year),
        ),
        BlocProvider(
          create: (_) => SettingsCubit(prefs),
        ),
        BlocProvider(
          create: (_) => CloudSyncCubit(
            CloudSyncService(),
            ExportService(),
            ImportService(),
            prefs,
          ),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Giản Ký',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeState.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'),
              Locale('en', 'US'),
            ],
            home: SplashScreen(prefs: prefs),
          );
        },
      ),
    );
  }
}
