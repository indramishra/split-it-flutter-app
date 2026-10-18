import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/splitwise_provider.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplitwiseApp());
}

class SplitwiseApp extends StatelessWidget {
  const SplitwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SplitwiseProvider(),
      child: MaterialApp(
        title: 'Splitwise Clone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ),
    );
  }
}
