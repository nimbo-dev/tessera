import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/schedule_entry.dart';
import '../models/weekly_schedule.dart';
import 'fichaje_service.dart';
import 'seneca_api.dart';
import 'storage_service.dart';

// ── Callbacks top-level (obligatorio para AndroidAlarmManager) ───────────────

/// Prep alarm: 30 min antes de la primera clase, consulta Séneca y
/// programa las alarmas exactas de fichaje para hoy.
@pragma('vm:entry-point')
Future<void> prepAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScheduleService._onPrepFired();
}

@pragma('vm:entry-point')
Future<void> fichajeEntradaCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FichajeService.ejecutarFichaje('E');
}

@pragma('vm:entry-point')
Future<void> fichajeSalidaCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FichajeService.ejecutarFichaje('S');
}

/// Servicio de programación de alarmas.
///
/// Arquitectura:
///   1. Prep alarm (AlarmManager, exacta) → 30 min antes de firstIn
///   2. Prep llama a getSchedule() para confirmar que hay clase hoy
///   3. Si hay clase → programa alarmas exactas de entrada/salida
///   4. Fallback: si AlarmManager falla → WorkManager expedited (best-effort)
///
/// Modo "periodo no lectivo": cuando está activo en la configuración, ignora
/// el horario de Séneca y ficha de lunes a viernes a horario fijo (p. ej. 9–14).
class ScheduleService {
  // IDs estables entre reinicios
  static const _prepBase     = 10; // 11=Lun … 15=Vie
  static const _idEntrada    = 21;
  static const _idSalida     = 22;
  static const _wkFallback   = 'tessera_fallback';

  // ── Importar horario semanal desde Séneca ─────────────────────────────────

  static Future<WeeklySchedule> importFromSeneca(String token) async {
    final now    = DateTime.now();
    // Lunes de la semana actual
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days   = <int, DayEntry>{};

    for (int i = 0; i < 5; i++) {
      final day = monday.add(Duration(days: i));
      try {
        final entries = await SenecaApi.getSchedule(token, day);
        final summary = DayScheduleSummary.fromEntries(day, entries);
        if (summary != null) {
          days[day.weekday] = DayEntry(
            firstIn: summary.firstIn,
            lastOut: summary.lastOut,
          );
        }
      } catch (_) {
        // Si un día falla, continuamos con el resto
      }
    }

    final schedule = WeeklySchedule(days: days, importedAt: now);
    await StorageService.saveWeeklySchedule(schedule);
    return schedule;
  }

  // ── Programar alarmas de prep para toda la semana ─────────────────────────

  static Future<void> scheduleWeek(WeeklySchedule schedule) async {
    final config = await StorageService.loadConfig();
    if (!config.autoFichajeEnabled) return;

    final now = DateTime.now();

    // Periodo no lectivo: programar los 5 días laborables a horario fijo,
    // independientemente del horario importado.
    if (config.nonLectivoEnabled) {
      for (int weekday = 1; weekday <= 5; weekday++) {
        final prepTime = _nextOccurrence(weekday, config.nonLectivoStart)
            .subtract(const Duration(minutes: 30));
        if (!prepTime.isAfter(now)) continue;
        await _schedulePrep(weekday, prepTime);
      }
      return;
    }

    for (final entry in schedule.days.entries) {
      final weekday  = entry.key;
      final dayEntry = entry.value;

      final prepTime = _nextOccurrence(weekday, dayEntry.firstIn)
          .subtract(const Duration(minutes: 30));

      if (!prepTime.isAfter(now)) continue;
      await _schedulePrep(weekday, prepTime);
    }
  }

  // ── Lógica interna cuando se activa el prep alarm ─────────────────────────

  static Future<void> _onPrepFired() async {
    _log('prep disparada a las ${DateTime.now()}');
    final config = await StorageService.loadConfig();
    if (!config.autoFichajeEnabled) {
      _log('autoFichaje desactivado → no hago nada');
      return;
    }

    try {
      final creds = await StorageService.loadCredentials();
      final token = await SenecaApi.silentLogin(
        username:        creds['username']!,
        password:        creds['password']!,
        persistentToken: creds['persistentToken']!,
        centerId:        config.centerId,
        codeProfile:     config.codeProfile,
      );
      _log('login silencioso OK');

      final today = DateTime.now();
      String firstIn;
      String lastOut;

      if (config.nonLectivoEnabled) {
        // Horario fijo de periodo no lectivo, sin consultar Séneca.
        firstIn = config.nonLectivoStart;
        lastOut = config.nonLectivoEnd;
        _log('modo no lectivo: $firstIn–$lastOut');
      } else {
        final entries = await SenecaApi.getSchedule(token, today);
        final summary = DayScheduleSummary.fromEntries(today, entries);

        if (summary == null) {
          _log('Séneca no devuelve clases hoy → reprogramo semana siguiente');
          await _reprogramNextWeek(today.weekday);
          return;
        }
        firstIn = summary.firstIn;
        lastOut = summary.lastOut;
        _log('horario de hoy: $firstIn–$lastOut');

        // Auto-refresco del esqueleto: guardamos el horario real de hoy para
        // que la programación del despertador no se quede desactualizada si tu
        // horario cambia. Así el botón de Ajustes deja de ser obligatorio.
        await _updateStoredDay(today.weekday, firstIn, lastOut);
      }

      final t = _parseHM;

      if (config.fichaEntrada) {
        final hm   = t(firstIn);
        // Hora al azar dentro de la ventana, no un offset fijo (más natural).
        final when = DateTime(today.year, today.month, today.day, hm.$1, hm.$2)
            .subtract(Duration(
                seconds: _randomOffsetSeconds(config.marginEntradaMinutes)));
        if (when.isAfter(today)) {
          await _scheduleExact(_idEntrada, when, fichajeEntradaCallback);
          _log('ENTRADA programada para $when');
        } else {
          _log('hora de entrada ya pasada ($when) → no se programa');
        }
      }

      if (config.fichaSalida) {
        final hm   = t(lastOut);
        final when = DateTime(today.year, today.month, today.day, hm.$1, hm.$2)
            .add(Duration(
                seconds: _randomOffsetSeconds(config.marginSalidaMinutes)));
        if (when.isAfter(today)) {
          await _scheduleExact(_idSalida, when, fichajeSalidaCallback);
          _log('SALIDA programada para $when');
        } else {
          _log('hora de salida ya pasada ($when) → no se programa');
        }
      }

      // Reprogramar prep alarm para la semana siguiente
      await _reprogramNextWeek(today.weekday);

    } catch (e) {
      _log('ERROR en prep: $e → fallback WorkManager en 5 min');
      // Fallback: WorkManager expedited en 5 min para reintentar el fichaje
      await Workmanager().registerOneOffTask(
        _wkFallback,
        _wkFallback,
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  static void _log(String msg) => debugPrint('Tessera/schedule: $msg');

  static final _rng = Random();

  /// Offset aleatorio en segundos dentro de la ventana [0, margen·60]. Así la
  /// hora exacta de fichaje varía cada día y no es siempre la misma.
  static int _randomOffsetSeconds(int marginMinutes) {
    if (marginMinutes <= 0) return 0;
    return _rng.nextInt(marginMinutes * 60 + 1);
  }

  // ── Cancelar todo ─────────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    for (int i = 1; i <= 5; i++) {
      try { await AndroidAlarmManager.cancel(_prepBase + i); } catch (_) {}
    }
    try { await AndroidAlarmManager.cancel(_idEntrada); } catch (_) {}
    try { await AndroidAlarmManager.cancel(_idSalida);  } catch (_) {}
    await Workmanager().cancelAll();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Programa la prep alarm de un día. Con fallback a WorkManager si la
  /// alarma exacta no está disponible (salvo que [allowFallback] sea false).
  static Future<void> _schedulePrep(int weekday, DateTime prepTime,
      {bool allowFallback = true}) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        prepTime,
        _prepBase + weekday,
        prepAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true, // imprescindible para que dispare en modo Doze
        rescheduleOnReboot: true,
      );
    } catch (_) {
      // AlarmManager no disponible (permiso denegado) — WorkManager fallback
      if (!allowFallback) return;
      final delay = prepTime.difference(DateTime.now());
      if (delay.isNegative) return;
      await Workmanager().registerOneOffTask(
        'tessera_prep_$weekday',
        'tessera_prep',
        initialDelay: delay,
        inputData: {'weekday': weekday},
        tag: 'tessera_prep',
      );
    }
  }

  static Future<void> _scheduleExact(
      int id, DateTime when, Function callback) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        when, id, callback,
        exact: true, wakeup: true,
        allowWhileIdle: true, // dispara a la hora exacta aunque esté en Doze
      );
    } catch (_) {
      // Fallback WorkManager
      final delay = when.difference(DateTime.now());
      if (delay.isNegative) return;
      await Workmanager().registerOneOffTask(
        'tessera_fichaje_$id',
        id == _idEntrada ? 'tessera_entrada' : 'tessera_salida',
        initialDelay: delay,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  /// Actualiza en el esqueleto guardado el horario real de un día (obtenido en
  /// vivo de Séneca por la prep alarm). Solo escribe si ha cambiado.
  static Future<void> _updateStoredDay(
      int weekday, String firstIn, String lastOut) async {
    final current  = await StorageService.loadWeeklySchedule();
    final existing = current?.getDay(weekday);
    if (existing != null &&
        existing.firstIn == firstIn &&
        existing.lastOut == lastOut) {
      return; // sin cambios, no reescribimos
    }
    final days = Map<int, DayEntry>.from(current?.days ?? const {});
    days[weekday] = DayEntry(firstIn: firstIn, lastOut: lastOut);
    await StorageService.saveWeeklySchedule(
      WeeklySchedule(days: days, importedAt: DateTime.now()),
    );
    _log('esqueleto actualizado (weekday $weekday): $firstIn–$lastOut');
  }

  static Future<void> _reprogramNextWeek(int weekday) async {
    final config = await StorageService.loadConfig();

    String? firstIn;
    if (config.nonLectivoEnabled) {
      firstIn = config.nonLectivoStart;
    } else {
      final schedule = await StorageService.loadWeeklySchedule();
      firstIn = schedule?.getDay(weekday)?.firstIn;
    }
    if (firstIn == null) return;

    final nextPrep = _nextOccurrence(weekday, firstIn, skipToday: true)
        .subtract(const Duration(minutes: 30));
    await _schedulePrep(weekday, nextPrep, allowFallback: false);
  }

  /// Próxima aparición de [weekday] a la hora [timeStr].
  /// Si [skipToday] es true, busca la semana siguiente aunque hoy sea ese día.
  static DateTime _nextOccurrence(int weekday, String timeStr,
      {bool skipToday = false}) {
    final now  = DateTime.now();
    final hm   = _parseHM(timeStr);
    int   diff = (weekday - now.weekday) % 7;

    if (diff == 0) {
      final todayAt = DateTime(now.year, now.month, now.day, hm.$1, hm.$2);
      // Si ya pasó o está a menos de 25 min → semana que viene
      if (skipToday || todayAt.isBefore(now.add(const Duration(minutes: 25)))) {
        diff = 7;
      }
    }

    final target = now.add(Duration(days: diff));
    return DateTime(target.year, target.month, target.day, hm.$1, hm.$2);
  }

  static (int, int) _parseHM(String time) {
    final p = time.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }
}
