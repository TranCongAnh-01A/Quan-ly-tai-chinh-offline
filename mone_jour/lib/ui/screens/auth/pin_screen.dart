import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/security_utils.dart';
import '../../../logic/settings/settings_cubit.dart';
import 'auth_wrapper.dart';
import 'widgets/pin_widgets.dart';

enum PinMode { verify, setup, remove }

class PinScreen extends StatefulWidget {
  final PinMode mode;

  const PinScreen({super.key, required this.mode});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _enteredPin = '';
  String _setupFirstPin = '';
  bool _isConfirming = false;
  bool _hasError = false;

  final List<String> _securityQuestions = [
    'Tên thú cưng đầu tiên của bạn là gì?',
    'Bạn học trường tiểu học nào?',
    'Tên người bạn thân nhất thời thơ ấu?',
    'Món ăn yêu thích nhất của bạn là gì?',
    'Thành phố nơi mẹ bạn sinh ra?'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinMode.verify) {
      _checkBiometricAuth();
    }
  }

  Future<void> _checkBiometricAuth() async {
    final cubit = context.read<SettingsCubit>();
    if (cubit.state.isBiometricEnabled) {
      // Đợi UI render xong rồi gọi
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      AuthWrapper.pauseLock = true;
      final authenticated = await auth.authenticate(
        localizedReason: 'Xác thực để mở khóa Giản Ký',
        biometricOnly: true,
      );
      AuthWrapper.pauseLock = false;
      if (authenticated && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AuthWrapper.pauseLock = false;
    }
  }

  void _onKeyPress(String key) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += key;
        _hasError = false;
      });

      if (_enteredPin.length == 4) {
        _processPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _processPin() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final cubit = context.read<SettingsCubit>();
    final pinHash = cubit.state.pinHash;

    switch (widget.mode) {
      case PinMode.verify:
        if (SecurityUtils.verifyPin(_enteredPin, pinHash)) {
          Navigator.of(context).pop(true);
        } else {
          _showError();
        }
        break;

      case PinMode.setup:
        if (!_isConfirming) {
          setState(() {
            _setupFirstPin = _enteredPin;
            _enteredPin = '';
            _isConfirming = true;
          });
        } else {
          if (_enteredPin == _setupFirstPin) {
            // Hỏi câu hỏi bảo mật
            final securityResult = await _showSecurityQuestionDialog();
            if (securityResult == null) {
              // Hủy setup
              _showError(resetConfirm: true);
              return;
            }

            // Hỏi sinh trắc học
            final canCheckBiometrics = await auth.canCheckBiometrics;
            final isDeviceSupported = await auth.isDeviceSupported();
            bool enableBiometrics = false;

            if (canCheckBiometrics && isDeviceSupported) {
              enableBiometrics = await _showBiometricPromptDialog() ?? false;
            }

            // Lưu cài đặt
            await cubit.setPin(_enteredPin);
            await cubit.setSecurityQuestion(securityResult['index'] as int, securityResult['answer'] as String);
            await cubit.setBiometricEnabled(enableBiometrics);

            if (mounted) Navigator.of(context).pop(true);
          } else {
            _showError(resetConfirm: true);
          }
        }
        break;

      case PinMode.remove:
        if (SecurityUtils.verifyPin(_enteredPin, pinHash)) {
          await cubit.removePin();
          if (mounted) Navigator.of(context).pop(true);
        } else {
          _showError();
        }
        break;
    }
  }

  void _showError({bool resetConfirm = false}) {
    setState(() {
      _hasError = true;
      _enteredPin = '';
      if (resetConfirm) {
        _isConfirming = false;
        _setupFirstPin = '';
      }
    });
  }

  Future<Map<String, dynamic>?> _showSecurityQuestionDialog() async {
    int selectedIndex = 0;
    final controller = TextEditingController();
    bool showError = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Câu hỏi bảo mật'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chọn một câu hỏi bảo mật. Nó sẽ dùng để khôi phục mã PIN khi bạn quên.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedIndex,
                    isExpanded: true,
                    items: List.generate(_securityQuestions.length, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text(_securityQuestions[index], overflow: TextOverflow.ellipsis),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedIndex = val);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Đáp án của bạn',
                      errorText: showError ? 'Vui lòng nhập đáp án' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setStateDialog(() => showError = true);
                    } else {
                      Navigator.of(context).pop({
                        'index': selectedIndex,
                        'answer': controller.text.trim(),
                      });
                    }
                  },
                  child: const Text('Xong'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showBiometricPromptDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sinh trắc học'),
          content: const Text('Bạn có muốn sử dụng Vân tay để mở khóa ứng dụng nhanh hơn thay vì nhập mã PIN không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleForgotPin() async {
    final cubit = context.read<SettingsCubit>();
    final qIndex = cubit.state.securityQuestionIndex;
    final correctAnswerHash = cubit.state.securityAnswerHash;

    if (qIndex == null || correctAnswerHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa thiết lập câu hỏi bảo mật')),
      );
      return;
    }

    final controller = TextEditingController();
    bool showError = false;

    final success = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Quên mã PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Câu hỏi: ${_securityQuestions[qIndex]}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Đáp án của bạn',
                      errorText: showError ? 'Đáp án không đúng' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (SecurityUtils.verifySecurityAnswer(controller.text, correctAnswerHash)) {
                      Navigator.of(context).pop(true);
                    } else {
                      setStateDialog(() => showError = true);
                    }
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );

    if (success == true) {
      // Chuyển màn hình sang mode Setup lại PIN
      if (!mounted) return;
      await cubit.removePin(); // Xóa PIN cũ để setup PIN mới
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PinScreen(mode: PinMode.setup)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = widget.mode != PinMode.verify;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(false),
                )
              : const SizedBox.shrink(),
        ),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              PinHeader(mode: widget.mode, isConfirming: _isConfirming),
              const SizedBox(height: 40),
              PinIndicators(enteredPin: _enteredPin),
              const SizedBox(height: 16),
              if (_hasError)
                Text(
                  widget.mode == PinMode.setup
                      ? 'Mã PIN không khớp. Thử lại.'
                      : 'Mã PIN sai. Vui lòng thử lại.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.dangerRed,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const SizedBox(height: 20),
              const Spacer(),
              PinNumpad(
                onKeyPress: _onKeyPress,
                onBackspace: _onBackspace,
                biometricButton: _buildBiometricButton(theme),
              ),
              if (widget.mode == PinMode.verify)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: TextButton(
                    onPressed: _handleForgotPin,
                    child: const Text('Quên mã PIN?'),
                  ),
                )
              else
                const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton(ThemeData theme) {
    final cubit = context.read<SettingsCubit>();
    if (widget.mode == PinMode.verify && cubit.state.isBiometricEnabled) {
      return InkWell(
        onTap: _authenticateWithBiometrics,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Icon(
            Icons.fingerprint,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }
    return const SizedBox(width: 80, height: 80);
  }
}
