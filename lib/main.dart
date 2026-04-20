import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────
//  🔑 REPLACE these with your Supabase project credentials
//  Found at: https://app.supabase.com → Project Settings → API
// ─────────────────────────────────────────────────────────────
const _supabaseUrl = '';
const _supabaseAnonKey = '';
// ─────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.initFactory();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const ShoppingApp());
}

class ShoppingApp extends StatefulWidget {
  const ShoppingApp({super.key});

  @override
  State<ShoppingApp> createState() => _ShoppingAppState();
}

class _ShoppingAppState extends State<ShoppingApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleDark() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping List',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: HomeScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleDark: _toggleDark,
      ),
    );
  }
}
