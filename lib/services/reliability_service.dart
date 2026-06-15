import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Estado de los permisos/ajustes que el fichaje automático necesita para
/// ejecutarse de forma fiable en segundo plano.
///
/// El Manifest los declara, pero en Android moderno hay que **pedirlos en
/// runtime**: si no, el sistema (y sobre todo capas como MIUI/One UI/EMUI)
/// congela la app y los fichajes salen tarde o se pierden.
class ReliabilityStatus {
  /// Permiso de notificaciones (avisos de fichaje + feedback de errores).
  final bool notifications;

  /// La app está exenta de la optimización de batería del sistema.
  final bool batteryUnrestricted;

  const ReliabilityStatus({
    required this.notifications,
    required this.batteryUnrestricted,
  });

  /// Falta algo crítico para que el fichaje en segundo plano sea fiable.
  bool get hasIssues => !notifications || !batteryUnrestricted;
}

/// Familia de capa de Android, que determina la guía y el deep-link a medida.
/// Los fabricantes "agresivos" matan apps en segundo plano (ver dontkillmyapp).
enum OemFamily { xiaomi, samsung, huawei, oppo, oneplus, vivo, other }

class ReliabilityService {
  ReliabilityService._();

  static Future<ReliabilityStatus> check() async {
    return ReliabilityStatus(
      notifications: await Permission.notification.isGranted,
      batteryUnrestricted: await Permission.ignoreBatteryOptimizations.isGranted,
    );
  }

  /// Pide el permiso de notificaciones (diálogo estándar de Android 13+).
  static Future<bool> requestNotifications() async {
    final r = await Permission.notification.request();
    return r.isGranted;
  }

  /// Pide la exención de optimización de batería (diálogo estándar de Android).
  /// Es la parte **universal**: funciona en cualquier fabricante.
  static Future<bool> requestBatteryExemption() async {
    final r = await Permission.ignoreBatteryOptimizations.request();
    return r.isGranted;
  }

  /// Detecta la familia del fabricante a partir de `Build`.
  static Future<OemFamily> oemFamily() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final id = '${info.manufacturer} ${info.brand}'.toLowerCase();
      if (id.contains('xiaomi') ||
          id.contains('redmi') ||
          id.contains('poco')) {
        return OemFamily.xiaomi;
      }
      if (id.contains('samsung')) return OemFamily.samsung;
      if (id.contains('huawei') || id.contains('honor')) {
        return OemFamily.huawei;
      }
      if (id.contains('oneplus')) return OemFamily.oneplus;
      if (id.contains('oppo') || id.contains('realme')) return OemFamily.oppo;
      if (id.contains('vivo') || id.contains('iqoo')) return OemFamily.vivo;
      return OemFamily.other;
    } catch (_) {
      return OemFamily.other;
    }
  }

  /// Texto guía con lo que el usuario debe activar a mano según el fabricante
  /// (lo que no se puede tocar por código). Vacío en fabricantes "buenos".
  static String guidanceText(OemFamily f) {
    switch (f) {
      case OemFamily.xiaomi:
        return 'Activa «Inicio automático» y pon la batería en «Sin '
            'restricciones».';
      case OemFamily.samsung:
        return 'En Batería, quita Tessera de «Apps en suspensión» (y de '
            '«suspensión profunda») y permite la actividad en segundo plano.';
      case OemFamily.huawei:
        return 'En «Inicio de aplicaciones», desactiva la gestión automática '
            'de Tessera y permite el inicio automático y en segundo plano.';
      case OemFamily.oppo:
        return 'Activa el «Inicio automático» de Tessera y permite la '
            'actividad en segundo plano.';
      case OemFamily.oneplus:
        return 'Activa el «Inicio automático» de Tessera y desactiva la '
            'optimización agresiva de batería.';
      case OemFamily.vivo:
        return 'Activa el «Inicio en segundo plano» (autostart) de Tessera.';
      case OemFamily.other:
        return '';
    }
  }

  /// Etiqueta del botón de deep-link, o `null` si para ese fabricante no hay
  /// una pantalla de autostart fiable (Samsung/otros → solo info de la app).
  static String? autostartLabel(OemFamily f) {
    switch (f) {
      case OemFamily.xiaomi:
      case OemFamily.oppo:
      case OemFamily.oneplus:
      case OemFamily.vivo:
        return 'Inicio automático';
      case OemFamily.huawei:
        return 'Inicio de apps';
      case OemFamily.samsung:
      case OemFamily.other:
        return null;
    }
  }

  /// Intenta abrir la pantalla de autostart del fabricante; si ninguno de los
  /// componentes candidatos existe, cae a los ajustes de la app.
  static Future<void> openAutostartSettings(OemFamily f) async {
    for (final c in _autostartComponents(f)) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: c[0],
          componentName: c[1],
        ).launch();
        return;
      } catch (_) {/* probamos el siguiente */}
    }
    await openAppSettings();
  }

  /// Componentes candidatos (paquete, clase) por fabricante. Son frágiles entre
  /// versiones, así que se prueban en orden y hay fallback a la info de la app.
  static List<List<String>> _autostartComponents(OemFamily f) {
    switch (f) {
      case OemFamily.xiaomi:
        return [
          [
            'com.miui.securitycenter',
            'com.miui.permcenter.autostart.AutoStartManagementActivity'
          ],
        ];
      case OemFamily.huawei:
        return [
          [
            'com.huawei.systemmanager',
            'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity'
          ],
          [
            'com.huawei.systemmanager',
            'com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity'
          ],
          [
            'com.huawei.systemmanager',
            'com.huawei.systemmanager.optimize.process.ProtectActivity'
          ],
        ];
      case OemFamily.oppo:
        return [
          [
            'com.coloros.safecenter',
            'com.coloros.safecenter.permission.startup.StartupAppListActivity'
          ],
          [
            'com.coloros.safecenter',
            'com.coloros.safecenter.startupapp.StartupAppListActivity'
          ],
          [
            'com.oppo.safe',
            'com.oppo.safe.permission.startup.StartupAppListActivity'
          ],
        ];
      case OemFamily.oneplus:
        return [
          [
            'com.oneplus.security',
            'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity'
          ],
        ];
      case OemFamily.vivo:
        return [
          [
            'com.vivo.permissionmanager',
            'com.vivo.permissionmanager.activity.BgStartUpManagerActivity'
          ],
          [
            'com.iqoo.secure',
            'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity'
          ],
        ];
      case OemFamily.samsung:
      case OemFamily.other:
        return const [];
    }
  }

  /// Abre los ajustes de la app (para revisar permisos manualmente). Es la vía
  /// universal para la hibernación y, en Samsung, las «apps en suspensión».
  static Future<void> openSettings() => openAppSettings();
}
