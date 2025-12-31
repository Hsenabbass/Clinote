import 'package:flutter/material.dart';
import 'package:mama/services/app_init.dart';
import 'package:mama/state/app_settings.dart';
import 'package:mama/ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInit.ensureReady();
  final settings = await AppSettings.load();
  runApp(MamaApp(settings: settings));
}

class MamaApp extends StatelessWidget {
  const MamaApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settings.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Dr Nesrine',
          themeMode: mode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: HomeScreen(settings: settings),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
      visualDensity: VisualDensity.standard,
    );

    final radius = BorderRadius.circular(16);

    return base.copyWith(
      scaffoldBackgroundColor: base.colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: base.colorScheme.surface.withOpacity(isDark ? 0.90 : 0.96),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.35 : 0.55),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(borderRadius: radius),
        focusedBorder: OutlineInputBorder(borderRadius: radius),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: base.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 46,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 52,
        headingTextStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        decoration: BoxDecoration(
          color: base.colorScheme.surface.withOpacity(isDark ? 0.25 : 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
