import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'seneca_api.dart';
import 'storage_service.dart';

// ── WorkManager callback (fallback) ──────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'tessera_entrada') {
        await FichajeService.ejecutarFichaje('E');
      } else if (taskName == 'tessera_salida') {
        await FichajeService.ejecutarFichaje('S');
      } else if (taskName == 'tessera_fallback') {
        final h = DateTime.now().hour;
        await FichajeService.ejecutarFichaje(h < 12 ? 'E' : 'S');
      }
    } catch (_) {
      return Future.value(false);
    }
    return Future.value(true);
  });
}

/// Ejecuta fichajes. La programación de alarmas vive en ScheduleService.
class FichajeService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // ── Inicialización ────────────────────────────────────────────────────────

  static Future<void> init() async {
    await AndroidAlarmManager.initialize();
    await Workmanager().initialize(callbackDispatcher);
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  // ── Ejecución de un fichaje ───────────────────────────────────────────────

  static Future<void> ejecutarFichaje(String type) async {
    debugPrint('Tessera/fichaje: ejecutarFichaje($type) a las ${DateTime.now()}');
    final config = await StorageService.loadConfig();
    if (!config.autoFichajeEnabled) return;
    if (type == 'E' && !config.fichaEntrada) return;
    if (type == 'S' && !config.fichaSalida) return;

    try {
      final creds = await StorageService.loadCredentials();
      final token = await SenecaApi.silentLogin(
        username:        creds['username']!,
        password:        creds['password']!,
        persistentToken: creds['persistentToken']!,
        centerId:        config.centerId,
        codeProfile:     config.codeProfile,
      );

      final key = await SenecaApi.getAccessPointKey(token);
      await SenecaApi.registrarPresencia(token, key, type);
      debugPrint('Tessera/fichaje: $type registrado OK');

      final label = type == 'E' ? 'Entrada' : 'Salida';
      final now   = DateTime.now();
      await _notifications.show(
        type == 'E' ? 1 : 2,
        'Tessera — $label registrada ✓',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tessera_channel', 'Fichajes',
            channelDescription: 'Notificaciones de fichaje automático',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      // Si falla (red, login...), reintentar en cuanto haya conexión.
      debugPrint('Tessera/fichaje: ERROR fichando $type: $e → reintento WorkManager');
      await Workmanager().registerOneOffTask(
        'tessera_retry_$type',
        type == 'E' ? 'tessera_entrada' : 'tessera_salida',
        initialDelay: const Duration(minutes: 2),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      rethrow;
    }
  }
}
