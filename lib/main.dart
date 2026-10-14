import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusmaxxingApp());
}

class FocusmaxxingApp extends StatelessWidget {
  const FocusmaxxingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final colorScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF00E676),
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Focusmaxxing',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: const Color(0xFF090A0D),
          ),
          home: const Scaffold(
            body: Center(
              child: Text(
                'Focusmaxxing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF4F6FB),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
