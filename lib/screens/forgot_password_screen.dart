import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  int _resendCooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendCooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final provider = context.read<SplitwiseProvider>();
    final error = await provider.sendPasswordResetCode(email);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _isLoading = false;
        _codeSent = true;
        _infoMessage = 'A 6-digit reset code has been sent to your device & email.';
      });
      _startCooldown();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit reset code.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final provider = context.read<SplitwiseProvider>();
    final error = await provider.resetPasswordWithCode(
      email: email,
      code: code,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.charcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: AppTheme.charcoal,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _isSuccess ? _buildSuccessView() : _buildFormCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 56,
              color: AppTheme.teal,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Password Reset Complete!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your password for ${_emailController.text.trim()} has been successfully updated. You can now log in.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop(_emailController.text.trim());
              },
              child: const Text(
                'Back to Log In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset, color: AppTheme.teal, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_codeSent
                          ? 'Enter your registered email'
                          : 'Verify code and set new password',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECE5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.negativeOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.negativeOrange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.negativeOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Info banner
          if (_infoMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: AppTheme.teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _infoMessage!,
                      style: const TextStyle(
                        color: AppTheme.tealDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Email input
          TextField(
            controller: _emailController,
            enabled: !_codeSent,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              suffixIcon: _codeSent
                  ? IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppTheme.teal),
                      tooltip: 'Change Email',
                      onPressed: () {
                        setState(() {
                          _codeSent = false;
                          _errorMessage = null;
                          _infoMessage = null;
                          _codeController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          if (!_codeSent) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _sendCode,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Reset Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ] else ...[
            // 6-digit reset code field
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: '6-Digit Verification Code',
                hintText: '123456',
                prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),

            // New password
            TextField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),

            // Confirm new password
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_reset, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 18),

            // Resend code countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _resendCooldown > 0
                      ? 'Resend code in ${_resendCooldown}s'
                      : 'Didn\'t get the code?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextButton(
                  onPressed: (_resendCooldown > 0 || _isLoading) ? null : _sendCode,
                  child: Text(
                    'Resend Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (_resendCooldown > 0 || _isLoading)
                          ? Colors.grey.shade400
                          : AppTheme.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Submit Reset Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _submitReset,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
