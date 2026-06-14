import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/app_config.dart';
import '../models/schedule_entry.dart';
import '../models/weekly_schedule.dart';
import '../services/schedule_service.dart';
import '../services/seneca_api.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  final VoidCallback? onOpenHistorial;
  const HomeScreen({
    super.key,
    required this.accessToken,
    this.onOpenHistorial,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _token;
  AppConfig?      _config;
  DayScheduleSummary? _today;
  WeeklySchedule? _weekly;
  bool _loadingSchedule  = true;
  bool _fichando         = false;
  bool _scheduleExpanded = false;
  String? _lastFichajeMsg;
  List<FichajeRecord>? _recentFichajes;
  bool _loadingFichajes = true;
  bool _fichajesError = false;
  UpdateInfo? _update;
  bool _downloading = false;
  double _dlProgress = 0;

  static const _weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _token = widget.accessToken;
    _init();
  }

  Future<void> _init() async {
    _config = await StorageService.loadConfig();
    _weekly = await StorageService.loadWeeklySchedule();
    await _loadTodaySchedule();
    if (_config!.autoFichajeEnabled &&
        (_weekly != null || _config!.nonLectivoEnabled)) {
      await ScheduleService.scheduleWeek(_weekly ??
          WeeklySchedule(days: const {}, importedAt: DateTime.now()));
    }
    await _loadRecentFichajes();
    await _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final u = await UpdateService.checkForUpdate();
      if (mounted && u != null) setState(() => _update = u);
    } catch (_) {
      // sin conexión o sin releases publicadas: lo ignoramos
    }
  }

  Future<void> _doUpdate() async {
    final u = _update;
    if (u == null) return;
    setState(() { _downloading = true; _dlProgress = 0; });
    try {
      await UpdateService.downloadAndInstall(
        u.apkUrl,
        onProgress: (p) { if (mounted) setState(() => _dlProgress = p); },
      );
      // El instalador de Android toma el control a partir de aquí.
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    }
  }

  Future<void> _loadRecentFichajes() async {
    if (mounted) {
      setState(() { _loadingFichajes = true; _fichajesError = false; });
    }
    try {
      final list =
          await _withAuthRetry(() => SenecaApi.getHistorial(_token, page: 1));
      list.sort((a, b) =>
          (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      if (mounted) {
        setState(() {
          _recentFichajes = list;
          _loadingFichajes = false;
          _fichajesError = false;
        });
      }
    } catch (e) {
      // No confundir "sin fichajes" con "no se pudo cargar": registramos el
      // error y lo señalamos para ofrecer reintento.
      debugPrint('Tessera: error cargando últimos fichajes: $e');
      if (mounted) {
        setState(() { _loadingFichajes = false; _fichajesError = true; });
      }
    }
  }

  /// Re-autentica con las credenciales guardadas (sin SMS) y refresca _token.
  Future<void> _relogin() async {
    _config ??= await StorageService.loadConfig();
    final creds = await StorageService.loadCredentials();
    _token = await SenecaApi.silentLogin(
      username:        creds['username']!,
      password:        creds['password']!,
      persistentToken: creds['persistentToken']!,
      centerId:        _config!.centerId,
      codeProfile:     _config!.codeProfile,
    );
  }

  /// Ejecuta [action]; si Séneca responde 401 (token de memoria caducado o
  /// invalidado por el fichaje automático en segundo plano), re-autentica una
  /// vez y reintenta. Es lo que hace iSeneca al vigilar la expiración.
  Future<T> _withAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SenecaApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      await _relogin();
      return await action();
    }
  }

  Future<void> _loadTodaySchedule() async {
    setState(() => _loadingSchedule = true);
    try {
      final entries =
          await _withAuthRetry(() => SenecaApi.getSchedule(_token, DateTime.now()));
      setState(() {
        _today = DayScheduleSummary.fromEntries(DateTime.now(), entries);
        _loadingSchedule = false;
      });
    } catch (_) {
      setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _toggleAuto(bool value) async {
    final newConfig = _config!.copyWith(autoFichajeEnabled: value);
    await StorageService.saveConfig(newConfig);
    setState(() => _config = newConfig);
    if (value) {
      await ScheduleService.scheduleWeek(_weekly ??
          WeeklySchedule(days: const {}, importedAt: DateTime.now()));
    } else {
      await ScheduleService.cancelAll();
    }
  }

  /// Fichaje manual: un único "control de presencia". Séneca alterna
  /// entrada/salida según el estado; enviamos un tipo orientativo por la hora.
  Future<void> _fichar() async {
    setState(() { _fichando = true; _lastFichajeMsg = null; });
    try {
      final type = DateTime.now().hour < 14 ? 'E' : 'S';
      await _withAuthRetry(() async {
        final key = await SenecaApi.getAccessPointKey(_token);
        await SenecaApi.registrarPresencia(_token, key, type);
      });
      setState(() =>
          _lastFichajeMsg = 'Fichaje registrado a las ${_fmt(DateTime.now())}');
    } on SenecaApiException catch (e) {
      setState(() => _lastFichajeMsg = 'Error: ${e.message}');
    } finally {
      setState(() => _fichando = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: _loadTodaySchedule,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                if (_update != null) ...[
                  _buildUpdateBanner(),
                  const SizedBox(height: 16),
                ],
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildTodayCard(),
                const SizedBox(height: 20),
                _buildManualCard(),
                if (_lastFichajeMsg != null) ...[
                  const SizedBox(height: 12),
                  _buildFeedback(_lastFichajeMsg!),
                ],
                const SizedBox(height: 20),
                _buildRecentCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Cabecera ──────────────────────────────────────────────────────────────

  static const _meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo',
      'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
      'diciembre'];

  String _dateLabel() {
    final d = DateTime.now();
    return '${_weekdays[d.weekday]}, ${d.day} de ${_meses[d.month]}';
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inicio',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 28)),
        const SizedBox(height: 2),
        Text(_dateLabel(),
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      ],
    ),
  );

  // ── Banner de actualización ───────────────────────────────────────────────

  Widget _buildUpdateBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      Icon(Icons.system_update_rounded, color: AppTheme.accent),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actualización disponible',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text('Versión ${_update!.version}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      _downloading
          ? SizedBox(
              width: 30, height: 30,
              child: CircularProgressIndicator(
                  value: _dlProgress > 0 ? _dlProgress : null,
                  strokeWidth: 3,
                  color: AppTheme.accent))
          : TextButton(onPressed: _doUpdate, child: const Text('Actualizar')),
    ]),
  );

  // ── Tarjeta estado on/off ─────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final enabled = _config?.autoFichajeEnabled ?? false;
    final nonLectivo = _config?.nonLectivoEnabled ?? false;
    // Se puede activar si hay horario importado o estamos en periodo no lectivo.
    final canEnable = (_weekly != null && !_weekly!.isEmpty) || nonLectivo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? [AppTheme.accent.withValues(alpha: 0.28), AppTheme.surface]
              : [AppTheme.surface, AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: enabled
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.hairline,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Fichaje automático activo' : 'Fichaje automático pausado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enabled ? AppTheme.accent : AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled && nonLectivo
                      ? 'Modo no lectivo: ficha ${_config!.nonLectivoStart}–${_config!.nonLectivoEnd} de L a V'
                      : enabled && canEnable
                          ? 'Tessera ficha por ti cada día lectivo'
                          : !canEnable
                              ? 'Importa tu horario en Ajustes para activar'
                              : 'Actívalo para que Tessera fiche solo',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_config != null && canEnable) ? _toggleAuto : null,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Horario de hoy ────────────────────────────────────────────────────────

  Widget _buildTodayCard() {
    final now = DateTime.now();
    final isWeekend = now.weekday >= 6;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: AppTheme.cardShadow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hoy',
                  style: Theme.of(context).textTheme.titleMedium),
              if (_loadingSchedule)
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 16),
          if (isWeekend)
            _chip(Icons.weekend_outlined, 'Fin de semana', AppTheme.textSecondary)
          else if (_today == null && !_loadingSchedule)
            _chip(Icons.event_busy_outlined, 'Sin clases hoy', AppTheme.warning)
          else if (_today != null) ...[
            Row(children: [
              _timeChip(Icons.login_rounded,  'Entrada', _today!.firstIn, AppTheme.success),
              const SizedBox(width: 12),
              _timeChip(Icons.logout_rounded, 'Salida',  _today!.lastOut, AppTheme.error),
            ]),
            const SizedBox(height: 14),
            _scheduleExpander(),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Fichaje manual ────────────────────────────────────────────────────────

  Widget _buildManualCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      boxShadow: AppTheme.cardShadow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fichaje manual', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Registra tu control de presencia ahora mismo.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        _FicharButton(loading: _fichando, onTap: _fichar),
      ],
    ),
  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);

  // ── Últimos fichajes ──────────────────────────────────────────────────────

  Widget _buildRecentCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      boxShadow: AppTheme.cardShadow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Últimos fichajes',
                style: Theme.of(context).textTheme.titleMedium),
            if (_recentFichajes != null && _recentFichajes!.isNotEmpty)
              InkWell(
                onTap: widget.onOpenHistorial,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Ver todo',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingFichajes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent)),
          )
        else if (_fichajesError)
          Row(children: [
            Expanded(
              child: _chip(Icons.cloud_off_outlined,
                  'No se pudieron cargar', AppTheme.textSecondary),
            ),
            TextButton(
              onPressed: _loadRecentFichajes,
              child: Text('Reintentar',
                  style: TextStyle(color: AppTheme.accent)),
            ),
          ])
        else if (_recentFichajes == null || _recentFichajes!.isEmpty)
          _chip(Icons.history_toggle_off_outlined, 'Sin fichajes recientes',
              AppTheme.textSecondary)
        else
          ...(_recentFichajes!.take(3).map(_fichajeRow)),
      ],
    ),
  ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0);

  Widget _fichajeRow(FichajeRecord r) {
    final color = r.isEntrada ? AppTheme.success : AppTheme.error;
    final label = r.isEntrada ? 'Entrada' : 'Salida';
    final icon  = r.isEntrada ? Icons.login_rounded : Icons.logout_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(_fmtFichaje(r.date),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }

  String _fmtFichaje(DateTime? d) {
    if (d == null) return '—';
    const dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${dias[d.weekday]} $hh:$mm';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _timeChip(IconData icon, String label, String time, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
              Text(time, style: TextStyle(color: color, fontSize: 18,
                  fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      );

  /// Cabecera "Ver horario (N clases)" que despliega/oculta el detalle horario.
  Widget _scheduleExpander() {
    final entries = _today!.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    final clases   = entries.where((e) => !e.isGuard).length;
    final guardias = entries.where((e) => e.isGuard).length;
    final parts = <String>[
      if (clases > 0)   '$clases ${clases == 1 ? 'clase' : 'clases'}',
      if (guardias > 0) '$guardias ${guardias == 1 ? 'guardia' : 'guardias'}',
    ];
    final summary = parts.join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(
                _scheduleExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 20,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 4),
              Text(
                _scheduleExpanded
                    ? 'Ocultar horario'
                    : 'Ver horario ($summary)',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),
        if (_scheduleExpanded) ...[
          const SizedBox(height: 8),
          ...(_today!.entries.map(_scheduleRow)),
        ],
      ],
    );
  }

  Widget _scheduleRow(ScheduleEntry e) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 90,
          child: Text('${e.initHour}–${e.endHour}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
      Expanded(child: Text('${e.subject}  ${e.units}',
          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _chip(IconData icon, String text, Color color) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(color: color, fontSize: 14)),
  ]);

  Widget _buildFeedback(String msg) {
    final isOk = !msg.startsWith('Error');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isOk ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (isOk ? AppTheme.success : AppTheme.error).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(isOk ? Icons.check_circle_outline : Icons.error_outline,
            color: isOk ? AppTheme.success : AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Text(msg, style: TextStyle(
            color: isOk ? AppTheme.success : AppTheme.error, fontSize: 13)),
      ]),
    ).animate().fadeIn();
  }
}

/// Botón único de "control de presencia" (la app oficial de Séneca también
/// usa un solo botón que alterna entrada/salida).
class _FicharButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _FicharButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accent))
                  : Icon(Icons.check_circle_outline_rounded,
                      color: AppTheme.accent, size: 26),
              const SizedBox(width: 10),
              Text(loading ? 'Fichando…' : 'Control de presencia',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
