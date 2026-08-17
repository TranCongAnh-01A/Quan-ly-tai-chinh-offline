import 'package:flutter/material.dart';
import '../pin_screen.dart';

class PinHeader extends StatelessWidget {
  final PinMode mode;
  final bool isConfirming;

  const PinHeader({
    super.key,
    required this.mode,
    required this.isConfirming,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    String subtitle;

    switch (mode) {
      case PinMode.verify:
        title = 'Nhập mã PIN';
        subtitle = 'Vui lòng nhập mã PIN để mở khóa';
        break;
      case PinMode.setup:
        title = isConfirming ? 'Xác nhận mã PIN' : 'Thiết lập mã PIN';
        subtitle = isConfirming
            ? 'Nhập lại mã PIN 4 số của bạn'
            : 'Tạo mã PIN 4 số để bảo vệ ứng dụng';
        break;
      case PinMode.remove:
        title = 'Gỡ bỏ mã PIN';
        subtitle = 'Nhập mã PIN hiện tại để gỡ bỏ';
        break;
    }

    return Column(
      children: [
        Icon(
          mode == PinMode.verify ? Icons.lock : Icons.security,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class PinIndicators extends StatelessWidget {
  final String enteredPin;

  const PinIndicators({super.key, required this.enteredPin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            border: isFilled
                ? null
                : Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
        );
      }),
    );
  }
}

class PinNumpad extends StatelessWidget {
  final void Function(String) onKeyPress;
  final VoidCallback onBackspace;
  final Widget biometricButton;

  const PinNumpad({
    super.key,
    required this.onKeyPress,
    required this.onBackspace,
    required this.biometricButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumpadButton('1', theme),
              _buildNumpadButton('2', theme),
              _buildNumpadButton('3', theme),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumpadButton('4', theme),
              _buildNumpadButton('5', theme),
              _buildNumpadButton('6', theme),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumpadButton('7', theme),
              _buildNumpadButton('8', theme),
              _buildNumpadButton('9', theme),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              biometricButton,
              _buildNumpadButton('0', theme),
              _buildBackspaceButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadButton(String number, ThemeData theme) {
    return InkWell(
      onTap: () => onKeyPress(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        child: Text(
          number,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return InkWell(
      onTap: onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Icon(
          Icons.backspace_outlined,
          size: 32,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
