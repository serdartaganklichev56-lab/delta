import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'guruh_chat.dart';
import 'stream_screen.dart';

class GuruhIchidaSahifasi extends StatefulWidget {
  final String guruhId;
  final String guruhNom;
  final bool menUstoz;
  const GuruhIchidaSahifasi({super.key,
      required this.guruhId, required this.guruhNom, required this.menUstoz});
  @override
  State<GuruhIchidaSahifasi> createState() => _GuruhIchidaSahifasiState();
}

class _GuruhIchidaSahifasiState extends State<GuruhIchidaSahifasi> {
  static const Color dark = Color(0xFF0f172a);
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _yangiKodYaratish() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = math.Random();
    final kod = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    final tugash = DateTime.now().add(const Duration(hours: 4));
    await FirebaseFirestore.instance
        .collection('guruhlar').doc(widget.guruhId).update({
      'kodlar': FieldValue.arrayUnion([kod]),
      'joriyKod': kod,
      'kodTugashVaqt': tugash.millisecondsSinceEpoch,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yangi kod: $kod (4 soat)"),
              backgroundColor: Colors.green));
    }
  }

  void _nusxalash(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nusxalandi!"),
            duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: dark,
        title: Text(widget.guruhNom,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('guruhlar').doc(widget.guruhId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          final azolar = (d['azolar'] as List? ?? []);
          final joriyKod = d['joriyKod'] as String? ?? '';
          final kodTugash = d['kodTugashVaqt'] as int? ?? 0;
          final kodAmal = kodTugash > DateTime.now().millisecondsSinceEpoch;
          final streamFaol = d['streamFaol'] as bool? ?? false;

          return Stack(children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Guruh nomi
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(children: [
                    Text(widget.guruhNom,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${azolar.length} a'zo",
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 12),

                // ID va Kod — faqat ustoz
                if (widget.menUstoz) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEEDA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF9F27)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.lock_outline, size: 14, color: Color(0xFF854F0B)),
                        const SizedBox(width: 4),
                        const Text("Faqat ustoz ko'radi",
                            style: TextStyle(fontSize: 11, color: Color(0xFF854F0B),
                                fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 10),

                      // Guruh ID
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Guruh ID", style: TextStyle(fontSize: 10, color: Color(0xFF854F0B))),
                          Text(widget.guruhId,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                                  color: Color(0xFF412402), letterSpacing: 1)),
                        ])),
                        GestureDetector(
                          onTap: () => _nusxalash(widget.guruhId),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF9F27),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.copy, size: 14, color: Color(0xFF412402)),
                          ),
                        ),
                      ]),
                      const Divider(color: Color(0xFFEF9F27), height: 16),

                      // Kirish kodi
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Kirish kodi", style: TextStyle(fontSize: 10, color: Color(0xFF854F0B))),
                          Text(
                            joriyKod.isEmpty ? "—" : (kodAmal ? joriyKod : "Muddati o'tgan"),
                            style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold,
                              color: kodAmal ? const Color(0xFF412402) : Colors.grey,
                              letterSpacing: 4,
                            ),
                          ),
                          if (joriyKod.isNotEmpty && kodAmal) ...[
                            const SizedBox(height: 2),
                            Text(
                              _qolganVaqt(kodTugash),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF854F0B)),
                            ),
                          ],
                        ])),
                        GestureDetector(
                          onTap: joriyKod.isNotEmpty && kodAmal
                              ? () => _nusxalash(joriyKod)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: joriyKod.isNotEmpty && kodAmal
                                  ? const Color(0xFFEF9F27)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.copy, size: 14, color: Color(0xFF412402)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF633806),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _yangiKodYaratish,
                          icon: const Icon(Icons.refresh, color: Color(0xFFFAEEDA), size: 16),
                          label: const Text("Yangi kod yaratish (4 soat)",
                              style: TextStyle(color: Color(0xFFFAEEDA), fontSize: 12)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Stream faol bo'lsa talabaga banner
                if (!widget.menUstoz && streamFaol) ...[
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StreamScreen(
                            guruhId: widget.guruhId,
                            guruhNom: widget.guruhNom))),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(60)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Jonli dars boshlandi!",
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: Colors.red, fontSize: 13)),
                            Text("Ustoz stream qilmoqda",
                                style: TextStyle(color: Colors.red, fontSize: 11)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("Kirish",
                              style: TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // A'zolar
                const Text("A'zolar",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),

                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('foydalanuvchilar')
                      .where(FieldPath.documentId, whereIn: azolar.isEmpty ? ['_'] : azolar)
                      .get(),
                  builder: (context, aSnap) {
                    if (!aSnap.hasData) return const Center(child: CircularProgressIndicator());
                    final azolarList = aSnap.data!.docs;
                    return Column(
                      children: azolarList.map((doc) {
                        final ad = doc.data() as Map<String, dynamic>;
                        final ism = '${ad['ism'] ?? ''} ${ad['familya'] ?? ''}'.trim();
                        final rol = ad['rol'] as String? ?? 'talaba';
                        final initials = ism.isNotEmpty
                            ? ism.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
                            : '?';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: dark.withAlpha(20),
                              child: Text(initials,
                                  style: const TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.bold, color: dark)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ism, style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                                Text(rol == 'ustoz' ? 'Ustoz' : 'Talaba',
                                    style: TextStyle(fontSize: 11,
                                        color: rol == 'ustoz'
                                            ? Colors.green : Colors.grey)),
                              ],
                            )),
                          ]),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 80),

                // Chat tugmasi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: dark,
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GuruhChatSahifasi(
                            guruhId: widget.guruhId, guruhNom: widget.guruhNom))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("Guruh chati"),
                  ),
                ),
              ]),
            ),

            // Floating stream tugmasi — faqat ustoz
            if (widget.menUstoz)
              Positioned(
                right: 16,
                bottom: 16,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StreamScreen(
                            guruhId: widget.guruhId,
                            guruhNom: widget.guruhNom))),
                    child: const Icon(Icons.videocam, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text("Stream",
                      style: TextStyle(fontSize: 10, color: Colors.red,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
          ]);
        },
      ),
    );
  }

  String _qolganVaqt(int tugashMs) {
    final qolgan = DateTime.fromMillisecondsSinceEpoch(tugashMs)
        .difference(DateTime.now());
    if (qolgan.isNegative) return "Muddati o'tgan";
    final soat = qolgan.inHours;
    final daqiqa = qolgan.inMinutes % 60;
    return "$soat soat $daqiqa daqiqa qoldi";
  }
}
