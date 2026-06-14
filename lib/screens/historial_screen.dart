import 'package:flutter/material.dart';
import '../models/weekly_schedule.dart';
import '../services/seneca_api.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

/// Historial de fichajes (control de presencia) con datos reales de Séneca
/// (GET horarios/registro-acceso). Dos vistas: lista paginada y calendario.
class HistorialScreen extends StatefulWidget {
  final String accessToken;
  const HistorialScreen({super.key, required this.accessToken});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

enum _Filter { todos, entradas, salidas }

class _HistorialScreenState extends State<HistorialScreen> {
  final _scroll = ScrollController();
  final List<FichajeRecord> _items = [];

  late String _token;
  WeeklySchedule? _weekly;
  int _page = 1;
  bool _loadingMore = false;
  bool _initialLoading = true;
  bool _hasMore = true;
  bool _error = false;
  _Filter _filter = _Filter.todos;

  bool _calendarView = false;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  static const _weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'];
  static const _months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo',
      'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
      'diciembre'];
  static const _monthsAbbr = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  @override
  void initState() {
    super.initState();
    _token = widget.accessToken;
    _scroll.addListener(_onScroll);
    StorageService.loadWeeklySchedule().then((w) {
      if (mounted) setState(() => _weekly = w);
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_calendarView &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // ── Carga / paginación ──────────────────────────────────────────────────

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() { _loadingMore = true; _error = false; });
    try {
      final page = await _withAuthRetry(
          () => SenecaApi.getHistorial(_token, page: _page));
      if (!mounted) return;
      setState(() {
        if (page.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(page);
          _page++;
        }
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _error = true;
      });
    }
  }

  /// Carga páginas hasta cubrir el mes [month] (o hasta que no haya más).
  Future<void> _ensureMonthLoaded(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    int guard = 0;
    while (_hasMore && guard < 40) {
      final oldest = _items.isEmpty ? null : _items.last.date;
      if (oldest != null && oldest.isBefore(monthStart)) break;
      await _loadMore();
      guard++;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _initialLoading = true;
      _error = false;
    });
    await _loadMore();
  }

  Future<void> _relogin() async {
    final config = await StorageService.loadConfig();
    final creds = await StorageService.loadCredentials();
    _token = await SenecaApi.silentLogin(
      username:        creds['username']!,
      password:        creds['password']!,
      persistentToken: creds['persistentToken']!,
      centerId:        config.centerId,
      codeProfile:     config.codeProfile,
    );
  }

  Future<T> _withAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SenecaApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      await _relogin();
      return await action();
    }
  }

  // ── Datos derivados ─────────────────────────────────────────────────────

  List<FichajeRecord> get _filtered {
    switch (_filter) {
      case _Filter.entradas:
        return _items.where((e) => e.isEntrada).toList();
      case _Filter.salidas:
        return _items.where((e) => !e.isEntrada).toList();
      case _Filter.todos:
        return _items;
    }
  }

  /// Aplana la lista en filas: cabeceras de día (DateTime) + fichajes.
  List<Object> get _rows {
    final out = <Object>[];
    String? lastKey;
    for (final f in _filtered) {
      final d = f.date;
      final key = d == null ? '—' : _key(d);
      if (key != lastKey) {
        out.add(d ?? '—');
        lastKey = key;
      }
      out.add(f);
    }
    return out;
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Map<String, List<FichajeRecord>> get _byDate {
    final m = <String, List<FichajeRecord>>{};
    for (final f in _items) {
      if (f.date == null) continue;
      m.putIfAbsent(_key(f.date!), () => []).add(f);
    }
    return m;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Historial',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 28)),
                  IconButton(
                    icon: Icon(
                        _calendarView
                            ? Icons.view_list_rounded
                            : Icons.calendar_month_rounded,
                        color: AppTheme.textSecondary),
                    tooltip: _calendarView ? 'Ver lista' : 'Ver calendario',
                    onPressed: () async {
                      setState(() => _calendarView = !_calendarView);
                      if (_calendarView) await _ensureMonthLoaded(_visibleMonth);
                    },
                  ),
                ],
              ),
            ),
            if (!_calendarView) _buildFilters(),
            const SizedBox(height: 4),
            Expanded(
                child: _calendarView ? _buildCalendar() : _buildList()),
          ],
        ),
      ),
    );
  }

  // ── Vista lista ──────────────────────────────────────────────────────────

  Widget _buildFilters() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(children: [
      _filterChip('Todos', _Filter.todos),
      const SizedBox(width: 8),
      _filterChip('Entradas', _Filter.entradas),
      const SizedBox(width: 8),
      _filterChip('Salidas', _Filter.salidas),
    ]),
  );

  Widget _filterChip(String label, _Filter f) {
    final selected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.18)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildList() {
    if (_initialLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error && _items.isEmpty) {
      return _centered(Icons.cloud_off_rounded,
          'No se pudo cargar el historial', 'Desliza para reintentar');
    }
    final rows = _rows;
    if (rows.isEmpty) {
      return _centered(Icons.history_toggle_off_outlined, 'Sin fichajes',
          'No hay registros para este filtro');
    }
    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: rows.length + 1,
        itemBuilder: (ctx, i) {
          if (i == rows.length) {
            return _loadingMore
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accent))),
                  )
                : const SizedBox(height: 8);
          }
          final row = rows[i];
          if (row is FichajeRecord) return _fichajeRow(row);
          return _dayHeader(row is DateTime ? row : null);
        },
      ),
    );
  }

  Widget _dayHeader(DateTime? d) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(_dayLabel(d),
        style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5)),
  );

  Widget _fichajeRow(FichajeRecord r) {
    final color = r.isEntrada ? AppTheme.success : AppTheme.error;
    final label = r.isEntrada ? 'Entrada' : 'Salida';
    final icon  = r.isEntrada ? Icons.login_rounded : Icons.logout_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500))),
        if (r.mode.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(r.mode,
                style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11)),
          ),
        Text(_hm(r.date),
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Vista calendario ──────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final byDate = _byDate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _monthHeader(),
        const SizedBox(height: 8),
        _weekdayLabels(),
        const SizedBox(height: 4),
        _monthGrid(byDate),
        const SizedBox(height: 12),
        _legend(),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          ),
          child: KeyedSubtree(
            key: ValueKey(
                _selectedDay == null ? 'none' : _key(_selectedDay!)),
            child: _selectedDayPanel(byDate),
          ),
        ),
        if (_loadingMore)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent))),
          ),
      ],
    );
  }

  Widget _monthHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        color: AppTheme.textSecondary,
        onPressed: () => _changeMonth(-1),
      ),
      Text('${_months[_visibleMonth.month]} ${_visibleMonth.year}',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded),
        color: AppTheme.textSecondary,
        // No dejamos avanzar a meses futuros.
        onPressed: _isCurrentMonth(_visibleMonth) ? null : () => _changeMonth(1),
      ),
    ],
  );

  bool _isCurrentMonth(DateTime m) {
    final n = DateTime.now();
    return m.year == n.year && m.month == n.month;
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = null;
    });
    await _ensureMonthLoaded(_visibleMonth);
  }

  Widget _weekdayLabels() => Row(
    children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
        .map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ))
        .toList(),
  );

  Widget _monthGrid(Map<String, List<FichajeRecord>> byDate) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = first.weekday - 1; // lunes = 0
    final cells = <Widget>[];
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      cells.add(_dayCell(d, byDate));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _dayCell(DateTime d, Map<String, List<FichajeRecord>> byDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = d == today;
    final isFuture = d.isAfter(today);
    final isSelected = _selectedDay != null &&
        _key(_selectedDay!) == _key(d);
    final recs = byDate[_key(d)];
    final has = recs != null && recs.isNotEmpty;
    final isLectivo = (_weekly?.days.containsKey(d.weekday) ?? false);
    final missing = !has && !isFuture && d != today && isLectivo;

    Color? dot;
    if (has) {
      final completo = recs.any((r) => r.isEntrada) &&
          recs.any((r) => !r.isEntrada);
      // Día a medias (solo una) → ámbar. Excepción: HOY con solo la entrada es
      // lo normal (jornada en curso), no un fallo, así que se queda en verde.
      dot = (completo || d == today) ? AppTheme.success : AppTheme.warning;
    } else if (missing) {
      // Lectivo y sin ningún fichaje → rojo (puede incluir festivos locales).
      dot = AppTheme.error;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = isSelected ? null : d),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppTheme.accent.withValues(alpha: 0.6))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 14,
                    color: isFuture
                        ? AppTheme.textSecondary.withValues(alpha: 0.4)
                        : AppTheme.textPrimary,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(height: 3),
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: dot ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _legendItem(AppTheme.success, 'Fichado'),
            _legendItem(AppTheme.warning, 'Incompleto'),
            _legendItem(AppTheme.error, 'Sin fichar'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
            'Incompleto = falta la entrada o la salida. '
            'El rojo puede incluir festivos o no lectivos.',
            style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 11)),
      ],
    ),
  );

  Widget _legendItem(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendDot(c),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      );

  Widget _legendDot(Color c) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _selectedDayPanel(Map<String, List<FichajeRecord>> byDate) {
    final d = _selectedDay;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Toca un día para ver sus fichajes.',
            style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 13)),
      );
    }
    final list = byDate[_key(d)] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_dayLabel(d),
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          _chip(Icons.do_not_disturb_on_outlined, 'Sin fichajes este día',
              AppTheme.textSecondary)
        else
          ...list.map(_fichajeRow),
      ],
    );
  }

  // ── Comunes ──────────────────────────────────────────────────────────────

  Widget _centered(IconData icon, String title, String subtitle) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 120),
      Icon(icon, size: 48,
          color: AppTheme.textSecondary.withValues(alpha: 0.4)),
      const SizedBox(height: 12),
      Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      const SizedBox(height: 4),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    ],
  );

  Widget _chip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(color: color, fontSize: 13)),
    ]),
  );

  // ── Formato ──────────────────────────────────────────────────────────────

  String _dayLabel(DateTime? d) {
    if (d == null) return 'Sin fecha';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'HOY';
    if (diff == 1) return 'AYER';
    return '${_weekdays[d.weekday]} ${d.day} ${_monthsAbbr[d.month]}'
        .toUpperCase();
  }

  String _hm(DateTime? d) {
    if (d == null) return '—';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
