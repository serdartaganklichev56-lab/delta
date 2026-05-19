class UserModel {
  final String uid;
  final String name;
  final String familya;
  final String phone;
  final String email;
  final String role;
  final int minutesLeft;
  final int extraMinutes;
  final String? tarifDaqiqa;
  final int? tarifIshtirokchi;
  final DateTime createdAt;
  final String? telegramChatId;
  final DateTime? tarifTugash; // 30 kun

  UserModel({
    required this.uid,
    required this.name,
    this.familya = '',
    this.phone = '',
    this.email = '',
    required this.role,
    this.minutesLeft = 0,
    this.extraMinutes = 0,
    this.tarifDaqiqa,
    this.tarifIshtirokchi,
    required this.createdAt,
    this.telegramChatId,
    this.tarifTugash,
  });

  bool get isDomla => role == 'domla';
  bool get isTalaba => role == 'talaba';
  bool get isCeo => role == 'ceo';
  bool get hasTarif => tarifDaqiqa != null && tarifIshtirokchi != null;
  bool get tarifFaol => tarifTugash != null && tarifTugash!.isAfter(DateTime.now());
  String get fullName => familya.isNotEmpty ? '$name $familya' : name;
  int get tarifLimit => int.tryParse(tarifDaqiqa ?? '0') ?? 0;
  int get jami => minutesLeft + extraMinutes;

  int get maxExtraBuyable {
    return (2000 - extraMinutes).clamp(0, 2000);
  }

  // Faqat 3 ta tarif, ishtirokchi har doim 60
  static int tarifNarxi(String daqiqa, int ishtirokchi) {
    final d = int.tryParse(daqiqa) ?? 0;
    if (d == 1500) return 150000;
    if (d == 3000) return 300000;
    if (d == 6000) return 600000;
    return 0;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? map['id'] ?? '',
      name: map['name'] ?? map['ism'] ?? '',
      familya: map['familya'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? map['rol'] ?? 'talaba',
      minutesLeft: map['minutesLeft'] ?? map['minutes_left'] ?? 0,
      extraMinutes: map['extraMinutes'] ?? 0,
      tarifDaqiqa: map['tarifDaqiqa'],
      tarifIshtirokchi: map['tarifIshtirokchi'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      telegramChatId: map['telegramChatId'],
      tarifTugash: map['tarifTugash'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['tarifTugash'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'familya': familya,
      'ism': name,
      'phone': phone,
      'email': email,
      'role': role,
      'rol': role,
      'minutesLeft': minutesLeft,
      'extraMinutes': extraMinutes,
      'tarifDaqiqa': tarifDaqiqa,
      'tarifIshtirokchi': tarifIshtirokchi,
      'created_at': createdAt.millisecondsSinceEpoch,
      'telegramChatId': telegramChatId,
      'tarifTugash': tarifTugash?.millisecondsSinceEpoch,
    };
  }
}
