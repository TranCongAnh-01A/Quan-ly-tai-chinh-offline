import 'package:flutter/material.dart';

import '../screens/expense/expense_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/journal/journal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tutorial_dialog.dart';

/// Bottom Navigation chính của app.
///
/// 4 tab: Trang chủ | Chi tiêu | Ghi chú | Cài đặt
/// Dùng IndexedStack để giữ state khi chuyển tab (không rebuild).
class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0;

  // Danh sách các tab screens
  final _screens = const [
    HomeScreen(),
    ExpenseListScreen(),
    JournalScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final isTutorialShown = prefs.getBool('is_tutorial_shown') ?? false;

    if (!isTutorialShown && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const TutorialDialog(),
      );
      
      // Sau khi đóng dialog, đánh dấu là đã xem
      await prefs.setBool('is_tutorial_shown', true);
      
      // Hiện SnackBar hướng dẫn vị trí nút (!)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Để xem lại hướng dẫn, hãy ấn vào biểu tượng (i) ở góc trên bên trái!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Chi tiêu',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Ghi chú',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}

