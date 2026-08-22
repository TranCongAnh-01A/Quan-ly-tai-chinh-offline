import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../auth/auth_wrapper.dart';
import '../../navigation/app_navigation.dart';

class SplashScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const SplashScreen({super.key, required this.prefs});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Tự động điều hướng sau khi hoàn thành hoạt ảnh
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800), // Thời gian hiệu ứng mờ dần
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(
              child: AppNavigation(),
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Lottie.asset(
          'assets/animations/splash.json', // Dùng bản json đã trích xuất
          width: 300,
          height: 300,
          fit: BoxFit.contain,
          repeat: false,
          errorBuilder: (context, error, stackTrace) {
            // Hiện chi tiết lỗi để tiện theo dõi nếu xảy ra lỗi
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Lỗi: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}
