import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Registro de diagnóstico persistente en disco.
///
/// El fichaje automático corre en segundo plano (alarmas / WorkManager), horas
/// después y en un isolate que muere enseguida; logcat se pierde. Este log
/// escribe cada paso a un fichero en la carpeta externa de la app
/// (`Android/data/es.tessera.app/files/tessera-diag.log`), legible desde
/// Ajustes y, en depuración, por `adb`.
class DiagLog {
  static const _name = 'tessera-diag.log';
  static const _maxBytes = 256 * 1024; // ~256 KB, se recorta a la mitad

  static Future<File?> _file() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;
    return File('${dir.path}/$_name');
  }

  /// Añade una línea con marca de tiempo. Nunca lanza.
  static Future<void> log(String msg) async {
    debugPrint('Tessera/diag: $msg');
    try {
      final f = await _file();
      if (f == null) return;
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final ts = '${now.year}-${two(now.month)}-${two(now.day)} '
          '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
      await f.writeAsString('$ts  $msg\n',
          mode: FileMode.append, flush: true);
      if (await f.length() > _maxBytes) {
        final txt = await f.readAsString();
        await f.writeAsString(txt.substring(txt.length - _maxBytes ~/ 2));
      }
    } catch (_) {/* el diagnóstico nunca debe romper el flujo */}
  }

  /// Contenido completo del log (para mostrar/compartir desde Ajustes).
  static Future<String> read() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return '(sin registros todavía)';
      return await f.readAsString();
    } catch (e) {
      return 'No se pudo leer el log: $e';
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}
