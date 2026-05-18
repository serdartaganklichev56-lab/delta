import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSahifasi extends StatefulWidget {
  final String guruhId;
  final String guruhNom;
  const ChatSahifasi({super.key, required this.guruhId, required this.guruhNom});
  @override
  State<ChatSahifasi> createState() => _ChatSahifasiState();
}

class _ChatSahifasiState extends State<ChatSahifasi> {
  static const Color dark = Color(0xFF0f172a);
  final uid = FirebaseAuth.instance.currentUser?.uid;
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
    final snap = await FirebaseFirestore.instance
        .collection('foydalanuvchilar').doc(uid).get();
    final d = snap.data() ?? {};
    final ism = '${d['ism'] ?? ''} ${d['familya'] ?? ''}'.trim();
    await FirebaseFirestore.instance
        .collection('guruhlar').doc(widget.guruhId)
        .collection('xabarlar').add({
      'matn': matn,
      'uid': uid,
      'ism': ism,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: dark,
        title: Text(widget.guruhNom, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guruhlar').doc(widget.guruhId)
                .collection('xabarlar')
                .orderBy('vaqt')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(
                  child: Text("Birinchi xabarni yozing 👋",
                      style: TextStyle(color: Colors.grey)));
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final menmi = d['uid'] == uid;
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
                            Text(d['ism'] ?? '—',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: menmi ? dark : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(menmi ? 16 : 4),
                                bottomRight: Radius.circular(menmi ? 4 : 16),
                              ),
                              border: menmi ? null
                                  : Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(d['matn'] ?? '',
                                style: TextStyle(
                                    color: menmi ? Colors.white : Colors.black87,
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
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(10),
                blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _xabarCtrl,
                decoration: InputDecoration(
                  hintText: "Xabar yozing...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                decoration: const BoxDecoration(color: dark, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
