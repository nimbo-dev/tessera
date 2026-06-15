import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/diag_log.dart';
import '../utils/contact.dart';
import '../utils/theme.dart';

/// Pantalla de diagnóstico: muestra el registro de actividad del fichaje y
/// permite enviarlo al desarrollador con un toque (correo prerelleno con la
/// info del dispositivo + el log reciente). Pensada para soporte: si a alguien
/// le falla un fichaje, manda esto y se ve exactamente qué pasó.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _log = 'Cargando…';
  String _device = '';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await DiagLog.read();
    final pkg = await PackageInfo.fromPlatform();
    String device = 'Android';
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      device = '${a.manufacturer} ${a.model} — Android ${a.version.release} '
          '(SDK ${a.version.sdkInt})';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _log = log;
      _device = device;
      _version = 'Tessera v${pkg.version} (${pkg.buildNumber})';
    });
  }

  /// Texto que se envía: cabecera con dispositivo/versión + últimas líneas.
  String _report() {
    final lines = _log.trim().split('\n');
    final recent = lines.length > 60
        ? lines.sublist(lines.length - 60).join('\n')
        : _log.trim();
    return '$_version\n$_device\n'
        '──────────────────────────\n'
        '$recent\n'
        '──────────────────────────\n'
        '(Describe aquí qué fichaje falló y a qué hora, si puedes.)';
  }

  Future<void> _enviar() async {
    final subject = Uri.encodeComponent('Tessera — diagnóstico ($_version)');
    final body = Uri.encodeComponent(_report());
    try {
      await AndroidIntent(
        action: 'android.intent.action.SENDTO',
        data: 'mailto:$contactEmail?subject=$subject&body=$body',
      ).launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _report()));
      _snack('No se encontró app de correo. Informe copiado al portapapeles.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Si un fichaje no salió bien, envíame este registro y veré '
                'exactamente qué ocurrió. No incluye tu contraseña ni datos '
                'personales.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _log.isEmpty ? '(sin registros todavía)' : _log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _enviar,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar al desarrollador'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _report()));
                      _snack('Informe copiado.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await DiagLog.clear();
                      await _load();
                      _snack('Registro borrado.');
                    },
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppTheme.error),
                    label: Text('Borrar',
                        style: TextStyle(color: AppTheme.error)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
