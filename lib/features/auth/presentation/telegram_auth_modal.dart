import 'package:flutter/material.dart';
import '../../../core/services/telegram_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';

/// Modal dialog guiding the user through Telegram MTProto setup (Phone -> OTP -> 2FA)
class TelegramAuthModal extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const TelegramAuthModal({
    super.key,
    required this.onAuthenticated,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAuthenticated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => TelegramAuthModal(onAuthenticated: onAuthenticated),
    );
  }

  @override
  State<TelegramAuthModal> createState() => _TelegramAuthModalState();
}

class _TelegramAuthModalState extends State<TelegramAuthModal> {
  final TelegramService _telegram = TelegramService.instance;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number (+62...)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.sendPhoneNumber(phone);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send phone: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.checkAuthenticationCode(code);
    } catch (e) {
      setState(() => _errorMessage = 'Invalid code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your 2FA password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.checkAuthenticationPassword(password);
    } catch (e) {
      setState(() => _errorMessage = 'Invalid password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StreamBuilder<TelegramAuthState>(
        stream: _telegram.onAuthStateChanged,
        initialData: _telegram.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? TelegramAuthState.uninitialized;

          if (state == TelegramAuthState.ready) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
                widget.onAuthenticated();
              }
            });
          }

          return GlassCard(
            blur: 24.0,
            opacity: 0.12,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppTheme.accentCyan.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppTheme.accentCyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram MTProto Vault',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 18,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'One-time 2GB storage activation',
                            style: TextStyle(
                              color: AppTheme.subtleText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Body based on MTProto Auth State
                if (state == TelegramAuthState.waitingPhoneNumber ||
                    state == TelegramAuthState.waitingParameters ||
                    state == TelegramAuthState.uninitialized) ...[
                  const Text(
                    'Enter your phone number registered with Telegram:',
                    style: TextStyle(color: AppTheme.doodleLine, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: _phoneController,
                    hintText: '+62 812 3456 7890',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  GlassButton(
                    onPressed: _submitPhone,
                    isLoading: _isLoading,
                    child: const Text(
                      'Request OTP Code',
                      style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (state == TelegramAuthState.waitingCode) ...[
                  const Text(
                    'Enter the code received inside your Telegram app:',
                    style: TextStyle(color: AppTheme.doodleLine, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: _codeController,
                    hintText: '5-digit code',
                    prefixIcon: Icons.lock_clock_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  GlassButton(
                    onPressed: _submitCode,
                    isLoading: _isLoading,
                    child: const Text(
                      'Verify & Activate Vault',
                      style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (state == TelegramAuthState.waitingPassword) ...[
                  const Text(
                    'Your Telegram account has 2-Step Verification enabled. Enter password:',
                    style: TextStyle(color: AppTheme.doodleLine, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: _passwordController,
                    hintText: '2FA Cloud Password',
                    prefixIcon: Icons.key_outlined,
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  GlassButton(
                    onPressed: _submitPassword,
                    isLoading: _isLoading,
                    child: const Text(
                      'Unlock 2FA Session',
                      style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else if (state == TelegramAuthState.ready) ...[
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppTheme.accentCyan, size: 48),
                        SizedBox(height: 12),
                        Text(
                          '2GB MTProto Vault Connected!',
                          style: TextStyle(color: AppTheme.doodleLine, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ] else if (state == TelegramAuthState.error) ...[
                  // Handled state: TDLib native binary not present or initialization error
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.offline_pin_rounded, color: AppTheme.accentPurple, size: 36),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Local Vault Mode Active',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Telegram MTProto native engine is offline. Your files will be securely stored in high-speed Local Vault.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.subtleText, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        GlassButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onAuthenticated();
                          },
                          child: const Text(
                            'Continue to Vault',
                            style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Fallback: If TDLib is connecting or stuck, give option to input or skip to demo
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.0),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to Telegram MTProto...',
                            style: TextStyle(color: AppTheme.subtleText, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Allow user to continue to home or close dialog
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onAuthenticated();
                          },
                          child: const Text(
                            'Skip to Vault (Test UI)',
                            style: TextStyle(color: AppTheme.subtleText, fontSize: 12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

