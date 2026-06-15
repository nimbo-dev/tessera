import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../models/schedule_entry.dart';
import 'diag_log.dart';
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
      } else if (taskName == 'tessera_safety') {
        await FichajeService.safetyNetCheck();
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
    await DiagLog.log('fichaje: ejecutarFichaje($type) — inicio');
    final config = await StorageService.loadConfig();
    if (!config.autoFichajeEnabled) {
      await DiagLog.log('fichaje: autoFichaje desactivado → nada');
      return;
    }
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
      await DiagLog.log('fichaje: login OK');

      final key = await SenecaApi.getAccessPointKey(token);
      await _registrar(token, key, type);
      await DiagLog.log('fichaje: $type REGISTRADO OK');
    } catch (e) {
      // Si falla (red, login...), reintentar en cuanto haya conexión.
      await DiagLog.log('fichaje: ERROR $type: $e → reintento WorkManager');
      await Workmanager().registerOneOffTask(
        'tessera_retry_$type',
        type == 'E' ? 'tessera_entrada' : 'tessera_salida',
        initialDelay: const Duration(minutes: 2),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      rethrow;
    }
  }

  /// Registra la presencia en Séneca y avisa con una notificación.
  static Future<void> _registrar(String token, String key, String type) async {
    await SenecaApi.registrarPresencia(token, key, type);
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
  }

  // ── Red de seguridad ──────────────────────────────────────────────────────

  /// Comprobación periódica (WorkManager) que recupera un fichaje perdido: si la
  /// alarma exacta no llegó a dispararse (p. ej. MIUI mató el proceso), aquí se
  /// mira en Séneca si falta la entrada o la salida de hoy y se registran.
  ///
  /// Es **idempotente**: consulta el historial antes de fichar, así nunca
  /// duplica un fichaje que la alarma ya hubiera registrado.
  static Future<void> safetyNetCheck() async {
    final config = await StorageService.loadConfig();
    if (!config.autoFichajeEnabled) return;

    final now = DateTime.now();
    if (now.weekday > 5) return; // solo de lunes a viernes

    // Horario de hoy: en no lectivo es fijo; si no, el esqueleto guardado.
    String firstIn, lastOut;
    if (config.nonLectivoEnabled) {
      firstIn = config.nonLectivoStart;
      lastOut = config.nonLectivoEnd;
    } else {
      final day =
          (await StorageService.loadWeeklySchedule())?.getDay(now.weekday);
      if (day == null) return; // hoy no había clase prevista
      firstIn = day.firstIn;
      lastOut = day.lastOut;
    }

    // ¿Toca comprobar algo ahora? Damos un margen de gracia para no pisar la
    // alarma exacta, y una ventana de varias horas tras la salida.
    const grace = Duration(minutes: 10);
    final entradaAt = _todayAt(now, firstIn);
    final salidaAt  = _todayAt(now, lastOut);
    final cutoff    = salidaAt.add(const Duration(hours: 4));
    final needEntrada = config.fichaEntrada &&
        now.isAfter(entradaAt.add(grace)) &&
        now.isBefore(cutoff);
    final needSalida = config.fichaSalida &&
        now.isAfter(
            salidaAt.add(Duration(minutes: config.marginSalidaMinutes) + grace)) &&
        now.isBefore(cutoff);
    if (!needEntrada && !needSalida) return;

    try {
      final creds = await StorageService.loadCredentials();
      final token = await SenecaApi.silentLogin(
        username:        creds['username']!,
        password:        creds['password']!,
        persistentToken: creds['persistentToken']!,
        centerId:        config.centerId,
        codeProfile:     config.codeProfile,
      );

      // En modo lectivo, confirmar que hoy hay clase (no fichar en festivos).
      if (!config.nonLectivoEnabled) {
        final entries = await SenecaApi.getSchedule(token, now);
        if (DayScheduleSummary.fromEntries(now, entries) == null) return;
      }

      final hist = await SenecaApi.getHistorial(token);
      bool yaFichado(String type) => hist.any((r) =>
          r.type == type &&
          r.date != null &&
          r.date!.year == now.year &&
          r.date!.month == now.month &&
          r.date!.day == now.day);

      final needRegister =
          (needEntrada && !yaFichado('E')) || (needSalida && !yaFichado('S'));
      if (!needRegister) return;

      final key = await SenecaApi.getAccessPointKey(token);
      if (needEntrada && !yaFichado('E')) {
        await _registrar(token, key, 'E');
        await DiagLog.log('safety: ENTRADA recuperada');
      }
      if (needSalida && !yaFichado('S')) {
        await _registrar(token, key, 'S');
        await DiagLog.log('safety: SALIDA recuperada');
      }
    } catch (e) {
      // El propio carácter periódico de la tarea es el reintento.
      await DiagLog.log('safety: error $e');
    }
  }

  /// Construye el DateTime de hoy a la hora "HH:MM".
  static DateTime _todayAt(DateTime now, String hm) {
    final p = hm.split(':');
    return DateTime(
        now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }
}
