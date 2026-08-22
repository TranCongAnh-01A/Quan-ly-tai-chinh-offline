import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Close Button (only on page 3)
            SizedBox(
              height: 56,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Hướng dẫn sử dụng',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (_currentPage == 2)
                    Positioned(
                      right: 8,
                      top: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildPage1(context),
                  _buildPage2(context),
                  _buildPage3(context),
                ],
              ),
            ),
            // Footer (Indicators & Navigation)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentPage > 0 ? _onBack : null,
                    child: Text(
                      'Trở lại',
                      style: TextStyle(
                        color: _currentPage > 0 ? AppTheme.primaryPastel : Colors.grey,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? AppTheme.primaryPastel
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _currentPage < 2 ? _onNext : null,
                    child: Text(
                      'Tiếp',
                      style: TextStyle(
                        color: _currentPage < 2 ? AppTheme.primaryPastel : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1(BuildContext context) {
    return _buildContent(
      context,
      icon: Icons.home_rounded,
      title: 'Trang Chủ',
      items: [
        'Tạo giao dịch: Bấm nút (+) trên thẻ Số dư hiện tại.',
        'Chi tiêu cố định: Nơi quản lý các khoản định kỳ. Lưu ý: Giao dịch được tạo từ đây là không thể chỉnh sửa.',
        'Hạn mức chi tiêu: Giúp bạn theo dõi không tiêu quá tay.',
        'Giao dịch gần đây: Ấn giữ một giao dịch để chỉnh sửa hoặc xóa.',
        'Bộ lọc: Biểu tượng phễu giúp bạn tìm kiếm và lọc giao dịch nhanh chóng.',
        'Chuyển tháng: Bấm mũi tên trái/phải trên cùng để xem tháng khác.',
      ],
    );
  }

  Widget _buildPage2(BuildContext context) {
    return _buildContent(
      context,
      icon: Icons.account_balance_wallet_rounded,
      title: 'Chi Tiêu',
      items: [
        'Thống kê: Biểu tượng biểu đồ ở góc trên cùng bên phải sẽ hiển thị thống kê chi tiết các khoản chi/thu.',
        'Tạo mới: Nút (+) lớn để thêm một khoản chi tiêu hoặc thu nhập mới giống như ở Trang chủ.',
        'Chuyển tháng: Bạn cũng có thể bấm mũi tên trên cùng để xem chi tiêu của các tháng khác.',
      ],
    );
  }

  Widget _buildPage3(BuildContext context) {
    return _buildContent(
      context,
      icon: Icons.settings_rounded,
      title: 'Cài Đặt',
      items: [
        'Đồng bộ Đám mây: Sao lưu dữ liệu lên Google Drive. Khi đổi máy hoặc mất dữ liệu, chỉ cần ấn Khôi phục để kéo bản backup gần nhất về.',
        'Khóa ứng dụng: Thiết lập mã PIN hoặc sinh trắc học để bảo mật ứng dụng của bạn.',
        'Xuất/Nhập dữ liệu: Cho phép bạn lưu dữ liệu ra file dưới dạng JSON hoặc CSV để quản lý thủ công.',
      ],
    );
  }

  Widget _buildContent(BuildContext context, {required IconData icon, required String title, required List<String> items}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(icon, size: 64, color: AppTheme.primaryPastel),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPastel,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
