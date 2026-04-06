enum ContainerType { pen, vial }

enum DoseSchedule {
  dailyAm,
  dailyPm,
  everyOtherDay,
  twiceWeekly,
  onceWeekly,
  custom,
}

extension DoseScheduleLabel on DoseSchedule {
  String get label {
    switch (this) {
      case DoseSchedule.dailyAm:      return 'Daily AM';
      case DoseSchedule.dailyPm:      return 'Daily PM';
      case DoseSchedule.everyOtherDay: return 'Every Other Day';
      case DoseSchedule.twiceWeekly:  return 'Twice a Week';
      case DoseSchedule.onceWeekly:   return 'Once a Week';
      case DoseSchedule.custom:       return 'Custom Days';
    }
  }

  String get value {
    switch (this) {
      case DoseSchedule.dailyAm:       return 'daily_am';
      case DoseSchedule.dailyPm:       return 'daily_pm';
      case DoseSchedule.everyOtherDay: return 'every_other_day';
      case DoseSchedule.twiceWeekly:   return 'twice_weekly';
      case DoseSchedule.onceWeekly:    return 'once_weekly';
      case DoseSchedule.custom:        return 'custom';
    }
  }

  static DoseSchedule fromValue(String v) {
    return DoseSchedule.values.firstWhere(
      (s) => s.value == v,
      orElse: () => DoseSchedule.dailyAm,
    );
  }
}

class Device {
  final String id;
  final String name;
  final ContainerType type;
  final String vendor;
  final String batchNumber;
  final String? coaUrl;
  final String reconstitutionDate;
  final double peptideMg;
  final double reconVolumeMl;
  final double desiredDoseMcg;
  final double doseVolumeIu;
  final int totalDoses;
  final int remainingDoses;
  final DoseSchedule schedule;
  /// Specific weekdays for twiceWeekly, onceWeekly, or custom schedules.
  /// Integers 1–7 where 1 = Monday, 7 = Sunday (Dart's DateTime.weekday).
  final List<int>? scheduleDays;
  final String? nfcTagId;
  final int alertThresholdPct;
  final String? notificationId;
  final bool active;
  final DateTime createdAt;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.vendor,
    required this.batchNumber,
    this.coaUrl,
    required this.reconstitutionDate,
    required this.peptideMg,
    required this.reconVolumeMl,
    required this.desiredDoseMcg,
    required this.doseVolumeIu,
    required this.totalDoses,
    required this.remainingDoses,
    required this.schedule,
    this.scheduleDays,
    this.nfcTagId,
    required this.alertThresholdPct,
    this.notificationId,
    required this.active,
    required this.createdAt,
  });

  double get remainingPct => totalDoses > 0 ? remainingDoses / totalDoses : 0.0;

  Device copyWith({
    String? id, String? name, ContainerType? type, String? vendor,
    String? batchNumber, String? coaUrl, String? reconstitutionDate,
    double? peptideMg, double? reconVolumeMl, double? desiredDoseMcg,
    double? doseVolumeIu, int? totalDoses, int? remainingDoses,
    DoseSchedule? schedule, List<int>? scheduleDays, bool clearScheduleDays = false,
    String? nfcTagId, int? alertThresholdPct,
    String? notificationId, bool? active, DateTime? createdAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      vendor: vendor ?? this.vendor,
      batchNumber: batchNumber ?? this.batchNumber,
      coaUrl: coaUrl ?? this.coaUrl,
      reconstitutionDate: reconstitutionDate ?? this.reconstitutionDate,
      peptideMg: peptideMg ?? this.peptideMg,
      reconVolumeMl: reconVolumeMl ?? this.reconVolumeMl,
      desiredDoseMcg: desiredDoseMcg ?? this.desiredDoseMcg,
      doseVolumeIu: doseVolumeIu ?? this.doseVolumeIu,
      totalDoses: totalDoses ?? this.totalDoses,
      remainingDoses: remainingDoses ?? this.remainingDoses,
      schedule: schedule ?? this.schedule,
      scheduleDays: clearScheduleDays ? null : (scheduleDays ?? this.scheduleDays),
      nfcTagId: nfcTagId ?? this.nfcTagId,
      alertThresholdPct: alertThresholdPct ?? this.alertThresholdPct,
      notificationId: notificationId ?? this.notificationId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'vendor': vendor,
    'batch_number': batchNumber,
    'coa_url': coaUrl,
    'reconstitution_date': reconstitutionDate,
    'peptide_mg': peptideMg,
    'recon_volume_ml': reconVolumeMl,
    'desired_dose_mcg': desiredDoseMcg,
    'dose_volume_iu': doseVolumeIu,
    'total_doses': totalDoses,
    'remaining_doses': remainingDoses,
    'schedule': schedule.value,
    'schedule_days': scheduleDays?.join(','),
    'nfc_tag_id': nfcTagId,
    'alert_threshold_pct': alertThresholdPct,
    'notification_id': notificationId,
    'active': active ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory Device.fromMap(Map<String, dynamic> m) => Device(
    id: m['id'] as String,
    name: m['name'] as String,
    type: ContainerType.values.firstWhere((t) => t.name == m['type']),
    vendor: m['vendor'] as String,
    batchNumber: m['batch_number'] as String,
    coaUrl: m['coa_url'] as String?,
    reconstitutionDate: m['reconstitution_date'] as String,
    peptideMg: (m['peptide_mg'] as num).toDouble(),
    reconVolumeMl: (m['recon_volume_ml'] as num).toDouble(),
    desiredDoseMcg: (m['desired_dose_mcg'] as num).toDouble(),
    doseVolumeIu: (m['dose_volume_iu'] as num).toDouble(),
    totalDoses: m['total_doses'] as int,
    remainingDoses: m['remaining_doses'] as int,
    schedule: DoseScheduleLabel.fromValue(m['schedule'] as String),
    scheduleDays: (m['schedule_days'] as String?)
        ?.split(',')
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toList(),
    nfcTagId: m['nfc_tag_id'] as String?,
    alertThresholdPct: m['alert_threshold_pct'] as int,
    notificationId: m['notification_id'] as String?,
    active: (m['active'] as int) == 1,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
