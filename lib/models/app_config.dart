/// Configuración persistente de la app (almacenada en SharedPreferences).
class AppConfig {
  final String twoFactorAuthToken; // Token de dispositivo de confianza
  final String username;
  final int centerId;
  final String codeProfile;

  final bool autoFichajeEnabled; // Interruptor global
  final bool fichaEntrada;
  final bool fichaSalida;

  // Márgenes en minutos antes/después de la hora exacta
  final int marginEntradaMinutes;
  final int marginSalidaMinutes;

  // Periodo no lectivo: cuando está activo, ignora el horario importado y
  // ficha de [nonLectivoStart] a [nonLectivoEnd] de lunes a viernes.
  // Típico de comienzos de septiembre y finales de junio (9:00–14:00).
  final bool nonLectivoEnabled;
  final String nonLectivoStart; // "09:00"
  final String nonLectivoEnd;   // "14:00"

  const AppConfig({
    required this.twoFactorAuthToken,
    required this.username,
    this.centerId = 344,
    this.codeProfile = 'P',
    this.autoFichajeEnabled = true,
    this.fichaEntrada = true,
    this.fichaSalida = true,
    this.marginEntradaMinutes = 10,
    this.marginSalidaMinutes = 10,
    this.nonLectivoEnabled = false,
    this.nonLectivoStart = '09:00',
    this.nonLectivoEnd = '14:00',
  });

  AppConfig copyWith({
    String? twoFactorAuthToken,
    String? username,
    int? centerId,
    String? codeProfile,
    bool? autoFichajeEnabled,
    bool? fichaEntrada,
    bool? fichaSalida,
    int? marginEntradaMinutes,
    int? marginSalidaMinutes,
    bool? nonLectivoEnabled,
    String? nonLectivoStart,
    String? nonLectivoEnd,
  }) {
    return AppConfig(
      twoFactorAuthToken: twoFactorAuthToken ?? this.twoFactorAuthToken,
      username: username ?? this.username,
      centerId: centerId ?? this.centerId,
      codeProfile: codeProfile ?? this.codeProfile,
      autoFichajeEnabled: autoFichajeEnabled ?? this.autoFichajeEnabled,
      fichaEntrada: fichaEntrada ?? this.fichaEntrada,
      fichaSalida: fichaSalida ?? this.fichaSalida,
      marginEntradaMinutes: marginEntradaMinutes ?? this.marginEntradaMinutes,
      marginSalidaMinutes: marginSalidaMinutes ?? this.marginSalidaMinutes,
      nonLectivoEnabled: nonLectivoEnabled ?? this.nonLectivoEnabled,
      nonLectivoStart: nonLectivoStart ?? this.nonLectivoStart,
      nonLectivoEnd: nonLectivoEnd ?? this.nonLectivoEnd,
    );
  }
}
