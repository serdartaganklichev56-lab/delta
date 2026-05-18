import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilSahifasi extends StatelessWidget {
  const ProfilSahifasi({super.key});
  static const Color dark = Color(0xFF0f172a);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: dark,
        title: const Text("Profil", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('foydalanuvchilar').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          final ism = '${d['ism'] ?? ''} ${d['familya'] ?? ''}'.trim();
          final rol = d['rol'] as String? ?? 'talaba';
          final tarif = d['tarif'] as String?;
          final limit = d['daqiqaLimit'] as int? ?? 0;
          final ishlatilgan = d['daqiqaIshlatilgan'] as int? ?? 0;
          final qolgan = (limit - ishlatilgan).clamp(0, limit);
          final foiz = limit > 0 ? ishlatilgan / limit : 0.0;
          final initials = ism.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withAlpha(20),
                    child: Text(initials,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(ism, style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rol == 'ceo' ? '👑 CEO' : rol == 'ustoz' ? '👨‍🏫 Ustoz' : '👨‍🎓 Talaba',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Tarif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF0f172a)),
                    const SizedBox(width: 6),
                    const Text("Tarif", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    if (tarif != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAEEDA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tarif,
                            style: const TextStyle(color: Color(0xFF633806),
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  if (tarif == null)
                    const Text("Tarif tanlanmagan",
                        style: TextStyle(color: Colors.grey))
                  else ...[
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("$ishlatilgan/$limit daqiqa",
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: foiz.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            color: dark,
                            minHeight: 6,
                          ),
                        ),
                      ])),
                      const SizedBox(width: 12),
                      Text("$qolgan\nqoldi",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  const Text("Tariflar", style: TextStyle(fontWeight: FontWeight.w600,
                      fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...[
                    {'nom': "Boshlang'ich", 'min': '1 500 min/oy', 'narx': '150 000 so\'m', 'id': 'boshlangich'},
                    {'nom': "Pro", 'min': '3 000 min/oy', 'narx': '300 000 so\'m', 'id': 'pro'},
                    {'nom': "Ultra", 'min': '6 000 min/oy', 'narx': '600 000 so\'m', 'id': 'ultra'},
                  ].map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tarif == t['id'] ? dark.withAlpha(10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: tarif == t['id'] ? dark : Colors.grey.shade300,
                        width: tarif == t['id'] ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(t['nom']!, style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                          if (tarif == t['id']) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: dark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text("Joriy",
                                  style: TextStyle(color: Colors.white, fontSize: 9)),
                            ),
                          ],
                        ]),
                        Text(t['min']!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ])),
                      Text(t['narx']!, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  )),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
