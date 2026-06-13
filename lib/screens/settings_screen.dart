import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../models/weekly_schedule.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/schedule_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../utils/theme.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String token;
  const SettingsScreen({super.key, required this.token});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppConfig? _config;
  WeeklySchedule? _weekly;
  String? _username;
  String _appVersion = '';
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await StorageService.loadConfig();
    final w = await StorageService.loadWeeklySchedule();
    final creds = await StorageService.loadCredentials();
    final pkg = await PackageInfo.fromPlatform();
    setState(() {
      _config = c;
      _weekly = w;
      _username = creds['username'];
      _appVersion = pkg.version;
      _loading = false;
    });
  }

  Future<void> _save(AppConfig updated) async {
    await StorageService.saveConfig(updated);
    setState(() => _config = updated);
    // Reprogramar las alarmas con la nueva configuración.
    if (updated.autoFichajeEnabled) {
      await ScheduleService.scheduleWeek(_weekly ??
          WeeklySchedule(days: const {}, importedAt: DateTime.now()));
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _updateSchedule() async {
    setState(() => _importing = true);
    try {
      final schedule = await ScheduleService.importFromSeneca(widget.token);
      setState(() => _weekly = schedule);
      if (_config?.autoFichajeEnabled == true && !_config!.nonLectivoEnabled) {
        await ScheduleService.scheduleWeek(schedule);
      }
      _snack('Horario actualizado — ${schedule.days.length} días lectivos',
          AppTheme.success);
    } catch (e) {
      _snack('Error al actualizar: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Abre un selector de hora y devuelve "HH:MM".
  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked('${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  void _showMarginInfo() {
    final entrada = _config?.marginEntradaMinutes ?? 0;
    final salida = _config?.marginSalidaMinutes ?? 0;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(children: [
          Icon(Icons.schedule_rounded, color: AppTheme.accent, size: 22),
          const SizedBox(width: 10),
          const Expanded(child: Text('Hora de fichaje')),
        ]),
        content: Text.rich(
          TextSpan(
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(
                  text: 'Fichar siempre a la misma hora exacta es poco '
                      'natural. Por eso Tessera no usa una hora fija: cada día '
                      'elige un momento '),
              TextSpan(
                  text: 'al azar',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              const TextSpan(text: ' dentro de tu margen.\n\n'),
              TextSpan(
                  text: '•  Entrada: hasta $entrada min antes de tu primera '
                      'clase.\n'),
              TextSpan(
                  text: '•  Salida: hasta $salida min después de tu última '
                      'clase.\n\n'),
              const TextSpan(
                  text: 'Así cada día es ligeramente distinto, como un '
                      'fichaje humano.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdatesManually() async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buscando actualizaciones…')));
    try {
      final u = await UpdateService.checkForUpdate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(u == null
            ? 'Estás en la última versión.'
            : 'Disponible la versión ${u.version}. Ve a Inicio para actualizar.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo comprobar (¿sin conexión?).')));
    }
  }

  Future<void> _resetCredentials() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Desconectar cuenta?'),
        content: Text(
          'Se eliminarán tus credenciales y el token de sesión. '
          'Tendrás que volver a conectar tu cuenta de Séneca.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearCredentials();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading || _config == null
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Ajustes',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 28)),
                ),
                _buildAccountCard(),
                const SizedBox(height: 24),
                _buildSection('Apariencia', [
                  _buildAppearanceSelector(),
                ]),

                const SizedBox(height: 20),
                _buildSection('Qué fichar', [
                  _buildSwitch(
                    icon: Icons.login_rounded,
                    iconColor: AppTheme.success,
                    label: 'Fichar entrada',
                    subtitle: 'Enviar fichaje al inicio de tu primera clase',
                    value: _config!.fichaEntrada,
                    onChanged: (v) => _save(_config!.copyWith(fichaEntrada: v)),
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    icon: Icons.logout_rounded,
                    iconColor: AppTheme.error,
                    label: 'Fichar salida',
                    subtitle: 'Enviar fichaje al finalizar tu última clase',
                    value: _config!.fichaSalida,
                    onChanged: (v) => _save(_config!.copyWith(fichaSalida: v)),
                  ),
                ]),

                const SizedBox(height: 20),
                _buildSection('Periodo no lectivo', [
                  _buildSwitch(
                    icon: Icons.beach_access_outlined,
                    iconColor: AppTheme.textSecondary,
                    label: 'Horario reducido (no lectivo)',
                    subtitle: 'Horario fijo de L a V, ignorando tus clases. '
                        'Para inicio de septiembre y final de junio.',
                    value: _config!.nonLectivoEnabled,
                    onChanged: (v) =>
                        _save(_config!.copyWith(nonLectivoEnabled: v)),
                  ),
                  if (_config!.nonLectivoEnabled) ...[
                    _buildDivider(),
                    _buildTimeRow(
                      icon: Icons.login_rounded,
                      iconColor: AppTheme.success,
                      label: 'Hora de entrada',
                      value: _config!.nonLectivoStart,
                      onTap: () => _pickTime(_config!.nonLectivoStart,
                          (t) => _save(_config!.copyWith(nonLectivoStart: t))),
                    ),
                    _buildDivider(),
                    _buildTimeRow(
                      icon: Icons.logout_rounded,
                      iconColor: AppTheme.error,
                      label: 'Hora de salida',
                      value: _config!.nonLectivoEnd,
                      onTap: () => _pickTime(_config!.nonLectivoEnd,
                          (t) => _save(_config!.copyWith(nonLectivoEnd: t))),
                    ),
                  ],
                ]),

                const SizedBox(height: 20),
                _buildExpansionCard(
                  icon: Icons.tune_rounded,
                  label: 'Avanzado',
                  subtitle: 'Horario y márgenes de fichaje',
                  children: [
                    _buildDivider(),
                    _buildActionRow(
                      icon: Icons.sync_rounded,
                      iconColor: AppTheme.textSecondary,
                      label: 'Actualizar horario desde Séneca',
                      subtitle: _weekly == null
                          ? 'Aún no importado'
                          : 'Actualizado el ${_fmtDate(_weekly!.importedAt)}',
                      trailing: _importing
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.accent))
                          : null,
                      onTap: _importing ? null : _updateSchedule,
                    ),
                    _buildDivider(),
                    _buildMarginRow(
                      icon: Icons.timer_outlined,
                      iconColor: AppTheme.success,
                      label: 'Fichaje de entrada',
                      suffix: 'antes de la 1ª clase',
                      value: _config!.marginEntradaMinutes,
                      onChanged: (v) =>
                          _save(_config!.copyWith(marginEntradaMinutes: v)),
                    ),
                    _buildDivider(),
                    _buildMarginRow(
                      icon: Icons.timer_off_outlined,
                      iconColor: AppTheme.error,
                      label: 'Fichaje de salida',
                      suffix: 'después de la última clase',
                      value: _config!.marginSalidaMinutes,
                      onChanged: (v) =>
                          _save(_config!.copyWith(marginSalidaMinutes: v)),
                    ),
                    _buildDivider(),
                    _buildActionRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.accent,
                      label: 'Cómo se elige la hora',
                      subtitle: 'El fichaje no es siempre a la misma hora',
                      onTap: _showMarginInfo,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _buildSection('Acerca de', [
                  _buildActionRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.textSecondary,
                    label: 'Tessera',
                    trailing: Text(_appVersion.isEmpty ? '' : 'v$_appVersion',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14)),
                    onTap: null,
                  ),
                  _buildDivider(),
                  _buildActionRow(
                    icon: Icons.system_update_rounded,
                    iconColor: AppTheme.textSecondary,
                    label: 'Buscar actualizaciones',
                    onTap: _checkUpdatesManually,
                  ),
                ]),

                const SizedBox(height: 40),
              ],
            ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _buildAccountCard() {
    final user = _username ?? '';
    final initial = user.isNotEmpty ? user[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: AppTheme.cardShadow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.isEmpty ? 'Cuenta de Séneca' : user,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 14),
                  SizedBox(width: 5),
                  Text('Conectado a Séneca',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
            tooltip: 'Desconectar',
            onPressed: _resetCredentials,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSelector() {
    final mode = themeNotifier.value;
    Widget seg(String label, IconData icon, ThemeMode m) {
      final sel = mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            themeNotifier.value = m;
            StorageService.saveThemeMode(m);
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? AppTheme.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel
                      ? AppTheme.accent.withValues(alpha: 0.5)
                      : Colors.transparent),
            ),
            child: Column(children: [
              Icon(icon,
                  size: 20,
                  color: sel ? AppTheme.accent : AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sel ? AppTheme.accent : AppTheme.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(children: [
        seg('Claro', Icons.light_mode_rounded, ThemeMode.light),
        seg('Oscuro', Icons.dark_mode_rounded, ThemeMode.dark),
        seg('Auto', Icons.brightness_auto_rounded, ThemeMode.system),
      ]),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: AppTheme.cardShadow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(children: children),
      ),
    ],
  );

  /// Tarjeta desplegable estilo menú de Android (ExpansionTile animado).
  Widget _buildExpansionCard({
    required IconData icon,
    required String label,
    String? subtitle,
    required List<Widget> children,
  }) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: AppTheme.cardShadow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Theme(
          // Quita las líneas divisorias que ExpansionTile dibuja al expandir.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // Conserva el estado expandido entre reconstrucciones (al tocar
            // los steppers se llama setState y se reconstruye la pantalla).
            key: const PageStorageKey('avanzado'),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(icon, color: AppTheme.textSecondary, size: 22),
            title: Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
            iconColor: AppTheme.textSecondary,
            collapsedIconColor: AppTheme.textSecondary,
            childrenPadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            children: children,
          ),
        ),
      );

  Widget _buildDivider() => Divider(
    height: 1,
    indent: 52,
    color: Colors.white.withValues(alpha: 0.07),
  );

  Widget _buildSwitch({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.accent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _buildTimeRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppTheme.accent, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent)),
              ),
            ],
          ),
        ),
      );

  Widget _buildMarginRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String suffix,
    required int value,
    required ValueChanged<int> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.accent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('hasta $value min $suffix',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Row(
              children: [
                _stepBtn(Icons.remove_rounded, () {
                  if (value > 0) onChanged(value - 1);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$value',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: AppTheme.accent)),
                ),
                _stepBtn(Icons.add_rounded, () {
                  if (value < 30) onChanged(value + 1);
                }),
              ],
            ),
          ],
        ),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.accent, size: 18),
    ),
  );

  Widget _buildActionRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppTheme.accent, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary, size: 18)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      );
}
