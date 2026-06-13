import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule_entry.dart';

const _base = 'https://seneca.juntadeandalucia.es/api/public/';
const _ua   = 'iSeneca/12.4.1 Android';

class SenecaApi {
  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Paso 1: solicitar código SMS. Devuelve el twoFactorAuthToken del servidor
  /// o lanza [Needs2FAException] si ya requiere código.
  static Future<LoginStep1Result> loginStep1(
      String username, String password) async {
    final resp = await http.post(
      Uri.parse('${_base}security/oauth/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': _ua,
      },
      body: {
        'username': username,
        'password': password,
        'grant_type': 'password',
        'scope': 'SENECADROID',
        'client_id': 'iseneca',
      },
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode == 200) {
      return LoginStep1Result(
        needsSms: false,
        accessToken: body['access_token'] as String?,
        twoFactorAuthToken: null,
        sendTo: null,
      );
    } else if (resp.statusCode == 412) {
      final data = body['data'] as Map<String, dynamic>;
      return LoginStep1Result(
        needsSms: true,
        accessToken: null,
        twoFactorAuthToken: data['2FactorAuthToken'] as String,
        sendTo: data['sendTo'] as String?,
      );
    } else {
      throw SenecaApiException('Login fallido (${resp.statusCode}): ${body['message']}');
    }
  }

  /// Paso 2: login con código SMS. Devuelve accessToken y el nuevo
  /// twoFactorAuthToken persistente (trustDevice).
  static Future<LoginStep2Result> loginStep2({
    required String username,
    required String password,
    required String twoFactorAuthToken,
    required String smsCode,
  }) async {
    final resp = await http.post(
      Uri.parse('${_base}security/oauth/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': _ua,
      },
      body: {
        'username': username,
        'password': password,
        'grant_type': 'password',
        'scope': 'SENECADROID',
        'client_id': 'iseneca',
        '2FactorAuthToken': twoFactorAuthToken,
        '2FactorAuthCode': smsCode,
        'trustDevice': 'true',
      },
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw SenecaApiException('2FA fallido (${resp.statusCode}): ${body['message']}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return LoginStep2Result(
      accessToken: body['access_token'] as String,
      persistentToken: body['2FactorAuthToken'] as String?,
    );
  }

  /// Login silencioso usando el token persistente (sin SMS).
  static Future<String> silentLogin({
    required String username,
    required String password,
    required String persistentToken,
    int centerId = 344,
    String codeProfile = 'P',
  }) async {
    final resp = await http.post(
      Uri.parse('${_base}security/oauth/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': _ua,
      },
      body: {
        'username': username,
        'password': password,
        'grant_type': 'password',
        'scope': 'SENECADROID',
        'client_id': 'iseneca',
        '2FactorAuthToken': persistentToken,
        'trustDevice': 'true',
      },
    );

    if (resp.statusCode != 200) {
      throw SenecaApiException('Login silencioso fallido (${resp.statusCode})');
    }

    final token = (jsonDecode(resp.body) as Map<String, dynamic>)['access_token'] as String;
    await _setCentro(token, centerId, codeProfile);
    return token;
  }

  // ── Session ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getInfoSession(String token) async {
    final resp = await http.get(
      Uri.parse('${_base}generales/info-session-seneca'),
      headers: {'Authorization': 'Bearer $token', 'User-Agent': _ua},
    );
    _checkOk(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  static Future<void> _setCentro(
      String token, int centerId, String codeProfile) async {
    final resp = await http.post(
      Uri.parse('${_base}generales/set-centro'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'User-Agent': _ua,
      },
      body: jsonEncode({'centerId': centerId, 'codeProfile': codeProfile}),
    );
    _checkOk(resp);
  }

  // ── Horario ───────────────────────────────────────────────────────────────

  /// Devuelve las clases del día. date en formato YYYY-MM-DD.
  static Future<List<ScheduleEntry>> getSchedule(
      String token, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final resp = await http.get(
      Uri.parse('${_base}seguimiento/horario?date=$dateStr'),
      headers: {'Authorization': 'Bearer $token', 'User-Agent': _ua},
    );
    _checkOk(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Fichaje ───────────────────────────────────────────────────────────────

  static Future<String> getAccessPointKey(String token) async {
    final resp = await http.get(
      Uri.parse('${_base}horarios/obtencion-puntos-acceso'),
      headers: {'Authorization': 'Bearer $token', 'User-Agent': _ua},
    );
    _checkOk(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final points = body['data'] as List<dynamic>;
    if (points.isEmpty) throw SenecaApiException('No hay puntos de acceso GPS.');
    return (points.first as Map<String, dynamic>)['key'] as String;
  }

  /// type: 'E' (entrada) | 'S' (salida)
  static Future<void> registrarPresencia(
      String token, String key, String type) async {
    final resp = await http.post(
      Uri.parse('${_base}horarios/registrar-control-presencia'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'User-Agent': _ua,
      },
      body: jsonEncode({
        'key': key,
        'type': type,
        'mode': 'GEO',
        'tokenQr': '',
      }),
    );
    _checkOk(resp);
  }

  // ── Historial de fichajes ─────────────────────────────────────────────────

  /// Historial de control de presencia (paginado). page suele ser 1-indexado.
  static Future<List<FichajeRecord>> getHistorial(String token,
      {int page = 1}) async {
    final resp = await http.get(
      Uri.parse('${_base}horarios/registro-acceso?page=$page'),
      headers: {'Authorization': 'Bearer $token', 'User-Agent': _ua},
    );
    _checkOk(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    final list = data is List
        ? data
        : (data is Map ? (data['content'] as List? ?? const []) : const []);
    return list
        .map((e) => FichajeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static void _checkOk(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw SenecaApiException(
        'HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}',
        statusCode: resp.statusCode,
      );
    }
  }
}

// ── Result types ─────────────────────────────────────────────────────────────

class LoginStep1Result {
  final bool needsSms;
  final String? accessToken;
  final String? twoFactorAuthToken;
  final String? sendTo;

  const LoginStep1Result({
    required this.needsSms,
    this.accessToken,
    this.twoFactorAuthToken,
    this.sendTo,
  });
}

class LoginStep2Result {
  final String accessToken;
  final String? persistentToken;

  const LoginStep2Result({
    required this.accessToken,
    this.persistentToken,
  });
}

/// Un registro del historial de control de presencia de Séneca.
class FichajeRecord {
  final String registryId;
  final DateTime? date;
  final String type; // 'E' (entrada) | 'S' (salida)
  final String mode; // 'GEO' | 'QR' …

  const FichajeRecord({
    required this.registryId,
    required this.date,
    required this.type,
    required this.mode,
  });

  bool get isEntrada => type == 'E';

  factory FichajeRecord.fromJson(Map<String, dynamic> j) => FichajeRecord(
        registryId: '${j['registryId'] ?? ''}',
        date: _parseDate(j['date']?.toString()),
        type: (j['type'] ?? '').toString(),
        mode: (j['mode'] ?? '').toString(),
      );

  /// Parseo defensivo: admite ISO y "dd/MM/yyyy[ HH:mm[:ss]]" o con guiones.
  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:[ T](\d{1,2}):(\d{2}))?')
        .firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!),
        int.tryParse(m[4] ?? '0') ?? 0, int.tryParse(m[5] ?? '0') ?? 0,
      );
    }
    return null;
  }
}

class SenecaApiException implements Exception {
  final String message;
  final int? statusCode;
  const SenecaApiException(this.message, {this.statusCode});

  @override
  String toString() => 'SenecaApiException: $message';
}
