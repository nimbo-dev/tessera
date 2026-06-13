/// Una franja horaria del horario de Séneca.
class ScheduleEntry {
  final String subject;
  final String units;
  final String initHour; // "8:00"
  final String endHour;  // "9:00"
  final bool isGuard;

  const ScheduleEntry({
    required this.subject,
    required this.units,
    required this.initHour,
    required this.endHour,
    this.isGuard = false,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      subject: json['subject'] ?? '',
      units: json['units'] ?? '',
      initHour: json['initHour'] ?? '',
      endHour: json['endHour'] ?? '',
      isGuard: json['guard'] ?? false,
    );
  }

  /// Convierte "8:00" a TimeOfDay equivalente en minutos desde medianoche.
  int get initMinutes => _toMinutes(initHour);
  int get endMinutes  => _toMinutes(endHour);

  static int _toMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

/// Resumen del día: primera entrada y última salida.
class DayScheduleSummary {
  final DateTime date;
  final String firstIn;  // "8:00"
  final String lastOut;  // "13:30"
  final List<ScheduleEntry> entries;

  const DayScheduleSummary({
    required this.date,
    required this.firstIn,
    required this.lastOut,
    required this.entries,
  });

  static DayScheduleSummary? fromEntries(
      DateTime date, List<ScheduleEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<ScheduleEntry>.from(entries)
      ..sort((a, b) => a.initMinutes.compareTo(b.initMinutes));
    return DayScheduleSummary(
      date: date,
      firstIn: sorted.first.initHour,
      lastOut: sorted.last.endHour,
      entries: sorted,
    );
  }
}
