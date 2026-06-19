import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const DelegadsApp());
}

/// Root widget.
///
/// Wraps the app in a [MultiProvider] so any screen can `context.read<ApiService>()`
/// to call the backend.
///
/// The home widget reacts to [ApiService.isAuthenticated] and switches
/// between [LoginScreen] and [DashboardScreen] automatically.
class DelegadsApp extends StatelessWidget {
  const DelegadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiService>(
          create: (_) => ApiService()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Delegads CRM',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        darkTheme: _buildTheme(brightness: Brightness.dark),
        home: const _AuthGate(),
      ),
    );
  }

  ThemeData _buildTheme({Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final seed = const Color(0xFF6D28D9); // deep purple
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F0E14) : const Color(0xFFF8F7FB),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF0F0E14) : const Color(0xFFF8F7FB),
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? const Color(0xFF1A1822) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1822) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Decides whether to show the login or dashboard based on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiService>(
      builder: (context, api, _) {
        if (!api.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return api.isAuthenticated
            ? const DashboardScreen()
            : const LoginScreen();
      },
    );
  }
}
