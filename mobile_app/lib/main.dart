import 'package:flutter/material.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/splash_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';

void main() {
  runApp(const PConnectApp());
}

class PConnectApp extends StatelessWidget {
  const PConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'P-Connect',
      theme: AppTheme.light(),
      routes: {LoginScreen.routeName: (_) => const LoginScreen()},
      home: const SplashScreen(),
    );
  }
}
