import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/country_code_picker.dart';
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

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Country code state - defaults to India (+91)
  String _selectedCountryDialCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  @override
  void dispose() {
    _nameController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    // If it contains mostly digits or starts with +, treat as phone
    final digitCount = RegExp(r'[0-9]').allMatches(trimmed).length;
    return digitCount >= 4; // At least 4 digits suggests phone number
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_split,
                      size: 44,
                      color: AppTheme.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SplitIt',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                      letterSpacing: -0.5,
                    ),
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
                        if (_isSignUp) ...[
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
                                        : (inputText.contains('@') ? TextInputType.emailAddress : TextInputType.emailAddress),
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
                                'SMS verification code will be sent to $_selectedCountryFlag $_selectedCountryDialCode',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Password
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

                        // Confirm Password (if sign up)
                        if (_isSignUp) ...[
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
                        ] else ...[
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

                        // Submit Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _submit,
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
                                  _isSignUp ? 'Create Account' : 'Log In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
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
