import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/fichaje_service.dart';
import 'services/seneca_api.dart';
import 'services/storage_service.dart';
import 'screens/setup_screen.dart';
import 'screens/main_shell.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('es', null);
  await FichajeService.init();

  themeNotifier.value = await StorageService.loadThemeMode();

  final initialScreen = await _resolveInitialScreen();
  runApp(TesseraApp(initialScreen: initialScreen));
}

Future<Widget> _resolveInitialScreen() async {
  try {
    if (!await StorageService.hasCredentials()) return const SetupScreen();
    final creds  = await StorageService.loadCredentials();
    final config = await StorageService.loadConfig();
    final token  = await SenecaApi.silentLogin(
      username:        creds['username']!,
      password:        creds['password']!,
      persistentToken: creds['persistentToken']!,
      centerId:        config.centerId,
      codeProfile:     config.codeProfile,
    );
    return MainShell(accessToken: token);
  } catch (_) {
    return const SetupScreen();
  }
}

class TesseraApp extends StatelessWidget {
  final Widget initialScreen;
  const TesseraApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Tessera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        // Fija la luminosidad activa para los getters de AppTheme.
        builder: (context, child) {
          AppTheme.brightness = Theme.of(context).brightness;
          return child!;
        },
        home: initialScreen,
      ),
    );
  }
}
