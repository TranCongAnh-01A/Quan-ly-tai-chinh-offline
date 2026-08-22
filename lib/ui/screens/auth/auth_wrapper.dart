import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/settings/settings_cubit.dart';
import '../../../logic/settings/settings_state.dart';
import 'pin_screen.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;
  
  // Biến toàn cục để tạm dừng khóa (Dùng khi gọi FilePicker, Share, LocalAuth...)
  static bool pauseLock = false;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isShowingPinScreen = false;
  StreamSubscription<SettingsState>? _settingsSubscription;

  /// Đã đọc xong cấu hình PIN chưa — trước đó chưa biết có phải khóa hay không
  /// nên cứ che nội dung lại cho an toàn.
  bool _settingsLoaded = false;

  /// App có đang ở nền / đang chuyển nền không.
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  /// Quyết định có khóa app lúc khởi động hay không.
  ///
  /// SettingsCubit đọc PIN từ secure storage BẤT ĐỒNG BỘ, nên tại thời điểm
  /// này state có thể chưa nạp xong (isPinEnabled còn là false mặc định).
  /// Nếu đọc một lần rồi thôi, máy nạp keystore chậm sẽ vào thẳng app không
  /// khóa. Vì vậy phải chờ tới state đầu tiên có isLoaded = true.
  void _checkInitialLock() {
    final cubit = context.read<SettingsCubit>();

    if (_applyInitialLock(cubit.state)) return;

    _settingsSubscription = cubit.stream.listen((settingsState) {
      if (_applyInitialLock(settingsState)) {
        _settingsSubscription?.cancel();
        _settingsSubscription = null;
      }
    });
  }

  /// Trả về true khi đã có đủ thông tin để quyết định (không cần chờ nữa).
  bool _applyInitialLock(SettingsState settingsState) {
    if (!settingsState.isLoaded) return false;

    setState(() {
      _settingsLoaded = true;
      _isLocked = settingsState.isPinEnabled;
    });

    if (settingsState.isPinEnabled) {
      _showPinScreen();
    }
    return true;
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nếu đang tạm dừng khóa (do gọi native dialog) thì bỏ qua
    if (AuthWrapper.pauseLock) {
      if (state == AppLifecycleState.resumed) {
        // Reset lại cờ sau khi app đã resume an toàn
        // Dùng Future.delayed để đảm bảo hệ điều hành đã xử lý xong event
        Future.delayed(const Duration(milliseconds: 500), () {
          AuthWrapper.pauseLock = false;
        });
      }
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final isPinEnabled = context.read<SettingsCubit>().state.isPinEnabled;
      setState(() {
        // Che nội dung TRƯỚC khi hệ điều hành chụp ảnh màn hình đa nhiệm
        _isBackgrounded = isPinEnabled;
        if (isPinEnabled) _isLocked = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _isBackgrounded = false);
      if (_isLocked && !_isShowingPinScreen) {
        _showPinScreen();
      }
    }
  }

  Future<void> _showPinScreen() async {
    if (_isShowingPinScreen) return;
    _isShowingPinScreen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Có thể được gọi sau khi state settings nạp xong → phải kiểm tra mounted
      if (!mounted) {
        _isShowingPinScreen = false;
        return;
      }

      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PinScreen(mode: PinMode.verify),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          opaque: true,
        ),
      );

      if (mounted) {
        setState(() {
          _isLocked = false;
          _isShowingPinScreen = false;
        });
      }
    });
  }

  /// Có phải che nội dung app lại không.
  ///
  /// Ba trường hợp: chưa biết có PIN hay không, đang bị khóa nhưng màn hình
  /// PIN chưa kịp push (khe hở 1 frame), và app đang ở nền (ảnh chụp màn hình
  /// đa nhiệm sẽ lộ số dư + giao dịch).
  bool get _shouldObscure => !_settingsLoaded || _isLocked || _isBackgrounded;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Giữ nguyên widget.child trong cây (không rebuild, không mất state
        // của AppNavigation), chỉ phủ lớp che lên trên.
        if (_shouldObscure) const _PrivacyCover(),
      ],
    );
  }
}

/// Lớp phủ kín màn hình, dùng cả cho lúc khóa lẫn lúc app ở nền.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Icon(
          Icons.lock_outline,
          size: 48,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
