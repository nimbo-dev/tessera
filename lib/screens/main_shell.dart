import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'historial_screen.dart';
import 'settings_screen.dart';

/// Contenedor principal con navegación inferior de 3 pestañas:
/// Inicio · Historial · Ajustes.
class MainShell extends StatefulWidget {
  final String accessToken;
  const MainShell({super.key, required this.accessToken});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        accessToken: widget.accessToken,
        onOpenHistorial: () => _goTo(1),
      ),
      HistorialScreen(accessToken: widget.accessToken),
      SettingsScreen(token: widget.accessToken),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      // La barra escucha al themeNotifier para repintarse al instante cuando
      // se cambia claro/oscuro; si no, conserva el color viejo hasta el
      // siguiente setState (al cambiar de pestaña), porque sus colores salen
      // de getters estáticos de AppTheme, no de un InheritedWidget.
      bottomNavigationBar: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, _, __) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.accent.withValues(alpha: 0.18),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppTheme.accent),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded, color: AppTheme.accent),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.accent),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
