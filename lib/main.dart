import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
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

  // Khởi tạo locale tiếng Việt cho DateFormat (intl package)
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo database
  await DatabaseService.initialize();

  final prefs = await SharedPreferences.getInstance();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER_ERROR: ${details.exception}');
    debugPrint('STACK_TRACE: ${details.stack}');
  };

  runApp(MoneJourApp(prefs: prefs));
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
