/// Una notificación push de alerta que manda el motor del backend.
///
/// El backend la manda con bloque `notification` (título y texto, para que
/// Android la muestre sola con la app cerrada) y bloque `data` con los ids
/// para abrir la bandeja: `greenhouseId`, `alertId`, `zoneId`, `variable` y
/// `severity` (`warn` | `critical`).
class PushAlert {
  final String? greenhouseId;
  final String? alertId;
  final String? zoneId;
  final String? variable;
  final String severity;
  final String title;
  final String body;

  const PushAlert({
    this.greenhouseId,
    this.alertId,
    this.zoneId,
    this.variable,
    this.severity = 'critical',
    required this.title,
    required this.body,
  });

  bool get critica => severity == 'critical';

  /// Adapter del mensaje de FCM (`data` + `notification`) al modelo.
  factory PushAlert.fromMessage(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    String? texto(String k) {
      final v = data[k];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final severity = texto('severity') ?? 'critical';
    return PushAlert(
      greenhouseId: texto('greenhouseId'),
      alertId: texto('alertId'),
      zoneId: texto('zoneId'),
      variable: texto('variable'),
      severity: severity,
      title: (title?.trim().isNotEmpty ?? false)
          ? title!.trim()
          : (texto('title') ??
              (severity == 'critical'
                  ? '⚠️ Alerta crítica de cultivo'
                  : 'Atención en tu cultivo')),
      body: (body?.trim().isNotEmpty ?? false)
          ? body!.trim()
          : (texto('message') ??
              texto('body') ??
              'Revisa la bandeja de alertas'),
    );
  }

  /// Id estable para no repetir la notificación local de la misma alerta.
  int get notificationId =>
      (alertId ?? '$greenhouseId/$zoneId/$variable').hashCode;
}
