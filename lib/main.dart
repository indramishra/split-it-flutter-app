import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/splitwise_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();
  runApp(const SplitItApp());
}

class SplitItApp extends StatelessWidget {
  const SplitItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SplitwiseProvider(),
      child: MaterialApp(
        title: 'SplitIt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplitItRoot(),
      ),
    );
  }
}

class SplitItRoot extends StatelessWidget {
  const SplitItRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();

    if (provider.isAuthLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_split,
                  size: 48,
                  color: AppTheme.teal,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SplitIt',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppTheme.teal),
            ],
          ),
        ),
      );
    }

    if (!provider.isAuthenticated) {
      return const AuthScreen();
    }

    final user = provider.currentUser;
    final needsEmail = !user.isEmailVerified;
    final needsPhone = user.phoneNumber != null &&
        user.phoneNumber!.isNotEmpty &&
        !user.isPhoneVerified;

    if (needsEmail || needsPhone) {
      return const EmailVerificationScreen();
    }

    return const MainScreen();
  }
}
