import 'package:flutter/material.dart';

/// Modo de tema activo (claro/oscuro/automático). Lo escuchan el MaterialApp
/// y el selector de Ajustes; se persiste en [StorageService].
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Tema de Tessera con soporte claro/oscuro.
///
/// Los colores semánticos (success/warning/error) son constantes; el resto
/// (acento, superficies, textos) se resuelven según [_b], que el `MaterialApp`
/// fija en cada build a la luminosidad activa. Así las pantallas pueden seguir
/// usando `AppTheme.surface` etc. sin pasar el `context`.
class AppTheme {
  AppTheme._();

  /// Luminosidad activa. La fija el builder de MaterialApp en cada frame.
  static Brightness _b = Brightness.light;
  static set brightness(Brightness b) => _b = b;
  static bool get isDark => _b == Brightness.dark;

  // ── Semánticos (iguales en ambos modos) ─────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);

  // ── Acento (cian, armónico con el verde/rojo) ────────────────────────────
  static const _accentDark  = Color(0xFF00B4D8); // cian vivo (como el original)
  static const _accentLight = Color(0xFF0E7C93); // cian más profundo para claro
  static Color get accent => isDark ? _accentDark : _accentLight;

  // ── Superficies y textos por modo ────────────────────────────────────────
  static Color get background => isDark ? const Color(0xFF0E1015) : const Color(0xFFE9EDF3);
  static Color get surface    => isDark ? const Color(0xFF181B22) : Colors.white;
  static Color get card       => isDark ? const Color(0xFF232733) : const Color(0xFFE2E7EF);
  static Color get primary    => isDark ? const Color(0xFF1A1D29) : const Color(0xFFE8EAF0);
  static Color get textPrimary   => isDark ? const Color(0xFFECEDEF) : const Color(0xFF1B1F27);
  static Color get textSecondary => isDark ? const Color(0xFF9AA1AC) : const Color(0xFF6B7280);

  /// Borde sutil de tarjetas (claro = casi imperceptible, oscuro = blanco translúcido).
  static Color get hairline =>
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

  /// Sombra de tarjeta: en claro da profundidad; en oscuro no se usa.
  static List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  // ── ThemeData por modo ───────────────────────────────────────────────────

  static ThemeData get dark  => themeFor(Brightness.dark);
  static ThemeData get light => themeFor(Brightness.light);

  static ThemeData themeFor(Brightness b) {
    final isDark = b == Brightness.dark;
    final accent = isDark ? _accentDark : _accentLight;
    final bg      = isDark ? const Color(0xFF0E1015) : const Color(0xFFE9EDF3);
    final surf    = isDark ? const Color(0xFF181B22) : Colors.white;
    final card    = isDark ? const Color(0xFF232733) : const Color(0xFFE2E7EF);
    final txt     = isDark ? const Color(0xFFECEDEF) : const Color(0xFF1B1F27);
    final txt2    = isDark ? const Color(0xFF9AA1AC) : const Color(0xFF6B7280);
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: b,
        primary: accent,
        secondary: accent,
        surface: surf,
        onPrimary: Colors.black,
        onSurface: txt,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: txt,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: txt,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: txt, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: TextStyle(color: txt, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: TextStyle(color: txt, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: txt, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: txt),
        bodyMedium: TextStyle(color: txt2),
        labelLarge: TextStyle(color: txt, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: txt2),
        hintStyle: TextStyle(color: txt2.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2)),
      ),
      // La barra de navegación toma sus colores del tema (no de los getters
      // estáticos), para que cambie de color al instante y animado al alternar
      // claro/oscuro, en vez de quedarse con el color anterior.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surf,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: s.contains(WidgetState.selected) ? accent : txt2,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? accent : txt2,
            )),
      ),
      dividerColor: hairline,
    );
  }
}
