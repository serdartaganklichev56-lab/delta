class RoomModel {
  final String id;
  final String name;
  final String domlaId;
  final String domlaName;
  final String code;
  final DateTime codeExpires;
  final bool isActive;
  final int memberCount;
  final List<String> azolar;
  final bool streamFaol;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.name,
    required this.domlaId,
    this.domlaName = '',
    required this.code,
    required this.codeExpires,
    this.isActive = true,
    this.memberCount = 0,
    this.azolar = const [],
    this.streamFaol = false,
    required this.createdAt,
  });

  bool get isCodeValid => codeExpires.isAfter(DateTime.now());

  factory RoomModel.fromMap(String id, Map<String, dynamic> map) {
    // joriyKod va kodTugashVaqt (delta_2 format) ham qabul qilamiz
    final code = map['joriyKod'] ?? map['code'] ?? '';
    final codeExpMs = map['kodTugashVaqt'] ?? map['code_expires'] ?? 0;

    return RoomModel(
      id: id,
      name: map['nom'] ?? map['name'] ?? '',
      domlaId: map['ustozId'] ?? map['domla_id'] ?? '',
      domlaName: map['domla_name'] ?? '',
      code: code,
      codeExpires: DateTime.fromMillisecondsSinceEpoch(codeExpMs),
      isActive: map['is_active'] ?? true,
      memberCount: (map['azolar'] as List? ?? []).length,
      azolar: List<String>.from(map['azolar'] ?? []),
      streamFaol: map['streamFaol'] ?? false,
      createdAt: map['yaratilgan'] != null
          ? (map['yaratilgan'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['yaratilgan'])
              : DateTime.now())
          : DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': name,
      'name': name,
      'ustozId': domlaId,
      'domla_id': domlaId,
      'domla_name': domlaName,
      'joriyKod': code,
      'code': code,
      'kodTugashVaqt': codeExpires.millisecondsSinceEpoch,
      'code_expires': codeExpires.millisecondsSinceEpoch,
      'is_active': isActive,
      'azolar': azolar,
      'streamFaol': streamFaol,
    };
  }
}
