import 'dart:convert';

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
      case DoseSchedule.dailyAm:
        return 'Daily AM';
      case DoseSchedule.dailyPm:
        return 'Daily PM';
      case DoseSchedule.everyOtherDay:
        return 'Every Other Day';
      case DoseSchedule.twiceWeekly:
        return 'Twice a Week';
      case DoseSchedule.onceWeekly:
        return 'Once a Week';
      case DoseSchedule.custom:
        return 'Custom Days';
    }
  }

  String get value {
    switch (this) {
      case DoseSchedule.dailyAm:
        return 'daily_am';
      case DoseSchedule.dailyPm:
        return 'daily_pm';
      case DoseSchedule.everyOtherDay:
        return 'every_other_day';
      case DoseSchedule.twiceWeekly:
        return 'twice_weekly';
      case DoseSchedule.onceWeekly:
        return 'once_weekly';
      case DoseSchedule.custom:
        return 'custom';
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

  /// Days after reconstitution before the compound expires. Default 30.
  final int expiryDays;
  final String? scheduleStartDate;
  final bool isBlend;
  final List<BlendComponent>? blendComponents;
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
    this.expiryDays = 30,
    this.scheduleStartDate,
    this.isBlend = false,
    this.blendComponents,
    this.nfcTagId,
    required this.alertThresholdPct,
    this.notificationId,
    required this.active,
    required this.createdAt,
  });

  double get remainingPct => totalDoses > 0 ? remainingDoses / totalDoses : 0.0;

  Device copyWith({
    String? id,
    String? name,
    ContainerType? type,
    String? vendor,
    String? batchNumber,
    String? coaUrl,
    String? reconstitutionDate,
    double? peptideMg,
    double? reconVolumeMl,
    double? desiredDoseMcg,
    double? doseVolumeIu,
    int? totalDoses,
    int? remainingDoses,
    DoseSchedule? schedule,
    List<int>? scheduleDays,
    bool clearScheduleDays = false,
    int? expiryDays,
    String? scheduleStartDate,
    bool clearScheduleStartDate = false,
    bool? isBlend,
    List<BlendComponent>? blendComponents,
    bool clearBlendComponents = false,
    String? nfcTagId,
    int? alertThresholdPct,
    String? notificationId,
    bool clearNotificationId = false,
    bool? active,
    DateTime? createdAt,
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
      scheduleDays:
          clearScheduleDays ? null : (scheduleDays ?? this.scheduleDays),
      expiryDays: expiryDays ?? this.expiryDays,
      scheduleStartDate: clearScheduleStartDate
          ? null
          : (scheduleStartDate ?? this.scheduleStartDate),
      isBlend: isBlend ?? this.isBlend,
      blendComponents: clearBlendComponents
          ? null
          : (blendComponents ?? this.blendComponents),
      nfcTagId: nfcTagId ?? this.nfcTagId,
      alertThresholdPct: alertThresholdPct ?? this.alertThresholdPct,
      notificationId:
          clearNotificationId ? null : (notificationId ?? this.notificationId),
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
        'expiry_days': expiryDays,
        'schedule_start_date': scheduleStartDate,
        'is_blend': isBlend ? 1 : 0,
        'blend_components_json': blendComponents != null
            ? jsonEncode(blendComponents!.map((c) => c.toMap()).toList())
            : null,
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
        expiryDays: (m['expiry_days'] as int?) ?? 30,
        scheduleStartDate: m['schedule_start_date'] as String?,
        isBlend: (m['is_blend'] as int?) == 1,
        blendComponents: _parseBlendComponents(m['blend_components_json']),
        nfcTagId: m['nfc_tag_id'] as String?,
        alertThresholdPct: m['alert_threshold_pct'] as int,
        notificationId: m['notification_id'] as String?,
        active: (m['active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static List<BlendComponent>? _parseBlendComponents(dynamic raw) {
    if (raw == null) return null;
    final text = raw as String;
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return null;
      final components = decoded
          .whereType<Map<String, dynamic>>()
          .map(BlendComponent.fromMap)
          .toList();
      return components.isEmpty ? null : components;
    } catch (_) {
      return null;
    }
  }
}

class BlendComponent {
  final String name;
  final double mg;

  const BlendComponent({required this.name, required this.mg});

  Map<String, dynamic> toMap() => {
        'name': name,
        'mg': mg,
      };

  factory BlendComponent.fromMap(Map<String, dynamic> map) => BlendComponent(
        name: (map['name'] as String? ?? '').trim(),
        mg: (map['mg'] as num?)?.toDouble() ?? 0,
      );
}
