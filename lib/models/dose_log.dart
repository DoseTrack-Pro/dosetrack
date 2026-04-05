enum LogMethod { nfc, manual }

class DoseLog {
  final String id;
  final String deviceId;
  final DateTime loggedAt;
  final LogMethod method;
  final double doseMcg;
  final double doseIu;
  final String? notes;

  const DoseLog({
    required this.id,
    required this.deviceId,
    required this.loggedAt,
    required this.method,
    required this.doseMcg,
    required this.doseIu,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'device_id': deviceId,
    'logged_at': loggedAt.toIso8601String(),
    'method': method.name,
    'dose_mcg': doseMcg,
    'dose_iu': doseIu,
    'notes': notes,
  };

  factory DoseLog.fromMap(Map<String, dynamic> m) => DoseLog(
    id: m['id'] as String,
    deviceId: m['device_id'] as String,
    loggedAt: DateTime.parse(m['logged_at'] as String),
    method: LogMethod.values.firstWhere((v) => v.name == m['method']),
    doseMcg: (m['dose_mcg'] as num).toDouble(),
    doseIu: (m['dose_iu'] as num).toDouble(),
    notes: m['notes'] as String?,
  );
}
