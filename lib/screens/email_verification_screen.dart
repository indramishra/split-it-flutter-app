import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isPhoneMode = false;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCooldown = 30;
  Timer? _timer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    _startPollingForVerification();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<SplitwiseProvider>().currentUser;
      // If email is already verified and phone is not, auto switch to phone mode
      if (user.isEmailVerified &&
          user.phoneNumber != null &&
          user.phoneNumber!.isNotEmpty &&
          !user.isPhoneVerified) {
        setState(() => _isPhoneMode = true);
      }
    });
  }

  void _startPollingForVerification() {
    // Poll every 5 seconds to check if email was verified via link click
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final provider = context.read<SplitwiseProvider>();
      final isVerified = await provider.checkEmailVerified();
      if (isVerified && mounted && !_isPhoneMode) {
        timer.cancel();
        _timer?.cancel();
        // Auto-advance to phone verification if needed
        final user = provider.currentUser;
        if (user.phoneNumber != null &&
            user.phoneNumber!.isNotEmpty &&
            !user.isPhoneVerified) {
          _clearDigits();
          setState(() => _isPhoneMode = true);
        } else {
          // Fully verified, navigate back
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  void _startCooldownTimer() {
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
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _clearDigits() {
    setState(() => _errorMessage = null);
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = context.read<SplitwiseProvider>();
    final error = await provider.verifyEmail(''); // Code not needed for link-based

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });

      if (error == null) {
        final user = provider.currentUser;
        if (user.phoneNumber != null &&
            user.phoneNumber!.isNotEmpty &&
            !user.isPhoneVerified) {
          setState(() => _isPhoneMode = true);
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final provider = context.read<SplitwiseProvider>();
    String? error;

    if (_isPhoneMode) {
      error = await provider.sendPhoneVerificationCode();
    } else {
      error = await provider.sendEmailVerificationCode();
    }

    if (mounted) {
      setState(() => _isResending = false);
      if (error != null) {
        setState(() => _errorMessage = error);
      } else {
        _startCooldownTimer();
        final methodLabel = _isPhoneMode ? 'SMS' : 'email';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.teal,
            content: Text(
              'A new verification ${methodLabel == 'SMS' ? 'code' : 'link'} was sent via $methodLabel!',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final user = provider.currentUser;

    final hasPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    final currentTarget = _isPhoneMode ? (user.phoneNumber ?? '') : user.email;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isPhoneMode ? 'Verify Phone' : 'Verify Email'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
            onPressed: () => provider.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tab Switcher if phone number is present
                  if (hasPhone) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_isPhoneMode) {
                                  _clearDigits();
                                  setState(() => _isPhoneMode = false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isPhoneMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isPhoneMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.isEmailVerified
                                            ? Icons.check_circle
                                            : Icons.email_outlined,
                                        size: 16,
                                        color: user.isEmailVerified
                                            ? Colors.green
                                            : AppTheme.tealDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Email ${user.isEmailVerified ? "✓" : ""}',
                                        style: TextStyle(
                                          fontWeight: !_isPhoneMode
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: !_isPhoneMode
                                              ? AppTheme.tealDark
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!_isPhoneMode) {
                                  _clearDigits();
                                  setState(() => _isPhoneMode = true);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isPhoneMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isPhoneMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.isPhoneVerified
                                            ? Icons.check_circle
                                            : Icons.sms_outlined,
                                        size: 16,
                                        color: user.isPhoneVerified
                                            ? Colors.green
                                            : AppTheme.tealDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Phone SMS ${user.isPhoneVerified ? "✓" : ""}',
                                        style: TextStyle(
                                          fontWeight: _isPhoneMode
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _isPhoneMode
                                              ? AppTheme.tealDark
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Icon Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPhoneMode
                          ? Icons.sms_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 54,
                      color: AppTheme.tealDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    _isPhoneMode
                        ? 'Verify your phone number'
                        : 'Verify your email',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (!_isPhoneMode) ...[
                    // Email verification - link based
                    Text(
                      'We\'ve sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTarget,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notification Banner Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.tealLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.teal.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.tealLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.mark_chat_unread_outlined,
                              color: AppTheme.tealDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Verification Email Sent',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Check your email inbox (and spam folder) for a verification link from SplitIt. Click the link to verify your email address.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Check Verification Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _checkVerification,
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
                                'I\'ve Clicked the Link',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Polling indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Auto-checking for verification...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.tealDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Phone verification - SMS code based
                    Text(
                      'We sent a 6-digit SMS code to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTarget,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notification Banner Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.tealLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.teal.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.tealLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.phone_android,
                              color: AppTheme.tealDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SMS Notification Dispatched',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Check your phone notifications tray or SMS messages for the 6-digit code.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.3,
                                  ),
                                ),
                                if (user.phoneVerificationCode != null &&
                                    user.phoneVerificationCode!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      // Quick fill from notification
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.tealLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.touch_app,
                                            size: 14,
                                            color: AppTheme.tealDark,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Quick fill: ${user.phoneVerificationCode}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.tealDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6 Digit Input Boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextField(
                            controller: TextEditingController(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.charcoal,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.teal,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                // Phone verification handled elsewhere
                              },
                        child: const Text(
                          'Verify Phone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Resend Code/Link Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the ${_isPhoneMode ? 'code' : 'email'}? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: (_resendCooldown > 0 || _isResending)
                            ? null
                            : _resendCode,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Resend ${_isPhoneMode ? 'Code' : 'Link'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (_resendCooldown > 0 || _isResending)
                                ? Colors.grey
                                : AppTheme.teal,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Notification Permission Assistance
                  TextButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 16),
                    label: const Text(
                      'Re-request notification permissions',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final granted =
                          await provider.requestNotificationPermission();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              granted
                                  ? 'Notification permission granted!'
                                  : 'Notification permission denied or restricted in device settings.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}