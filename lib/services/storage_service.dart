import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/weekly_schedule.dart';

/// Persistencia de credenciales (segura) y configuración (prefs).
class StorageService {
  static const _storage = FlutterSecureStorage();

  // ── Claves ────────────────────────────────────────────────────────────────
  static const _k2FA       = 'persistent_2fa_token';
  static const _kUsername  = 'seneca_username';
  static const _kPassword  = 'seneca_password';   // cifrado con flutter_secure_storage

  // ── Credenciales seguras ──────────────────────────────────────────────────

  static Future<void> saveCredentials({
    required String username,
    required String password,
    required String persistentToken,
    required int centerId,
    required String codeProfile,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _k2FA,      value: persistentToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('center_id', centerId);
    await prefs.setString('code_profile', codeProfile);
  }

  static Future<Map<String, String?>> loadCredentials() async {
    return {
      'username':        await _storage.read(key: _kUsername),
      'password':        await _storage.read(key: _kPassword),
      'persistentToken': await _storage.read(key: _k2FA),
    };
  }

  static Future<bool> hasCredentials() async {
    final token = await _storage.read(key: _k2FA);
    final user  = await _storage.read(key: _kUsername);
    return token != null && user != null;
  }

  static Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }

  // ── Configuración ─────────────────────────────────────────────────────────

  static Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_enabled',       config.autoFichajeEnabled);
    await prefs.setBool('ficha_entrada',       config.fichaEntrada);
    await prefs.setBool('ficha_salida',        config.fichaSalida);
    await prefs.setInt('margin_entrada',       config.marginEntradaMinutes);
    await prefs.setInt('margin_salida',        config.marginSalidaMinutes);
    await prefs.setBool('no_lectivo_enabled',  config.nonLectivoEnabled);
    await prefs.setString('no_lectivo_start',  config.nonLectivoStart);
    await prefs.setString('no_lectivo_end',    config.nonLectivoEnd);
  }

  static Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final creds = await loadCredentials();
    return AppConfig(
      twoFactorAuthToken: creds['persistentToken'] ?? '',
      username:           creds['username'] ?? '',
      centerId:           prefs.getInt('center_id') ?? 344,
      codeProfile:        prefs.getString('code_profile') ?? 'P',
      autoFichajeEnabled: prefs.getBool('auto_enabled') ?? true,
      fichaEntrada:       prefs.getBool('ficha_entrada') ?? true,
      fichaSalida:        prefs.getBool('ficha_salida') ?? true,
      marginEntradaMinutes: prefs.getInt('margin_entrada') ?? 10,
      marginSalidaMinutes:  prefs.getInt('margin_salida') ?? 10,
      nonLectivoEnabled: prefs.getBool('no_lectivo_enabled') ?? false,
      nonLectivoStart:   prefs.getString('no_lectivo_start') ?? '09:00',
      nonLectivoEnd:     prefs.getString('no_lectivo_end') ?? '14:00',
    );
  }

  // ── Tema (claro/oscuro/automático) ────────────────────────────────────────

  static const _kThemeMode = 'theme_mode';

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kThemeMode);
    return ThemeMode.values.firstWhere((m) => m.name == s,
        orElse: () => ThemeMode.light);
  }

  // ── Horario semanal ───────────────────────────────────────────────────────

  static const _kWeeklySchedule = 'weekly_schedule';

  static Future<void> saveWeeklySchedule(WeeklySchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWeeklySchedule, schedule.toJsonString());
  }

  static Future<WeeklySchedule?> loadWeeklySchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kWeeklySchedule);
    if (raw == null) return null;
    try {
      return WeeklySchedule.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

}
