class Protocol {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;

  const Protocol({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.notes,
  });

  int get dayNumber => DateTime.now().difference(startDate).inDays + 1;
  int? get totalDays => endDate != null ? endDate!.difference(startDate).inDays + 1 : null;
  bool get isActive => endDate == null || endDate!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
  };

  factory Protocol.fromMap(Map<String, dynamic> m) => Protocol(
    id: m['id'] as String,
    name: m['name'] as String,
    startDate: DateTime.parse(m['start_date'] as String),
    endDate: m['end_date'] != null ? DateTime.parse(m['end_date'] as String) : null,
    notes: m['notes'] as String?,
  );

  Protocol copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? notes,
    bool clearNotes = false,
  }) => Protocol(
    id: id ?? this.id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    notes: clearNotes ? null : (notes ?? this.notes),
  );
}
