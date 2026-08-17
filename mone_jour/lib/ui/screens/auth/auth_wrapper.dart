import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/settings/settings_cubit.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  void _checkInitialLock() {
    final cubit = context.read<SettingsCubit>();
    if (cubit.state.isPinEnabled) {
      setState(() {
        _isLocked = true;
      });
      _showPinScreen();
    }
  }

  @override
  void dispose() {
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
      if (isPinEnabled && !_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocked && !_isShowingPinScreen) {
        _showPinScreen();
      }
    }
  }

  Future<void> _showPinScreen() async {
    if (_isShowingPinScreen) return;
    _isShowingPinScreen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
