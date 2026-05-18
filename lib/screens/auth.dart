import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthSahifasi extends StatefulWidget {
  const AuthSahifasi({super.key});
  @override
  State<AuthSahifasi> createState() => _AuthSahifasiState();
}

class _AuthSahifasiState extends State<AuthSahifasi> {
  static const Color dark = Color(0xFF0f172a);
  bool _royhattan = false;
  bool _yuklanmoqda = false;
  bool _parolKor = false;
  String? _xato;

  final _emailCtrl = TextEditingController();
  final _parolCtrl = TextEditingController();
  final _ismCtrl = TextEditingController();
  final _familyaCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose(); _parolCtrl.dispose();
    _ismCtrl.dispose(); _familyaCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirish() async {
    setState(() { _yuklanmoqda = true; _xato = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _parolCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _xato = e.code == 'invalid-credential'
          ? 'Email yoki parol noto\'g\'ri'
          : e.message ?? 'Xato');
    } finally {
      setState(() => _yuklanmoqda = false);
    }
  }

  Future<void> _royhattanOtish() async {
    if (_ismCtrl.text.isEmpty || _familyaCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty || _parolCtrl.text.isEmpty) {
      setState(() => _xato = "Barcha maydonlarni to'ldiring");
      return;
    }
    setState(() { _yuklanmoqda = true; _xato = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _parolCtrl.text.trim(),
      );
      final uid = cred.user!.uid;
      // ProfilId yaratish
      final profilId = _profilIdYarat(uid);
      await FirebaseFirestore.instance.collection('foydalanuvchilar').doc(uid).set({
        'ism': _ismCtrl.text.trim(),
        'familya': _familyaCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'rol': 'talaba',
        'profilId': profilId,
        'yaratilgan': FieldValue.serverTimestamp(),
        'tarif': null,
        'daqiqaLimit': 0,
        'daqiqaIshlatilgan': 0,
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _xato = e.code == 'email-already-in-use'
          ? 'Bu email allaqachon ishlatilgan'
          : e.message ?? 'Xato');
    } finally {
      setState(() => _yuklanmoqda = false);
    }
  }

  String _profilIdYarat(String uid) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = uid.hashCode.abs();
    return List.generate(6, (i) => chars[(r >> (i * 5)) % chars.length]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 40),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(16)),
              child: const Center(child: Text("Δ",
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 16),
            const Text("Delta", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("O'qon platformasi", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 36),

            // Toggle
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _toggleBtn("Kirish", !_royhattan, () => setState(() => _royhattan = false)),
                _toggleBtn("Ro'yxatdan", _royhattan, () => setState(() => _royhattan = true)),
              ]),
            ),
            const SizedBox(height: 20),

            if (_royhattan) ...[
              _input(_ismCtrl, "Ism", Icons.person_outline),
              const SizedBox(height: 12),
              _input(_familyaCtrl, "Familya", Icons.person_outline),
              const SizedBox(height: 12),
            ],
            _input(_emailCtrl, "Email", Icons.email_outlined, type: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _parolField(),

            if (_xato != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text(_xato!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _yuklanmoqda ? null : (_royhattan ? _royhattanOtish : _kirish),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _yuklanmoqda
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_royhattan ? "Ro'yxatdan o'tish" : "Kirish",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0f172a) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: TextField(controller: ctrl, keyboardType: type,
          decoration: InputDecoration(labelText: label,
              prefixIcon: Icon(icon, color: const Color(0xFF0f172a)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16))),
    );
  }

  Widget _parolField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: TextField(
        controller: _parolCtrl,
        obscureText: !_parolKor,
        decoration: InputDecoration(
          labelText: "Parol",
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0f172a)),
          suffixIcon: IconButton(
            icon: Icon(_parolKor ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: () => setState(() => _parolKor = !_parolKor),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
