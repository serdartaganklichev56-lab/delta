class UserModel {
  final String uid;
  final String name;
  final String familya;
  final String phone;
  final String email;
  final String role;
  final int minutesLeft;
  final int extraMinutes;
  final String? tarifDaqiqa;   // '1500' | '3000' | '6000' | null
  final int? tarifIshtirokchi; // 50 | 100 | 150 | null
  final DateTime createdAt;

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
  });

  bool get isDomla => role == 'domla';
  bool get isTalaba => role == 'talaba';
  bool get isCeo => role == 'ceo';
  bool get hasTarif => tarifDaqiqa != null && tarifIshtirokchi != null;
  String get fullName => familya.isNotEmpty ? '$name $familya' : name;

  int get tarifLimit => int.tryParse(tarifDaqiqa ?? '0') ?? 0;
  int get jami => minutesLeft + extraMinutes;

  // Qo'shimcha daqiqa sotib olish mumkin bo'lgan max miqdor
  int get maxExtraBuyable {
    final qolgan = extraMinutes;
    return (2000 - qolgan).clamp(0, 2000);
  }

  // Tarif narxi (so'm)
  static int tarifNarxi(String daqiqa, int ishtirokchi) {
    final d = int.tryParse(daqiqa) ?? 0;
    if (d == 1500) {
      if (ishtirokchi == 50) return 150000;
      if (ishtirokchi == 100) return 300000;
      if (ishtirokchi == 150) return 500000;
    } else if (d == 3000) {
      if (ishtirokchi == 50) return 300000;
      if (ishtirokchi == 100) return 600000;
      if (ishtirokchi == 150) return 1000000;
    } else if (d == 6000) {
      if (ishtirokchi == 50) return 500000;
      if (ishtirokchi == 100) return 1000000;
      if (ishtirokchi == 150) return 1500000;
    }
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
      minutesLeft: map['minutesLeft'] ?? map['minutes_left'] ?? map['daqiqaLimit'] ?? 0,
      extraMinutes: map['extraMinutes'] ?? 0,
      tarifDaqiqa: map['tarifDaqiqa'],
      tarifIshtirokchi: map['tarifIshtirokchi'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
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
    };
  }
}
