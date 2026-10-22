import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/country_code_picker.dart';
import '../widgets/google_logo.dart';
import '../widgets/app_logo.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;

  final _nameController = TextEditingController();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _smsCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Country code state - defaults to India (+91)
  String _selectedCountryDialCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  // Phone login flow state
  bool _phoneLoginMode = false; // true when phone entered, waiting for SMS
  String _pendingPhoneNumber = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  // Detects if input is email or phone
  bool _isEmailInput(String input) {
    return input.contains('@');
  }

  // Format phone number with country code
  String _formatPhoneNumber(String phone, String countryCode) {
    final digitsOnly = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    if (digitsOnly.startsWith('+')) {
      return digitsOnly;
    }
    return '$countryCode$digitsOnly';
  }

  // Check if the input looks like a phone number (digits or starts with +)
  bool _isPhoneInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('@')) return false;
    final digitCount = RegExp(r'[0-9]').allMatches(trimmed).length;
    return digitCount >= 4;
  }

  Future<void> _sendSmsCode() async {
    final input = _emailOrPhoneController.text.trim();
    if (!_isPhoneInput(input)) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final phoneNumber = _formatPhoneNumber(input, _selectedCountryDialCode);
    final provider = context.read<SplitwiseProvider>();

    if (_isSignUp) {
      // For signup, register first then send SMS
      final name = _nameController.text.trim();
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;

      if (name.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter your full name.';
        });
        return;
      }
      if (password != confirmPassword) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Passwords do not match.';
        });
        return;
      }

      // Register with phone (no email)
      final error = await provider.register(
        name: name,
        email: '',
        password: password,
        phoneNumber: phoneNumber,
      );

      if (error != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = error;
          });
        }
        return;
      }
    }

    // Send SMS code
    final sendError = await provider.sendPhoneVerificationCode(phoneNumber: phoneNumber);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (sendError != null) {
          _errorMessage = sendError;
        } else {
          _phoneLoginMode = true;
          _pendingPhoneNumber = phoneNumber;
          _successMessage = 'SMS code sent to $phoneNumber';
        }
      });
    }
  }

  Future<void> _verifySmsCode() async {
    final smsCode = _smsCodeController.text.trim();
    if (smsCode.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final provider = context.read<SplitwiseProvider>();

    if (_isSignUp) {
      // For signup, verify phone after registration
      final error = await provider.verifyPhone(smsCode);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    } else {
      // For login, use passwordless phone login
      final error = await provider.login(
        phoneNumber: _pendingPhoneNumber,
        smsCode: smsCode,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final provider = context.read<SplitwiseProvider>();
    final emailOrPhone = _emailOrPhoneController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      final name = _nameController.text.trim();
      final confirmPassword = _confirmPasswordController.text;

      if (name.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter your full name.';
        });
        return;
      }
      if (password != confirmPassword) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Passwords do not match.';
        });
        return;
      }

      // Determine if user is signing up with email or phone
      final isEmail = _isEmailInput(emailOrPhone);
      final email = isEmail ? emailOrPhone.toLowerCase() : '';
      final phoneNumber = isEmail ? null : _formatPhoneNumber(emailOrPhone, _selectedCountryDialCode);

      final error = await provider.register(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    } else {
      // Login - detect if email or phone
      final isEmail = _isEmailInput(emailOrPhone);
      final loginEmail = isEmail ? emailOrPhone.toLowerCase() : '';
      final loginPhone = isEmail ? null : _formatPhoneNumber(emailOrPhone, _selectedCountryDialCode);

      final error = await provider.login(
        email: loginEmail,
        password: password,
        phoneNumber: loginPhone,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
  }

  void _resetPhoneLogin() {
    setState(() {
      _phoneLoginMode = false;
      _pendingPhoneNumber = '';
      _smsCodeController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
      _isGoogleLoading = true;
    });

    final provider = context.read<SplitwiseProvider>();
    final error = await provider.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isGoogleLoading = false;
        _errorMessage = error;
      });

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(error, style: const TextStyle(fontSize: 13))),
              ],
            ),
            backgroundColor: AppTheme.negativeOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputText = _emailOrPhoneController.text.trim();
    final isPhone = _isPhoneInput(inputText);
    final isEmailMode = inputText.contains('@');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding Header
                  const SplitItBrandHeader(
                    logoSize: 64,
                    fontSize: 32,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Split bills and share expenses with friends & groups.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Auth Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mode Switcher (Log in / Sign up)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = false;
                                      _phoneLoginMode = false;
                                      _errorMessage = null;
                                      _successMessage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: !_isSignUp
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Log In',
                                        style: TextStyle(
                                          fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                                          color: !_isSignUp ? AppTheme.tealDark : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = true;
                                      _phoneLoginMode = false;
                                      _errorMessage = null;
                                      _successMessage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isSignUp ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _isSignUp
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                                          color: _isSignUp ? AppTheme.tealDark : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Success Banner
                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.tealLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: AppTheme.teal, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
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

                        // Error Banner
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

                        // Full Name (if sign up)
                        if (_isSignUp && !_phoneLoginMode) ...[
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email or Phone Number (single field with country code for phone)
                        if (!_phoneLoginMode) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Country Code Dropdown (shown when phone input is detected)
                                  if (isPhone && !isEmailMode) ...[
                                    SizedBox(
                                      width: 110,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedCountryDialCode,
                                        decoration: InputDecoration(
                                          hintText: 'Code',
                                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          constraints: const BoxConstraints(minWidth: 0),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
                                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                                        items: countries.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c.dialCode,
                                            child: Row(
                                              children: [
                                                Text(
                                                  getFlagFromDialCode(c.dialCode),
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  c.dialCode,
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedCountryDialCode = value;
                                              _selectedCountryFlag = getFlagFromDialCode(value);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // Main input field
                                  Expanded(
                                    child: TextField(
                                      controller: _emailOrPhoneController,
                                      keyboardType: isPhone && !isEmailMode
                                          ? TextInputType.phone
                                          : TextInputType.emailAddress,
                                      autocorrect: false,
                                      onChanged: (value) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: _isSignUp
                                            ? 'Email or Phone Number *'
                                            : 'Email or Phone Number',
                                        hintText: inputText.contains('@') ? 'you@example.com' : 'Enter email or phone',
                                        prefixIcon: isPhone && !isEmailMode
                                            ? const Icon(Icons.phone_outlined, size: 20)
                                            : const Icon(Icons.email_outlined, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Helper text for phone input
                              if (isPhone && !isEmailMode && inputText.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'SMS verification will be sent to $_selectedCountryFlag $_selectedCountryDialCode',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          // Phone login mode - show SMS verification
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show phone number
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone_outlined, color: AppTheme.teal, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$_selectedCountryFlag $_pendingPhoneNumber',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _resetPhoneLogin,
                                      child: const Text('Change'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // SMS Code Input
                              TextField(
                                controller: _smsCodeController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 8,
                                  color: AppTheme.charcoal,
                                ),
                                maxLength: 6,
                                decoration: InputDecoration(
                                  labelText: 'SMS Verification Code',
                                  hintText: '000000',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.sms_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (value) {
                                  if (value.length == 6) {
                                    _verifySmsCode();
                                  }
                                },
                              ),
                              const SizedBox(height: 14),

                              // Resend code
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _sendSmsCode,
                                  child: Text(
                                    'Resend Code',
                                    style: TextStyle(
                                      color: _isLoading ? Colors.grey : AppTheme.teal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Password (only for email login/signup, not phone login mode)
                        if (!_phoneLoginMode && (!isPhone || _isSignUp)) ...[
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
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
                        ],

                        // Confirm Password (if sign up, not phone login mode)
                        if (_isSignUp && !_phoneLoginMode) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_reset, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else if (!_isSignUp && !_phoneLoginMode) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                final updatedEmail = await Navigator.of(context).push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailOrPhoneController.text.trim(),
                                    ),
                                  ),
                                );
                                if (updatedEmail != null && mounted) {
                                  setState(() {
                                    _emailOrPhoneController.text = updatedEmail;
                                    _passwordController.clear();
                                    _isSignUp = false;
                                    _errorMessage = null;
                                    _successMessage = 'Password reset successfully! Please log in with your new password.';
                                  });
                                }
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppTheme.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Submit / Send SMS / Verify Button
                        if (_phoneLoginMode) ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _verifySmsCode,
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
                                    'Verify Code',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ] else ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _isLoading
                                ? null
                                : (isPhone && !isEmailMode ? _sendSmsCode : _submit),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isPhone && !isEmailMode && !_isSignUp
                                        ? 'Send SMS Code'
                                        : (_isSignUp ? 'Create Account' : 'Log In'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Divider with "Or continue with"
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.charcoal,
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        backgroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppTheme.teal,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const GoogleLogo(size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _isSignUp ? 'Sign up with Google' : 'Continue with Google',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Device track info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.devices_outlined, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Synced in real time across all your devices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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