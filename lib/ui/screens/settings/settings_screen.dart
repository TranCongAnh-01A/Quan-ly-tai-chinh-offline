import 'package:flutter/material.dart';

import '../../widgets/tutorial_dialog.dart';
import '../../widgets/animated_slide_down.dart';
import 'widgets/auto_backup_card.dart';
import 'widgets/settings_sections.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          tooltip: 'Hướng dẫn sử dụng',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const TutorialDialog(),
            );
          },
        ),
        title: Text(
          'Cài đặt',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: const [
          FadeInSlideDown(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionTitle(title: 'Đám mây'),
                SizedBox(height: 12),
                CloudSyncCard(),
              ],
            ),
          ),



          SizedBox(height: 24),
          FadeInSlideDown(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionTitle(title: 'Bảo mật'),
                SizedBox(height: 12),
                SecurityCard(),
              ],
            ),
          ),

          SizedBox(height: 24),
          FadeInSlideDown(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionTitle(title: 'Quản lý dữ liệu'),
                SizedBox(height: 12),
                DataCard(),
              ],
            ),
          ),
          SizedBox(height: 24),
          FadeInSlideDown(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionTitle(title: 'Sao lưu tự động'),
                SizedBox(height: 12),
                AutoBackupCard(),
              ],
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

