import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';

class GuruhChatScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  const GuruhChatScreen({super.key, required this.room, required this.user});

  @override
  State<GuruhChatScreen> createState() => _GuruhChatScreenState();
}

class _GuruhChatScreenState extends State<GuruhChatScreen> {
  final _xabarCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _xabarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _yuborish() async {
    final matn = _xabarCtrl.text.trim();
    if (matn.isEmpty) return;
    _xabarCtrl.clear();
    await FirebaseFirestore.instance
        .collection('guruhlar').doc(widget.room.id)
        .collection('chat').add({
      'matn': matn,
      'uid': widget.user.uid,
      'ism': widget.user.fullName,
      'vaqt': FieldValue.serverTimestamp(),
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guruhlar').doc(widget.room.id)
                .collection('chat')
                .orderBy('vaqt')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final xabarlar = snap.data!.docs;
              if (xabarlar.isEmpty) {
                return const Center(
                    child: Text('Hali xabar yo\'q',
                        style: TextStyle(color: AppColors.textHint)));
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: xabarlar.length,
                itemBuilder: (context, i) {
                  final d = xabarlar[i].data() as Map<String, dynamic>;
                  final menmi = d['uid'] == widget.user.uid;
                  return Align(
                    alignment: menmi ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7),
                      child: Column(
                        crossAxisAlignment: menmi
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!menmi)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(d['ism'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textHint,
                                      fontWeight: FontWeight.w500)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: menmi ? AppColors.primaryDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(menmi ? 16 : 4),
                                bottomRight: Radius.circular(menmi ? 4 : 16),
                              ),
                            ),
                            child: Text(d['matn'] ?? '',
                                style: TextStyle(
                                    color: menmi
                                        ? AppColors.primaryLight
                                        : AppColors.textPrimary,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _xabarCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Xabar yozing...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                onSubmitted: (_) => _yuborish(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _yuborish,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: AppColors.primaryLight, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
