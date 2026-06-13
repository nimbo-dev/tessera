import 'dart:convert';

/// Entrada de un día de la semana con primera y última hora de clase.
class DayEntry {
  final String firstIn;  // "08:00"
  final String lastOut;  // "14:00"

  const DayEntry({required this.firstIn, required this.lastOut});

  Map<String, dynamic> toJson() => {'firstIn': firstIn, 'lastOut': lastOut};

  factory DayEntry.fromJson(Map<String, dynamic> j) =>
      DayEntry(firstIn: j['firstIn'] as String, lastOut: j['lastOut'] as String);
}

/// Horario semanal importado de Séneca (lunes=1 ... viernes=5).
class WeeklySchedule {
  final Map<int, DayEntry> days;
  final DateTime importedAt;

  const WeeklySchedule({required this.days, required this.importedAt});

  bool hasClassOn(int weekday) => days.containsKey(weekday);
  DayEntry? getDay(int weekday) => days[weekday];

  bool get isEmpty => days.isEmpty;

  Map<String, dynamic> toJson() => {
    'importedAt': importedAt.toIso8601String(),
    'days': days.map((k, v) => MapEntry(k.toString(), v.toJson())),
  };

  factory WeeklySchedule.fromJson(Map<String, dynamic> j) => WeeklySchedule(
    importedAt: DateTime.parse(j['importedAt'] as String),
    days: (j['days'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), DayEntry.fromJson(v as Map<String, dynamic>)),
    ),
  );

  String toJsonString() => jsonEncode(toJson());
  factory WeeklySchedule.fromJsonString(String s) =>
      WeeklySchedule.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
