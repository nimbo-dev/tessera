import 'package:flutter/material.dart';
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
      // Los colores salen del navigationBarTheme del tema activo, así la barra
      // se repinta sola (y animada) al cambiar claro/oscuro.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
