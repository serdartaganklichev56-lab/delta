import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../../services/room_service.dart';
import '../stream/stream_screen.dart';
import 'guruh_chat_screen.dart';

class GuruhIchidaScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  final bool menUstoz;
  const GuruhIchidaScreen({
    super.key,
    required this.room,
    required this.user,
    required this.menUstoz,
  });

  @override
  State<GuruhIchidaScreen> createState() => _GuruhIchidaScreenState();
}

class _GuruhIchidaScreenState extends State<GuruhIchidaScreen> {
  final _roomService = RoomService();

  Future<void> _talabaniChiqarish(String uid, String ism) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Talabani chiqarish"),
        content: Text("'$ism' ni guruhdan chiqarmoqchimisiz?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Bekor")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Chiqar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('guruhlar')
          .doc(widget.room.id)
          .update({'azolar': FieldValue.arrayRemove([uid])});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$ism guruhdan chiqarildi"),
              backgroundColor: AppColors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e"), backgroundColor: AppColors.red));
    }
  }

  void _nusxalash(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nusxalandi!'),
            duration: Duration(seconds: 1)));
  }

  Future<void> _yangiKod() async {
    await _roomService.regenerateCode(widget.room.id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yangi kod yaratildi (4 soat)'),
            backgroundColor: AppColors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('guruhlar')
            .doc(widget.room.id)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          final room = RoomModel.fromMap(widget.room.id, d);
          final streamFaol = d['streamFaol'] as bool? ?? false;

          return Stack(children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Guruh info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(children: [
                    Text(room.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${room.azolar.length} a'zo",
                        style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.4),
                            fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Ustoz: ID va Kod
                if (widget.menUstoz) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryDark.withValues(alpha: 0.4)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        Text('Faqat ustoz ko\'radi',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryLight.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 10),

                      // Kirish kodi
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Kirish kodi',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryLight.withValues(alpha: 0.6))),
                          Text(
                            room.code.isEmpty ? '—' : (room.isCodeValid ? room.code : 'Muddati o\'tgan'),
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: room.isCodeValid ? AppColors.primary : AppColors.textHint,
                                letterSpacing: 4),
                          ),
                          if (room.code.isNotEmpty && room.isCodeValid)
                            Text(
                              _qolganVaqt(room.codeExpires),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryLight.withValues(alpha: 0.6)),
                            ),
                        ])),
                        GestureDetector(
                          onTap: room.isCodeValid ? () => _nusxalash(room.code) : null,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: room.isCodeValid
                                  ? AppColors.primaryDark
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.copy,
                                size: 14, color: AppColors.primaryLight),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _yangiKod,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Yangi kod (4 soat)',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Talaba: stream faol bo'lsa banner
                if (!widget.menUstoz && streamFaol) ...[
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => StreamScreen(
                            room: room, user: widget.user))),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jonli dars boshlandi!',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.red,
                                    fontSize: 13)),
                            Text('Ustoz stream qilmoqda',
                                style: TextStyle(color: AppColors.red, fontSize: 11)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Kirish',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // A'zolar
                Text("A'zolar",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary.withValues(alpha: 0.5))),
                const SizedBox(height: 8),

                ...room.azolar.map((uid) => FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('foydalanuvchilar').doc(uid).get(),
                  builder: (context, aSnap) {
                    if (!aSnap.hasData) return const SizedBox();
                    final ad = aSnap.data!.data() as Map<String, dynamic>? ?? {};
                    final ism = '${ad['ism'] ?? ad['name'] ?? ''} ${ad['familya'] ?? ''}'.trim();
                    final rol = ad['rol'] ?? ad['role'] ?? 'talaba';
                    final initials = ism.isNotEmpty
                        ? ism.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
                        : '?';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryDark.withValues(alpha: 0.3),
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ism.isEmpty ? 'Foydalanuvchi' : ism,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                          Text(
                            rol == 'domla' || rol == 'ustoz' ? 'Ustoz' : 'Talaba',
                            style: TextStyle(
                                fontSize: 11,
                                color: (rol == 'domla' || rol == 'ustoz')
                                    ? AppColors.green
                                    : AppColors.textHint),
                          ),
                        ])),
                        // Ustoz boshqa a'zoni chiqara oladi (o'zini emas)
                        if (widget.menUstoz && uid != widget.user.uid)
                          GestureDetector(
                            onTap: () => _talabaniChiqarish(uid, ism.isEmpty ? 'Foydalanuvchi' : ism),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.person_remove_outlined,
                                  size: 16, color: AppColors.red),
                            ),
                          ),
                      ]),
                    );
                  },
                )),

                const SizedBox(height: 80),

                // Chat tugmasi
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GuruhChatScreen(room: room, user: widget.user))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Guruh chati'),
                  ),
                ),
              ]),
            ),

            // Stream FAB — ustoz
            if (widget.menUstoz)
              Positioned(
                right: 16, bottom: 16,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FloatingActionButton(
                    backgroundColor: AppColors.red,
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => StreamScreen(room: room, user: widget.user))),
                    child: const Icon(Icons.videocam, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text('Stream',
                      style: TextStyle(fontSize: 10, color: AppColors.red,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
          ]);
        },
      ),
    );
  }

  String _qolganVaqt(DateTime tugash) {
    final qolgan = tugash.difference(DateTime.now());
    if (qolgan.isNegative) return 'Muddati o\'tgan';
    return '${qolgan.inHours} soat ${qolgan.inMinutes % 60} daqiqa qoldi';
  }
}
