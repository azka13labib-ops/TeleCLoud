import 'package:flutter/material.dart';
import '../../../core/services/telegram_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';

/// Modal dialog guiding the user through Telegram MTProto setup:
/// 1. Enter Telegram API Credentials (api_id & api_hash from my.telegram.org)
/// 2. Submit Phone Number
/// 3. Enter Official Telegram Verification OTP
/// 4. Submit 2FA Password (if enabled)
/// 5. Automatically create/bind "Personal Cloud Vault" channel
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
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => TelegramAuthModal(onAuthenticated: onAuthenticated),
    );
  }

  @override
  State<TelegramAuthModal> createState() => _TelegramAuthModalState();
}

class _TelegramAuthModalState extends State<TelegramAuthModal> {
  final TelegramService _telegram = TelegramService.instance;

  final TextEditingController _apiIdController = TextEditingController();
  final TextEditingController _apiHashController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (TelegramService.apiId != 0) {
      _apiIdController.text = TelegramService.apiId.toString();
    }
    if (TelegramService.apiHash.isNotEmpty && TelegramService.apiHash != 'YOUR_API_HASH_HERE') {
      _apiHashController.text = TelegramService.apiHash;
    }
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    final idText = _apiIdController.text.trim();
    final hash = _apiHashController.text.trim();

    final id = int.tryParse(idText);
    if (id == null || id == 0) {
      setState(() => _errorMessage = 'Masukkan App api_id berupa angka valid dari my.telegram.org');
      return;
    }
    if (hash.isEmpty) {
      setState(() => _errorMessage = 'Masukkan App api_hash dari my.telegram.org');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.updateCredentials(id: id, hash: hash);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal menyimpan kredensial: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      setState(() => _errorMessage = 'Gunakan format internasional (contoh: +628123456789)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.sendPhoneNumber(phone);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal mengirim OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Masukkan 5 digit kode verifikasi Telegram');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.checkAuthenticationCode(code);
    } catch (e) {
      setState(() => _errorMessage = 'Kode verifikasi salah: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Masukkan sandi Two-Step Verification Anda');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _telegram.checkAuthenticationPassword(password);
    } catch (e) {
      setState(() => _errorMessage = 'Sandi 2FA tidak cocok: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

          return SingleChildScrollView(
            child: GlassCard(
              blur: 24.0,
              opacity: 0.14,
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                          Icons.cloud_upload_outlined,
                          color: AppTheme.accentCyan,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Telegram MTProto 2GB Vault',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStepSubtitle(state),
                              style: const TextStyle(
                                color: AppTheme.subtleText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.subtleText, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Error notification banner if any
                  if (_errorMessage != null || _telegram.lastErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
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
                              _errorMessage ?? _telegram.lastErrorMessage ?? '',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Form Content Based on Auth State
                  _buildContentForState(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStepSubtitle(TelegramAuthState state) {
    switch (state) {
      case TelegramAuthState.waitingCredentials:
        return 'Step 1/3: API Credentials';
      case TelegramAuthState.waitingPhoneNumber:
        return 'Step 2/3: Masukkan Nomor HP';
      case TelegramAuthState.waitingCode:
        return 'Step 3/3: Verifikasi Kode OTP';
      case TelegramAuthState.waitingPassword:
        return 'Verifikasi 2-Step Password';
      case TelegramAuthState.ready:
        return 'Koneksi Berhasil Aktif';
      case TelegramAuthState.waitingParameters:
        return 'Menghubungkan MTProto...';
      case TelegramAuthState.error:
        return 'Status Sambungan';
      default:
        return 'Aktivasi Cloud Storage';
    }
  }

  Widget _buildContentForState(TelegramAuthState state) {
    // If credentials are not set, show credential input form
    if (state == TelegramAuthState.waitingCredentials ||
        (!TelegramService.hasValidCredentials && state != TelegramAuthState.ready)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.accentCyan, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ambil api_id & api_hash gratis di my.telegram.org -> API development tools.',
                    style: TextStyle(color: AppTheme.doodleLine, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'App api_id:',
            style: TextStyle(color: AppTheme.doodleLine, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _apiIdController,
            hintText: 'Contoh: 28391829',
            prefixIcon: Icons.tag,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          const Text(
            'App api_hash:',
            style: TextStyle(color: AppTheme.doodleLine, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _apiHashController,
            hintText: 'Contoh: 7f83a09...',
            prefixIcon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: _submitCredentials,
            isLoading: _isLoading,
            child: const Text(
              'Simpan & Lanjutkan',
              style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    // Step 2: Phone number
    if (state == TelegramAuthState.waitingPhoneNumber) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nomor HP Terdaftar di Telegram:',
            style: TextStyle(color: AppTheme.doodleLine, fontSize: 13),
          ),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _phoneController,
            hintText: '+6281234567890',
            prefixIcon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan kode negara lengkap dengan tanda tambah (+)',
            style: TextStyle(color: AppTheme.subtleText, fontSize: 11),
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: _submitPhone,
            isLoading: _isLoading,
            child: const Text(
              'Kirim Kode OTP',
              style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    // Step 3: OTP Code
    if (state == TelegramAuthState.waitingCode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buka aplikasi Telegram resmi Anda dan masukkan 5 digit kode masuk yang dikirim:',
            style: TextStyle(color: AppTheme.doodleLine, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _codeController,
            hintText: '5-digit OTP Code',
            prefixIcon: Icons.lock_outline,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: _submitCode,
            isLoading: _isLoading,
            child: const Text(
              'Verifikasi & Buka Saluran Vault',
              style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    // Step 4: 2FA Password
    if (state == TelegramAuthState.waitingPassword) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akun Telegram Anda menggunakan Two-Step Verification. Masukkan kata sandi cloud:',
            style: TextStyle(color: AppTheme.doodleLine, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _passwordController,
            hintText: 'Password 2FA',
            prefixIcon: Icons.password,
            obscureText: true,
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: _submitPassword,
            isLoading: _isLoading,
            child: const Text(
              'Buka Akses 2FA',
              style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    // Ready
    if (state == TelegramAuthState.ready) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.accentCyan, size: 52),
              SizedBox(height: 14),
              Text(
                'Telegram MTProto Aktif!',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Saluran penyimpanan 2GB siap digunakan untuk upload dan download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.subtleText, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Connecting progress / Handshake
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Menghubungkan ke server Telegram MTProto...',
              style: TextStyle(color: AppTheme.doodleLine, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Menginisialisasi sesi enkripsi database TDLib',
              style: TextStyle(color: AppTheme.subtleText, fontSize: 11),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onAuthenticated();
              },
              child: const Text(
                'Gunakan Mode Offline / Nanti Saja',
                style: TextStyle(color: AppTheme.subtleText, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
