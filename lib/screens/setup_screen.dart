import 'package:flutter/material.dart';
import '../services/schedule_service.dart';
import '../services/seneca_api.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../widgets/tessera_logo.dart';
import 'main_shell.dart';

/// Pantalla de configuración inicial — se muestra solo la primera vez.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _passVisible = false;
  bool _loading     = false;
  String? _error;

  // Estado del flujo
  bool _waitingForSms = false;
  String? _serverFaToken;
  String? _sendTo;

  // ── Paso 1: pedir el código SMS ───────────────────────────────────────────

  Future<void> _requestSms() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Introduce usuario y contraseña.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await SenecaApi.loginStep1(
          _userCtrl.text.trim(), _passCtrl.text);
      if (!result.needsSms && result.accessToken != null) {
        // Caso sin 2FA (poco probable)
        await _finishSetup(accessToken: result.accessToken!, persistentToken: null);
      } else {
        setState(() {
          _waitingForSms = true;
          _serverFaToken = result.twoFactorAuthToken;
          _sendTo        = result.sendTo;
        });
      }
    } on SenecaApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Paso 2: verificar código y guardar token ──────────────────────────────

  Future<void> _verifySms() async {
    if (_codeCtrl.text.length < 4) {
      setState(() => _error = 'Introduce el código SMS completo.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await SenecaApi.loginStep2(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        twoFactorAuthToken: _serverFaToken!,
        smsCode: _codeCtrl.text.trim(),
      );

      // Obtener centerId de la sesión
      int centerId = 344;
      String codeProfile = 'P';
      try {
        final info = await SenecaApi.getInfoSession(result.accessToken);
        final centers = (info['centers'] as List<dynamic>?) ?? [];
        if (centers.isNotEmpty) {
          final c = centers.first as Map<String, dynamic>;
          centerId    = int.tryParse(c['centerId'].toString()) ?? 344;
          codeProfile = c['codeProfile'] as String? ?? 'P';
        }
      } catch (_) {}

      await StorageService.saveCredentials(
        username:        _userCtrl.text.trim(),
        password:        _passCtrl.text,
        persistentToken: result.persistentToken ?? _serverFaToken!,
        centerId:        centerId,
        codeProfile:     codeProfile,
      );

      await _finishSetup(
          accessToken: result.accessToken,
          persistentToken: result.persistentToken);
    } on SenecaApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _finishSetup(
      {required String accessToken, String? persistentToken}) async {
    // Importar el horario semanal ya en el alta: así el fichaje automático
    // funciona desde el primer día y queda registrada la fecha de importación.
    try {
      final schedule = await ScheduleService.importFromSeneca(accessToken);
      await ScheduleService.scheduleWeek(schedule);
    } catch (_) {
      // Si falla, el usuario podrá importarlo luego desde Ajustes.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(accessToken: accessToken)),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 48),
              if (!_waitingForSms) _buildCredentials(),
              if (_waitingForSms)  _buildSmsVerification(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildError(_error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const TesseraLogo(),
      const SizedBox(height: 16),
      Text(
        'Conecta tu cuenta de Séneca una sola vez y la app fichará automáticamente cada día.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      _buildInfoCard(),
    ],
  );

  Widget _buildInfoCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Cómo funciona?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.accent)),
        const SizedBox(height: 12),
        _step('1', 'Introduces tu usuario y contraseña de Séneca.'),
        _step('2', 'Séneca enviará un código SMS a tu móvil.'),
        _step('3', 'Introduces el código — este es el único SMS que necesitarás.'),
        _step('4', 'Tessera guardará un token seguro y nunca más te pedirá credenciales.'),
      ],
    ),
  );

  Widget _step(String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(n,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );

  Widget _buildCredentials() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Tus credenciales de Séneca',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      TextFormField(
        controller: _userCtrl,
        decoration: const InputDecoration(
          labelText: 'Usuario',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
        textInputAction: TextInputAction.next,
        autocorrect: false,
        keyboardType: TextInputType.name,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passCtrl,
        obscureText: !_passVisible,
        decoration: InputDecoration(
          labelText: 'Contraseña',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            icon: Icon(_passVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _passVisible = !_passVisible),
          ),
        ),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _requestSms(),
      ),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: _loading ? null : _requestSms,
        child: _loading
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Text('Conectar con Séneca'),
      ),
    ],
  );

  Widget _buildSmsVerification() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Código de verificación',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Séneca ha enviado un SMS${_sendTo != null ? " al ${_sendTo}" : ""}. Introduce el código:',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
        maxLength: 7,
        decoration: const InputDecoration(
          hintText: '• • • • • •',
          counterText: '',
        ),
        onFieldSubmitted: (_) => _verifySms(),
      ),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: _loading ? null : _verifySms,
        child: _loading
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Text('Verificar y activar'),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() {
          _waitingForSms = false;
          _serverFaToken = null;
          _error = null;
        }),
        child: const Text('Volver atrás'),
      ),
    ],
  );

  Widget _buildError(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ),
      ],
    ),
  );
}
