import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';

class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState(this.themeMode);

  @override
  List<Object> get props => [themeMode];
}

class ThemeCubit extends Cubit<ThemeState> {
  final SharedPreferences _prefs;
  static const _themeKey = 'theme_mode';

  ThemeCubit(this._prefs) : super(const ThemeState(ThemeMode.system));

  Future<void> loadTheme() async {
    final isDark = _prefs.getBool(_themeKey);
    if (isDark != null) {
      emit(ThemeState(isDark ? ThemeMode.dark : ThemeMode.light));
    } else {
      // Mặc định là sáng nếu chưa có cấu hình
      emit(const ThemeState(ThemeMode.light));
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    await _prefs.setBool(_themeKey, isDark);
    emit(ThemeState(isDark ? ThemeMode.dark : ThemeMode.light));
  }
}
