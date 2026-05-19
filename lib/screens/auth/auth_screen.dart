import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

// Bot username ni bu yerga yozing
const String _botUsername = 'DeltaEduBot'; // @DeltaEduBot ga o'zgartiring

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _royhattan = false;
  bool _yuklanmoqda = false;
  bool _parolKor = false;
  String? _xato;

  final _emailCtrl = TextEditingController();
  final _parolCtrl = TextEditingController();
  final _ismCtrl = TextEditingController();
  final _familyaCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _parolCtrl.dispose();
    _ismCtrl.dispose();
    _familyaCtrl.dispose();
    _telegramCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirish() async {
    setState(() { _yuklanmoqda = true; _xato = null; });
    try {
      final user = await _authService.login(
        email: _emailCtrl.text.trim(),
        password: _parolCtrl.text.trim(),
      );
      if (user != null && mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: user)));
      }
    } catch (e) {
      setState(() => _xato = "Email yoki parol noto'g'ri");
    } finally {
      if (mounted) setState(() => _yuklanmoqda = false);
    }
  }

  Future<void> _royhattanOtish() async {
    if (_ismCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _parolCtrl.text.isEmpty) {
      setState(() => _xato = "Barcha maydonlarni to'ldiring");
      return;
    }
    setState(() { _yuklanmoqda = true; _xato = null; });
    try {
      final user = await _authService.register(
        name: _ismCtrl.text.trim(),
        familya: _familyaCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _parolCtrl.text.trim(),
        role: 'talaba',
        telegramChatId: _telegramCtrl.text.trim().isEmpty
            ? null
            : _telegramCtrl.text.trim(),
      );
      if (user != null && mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: user)));
      }
    } catch (e) {
      setState(() => _xato = 'Xatolik: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _yuklanmoqda = false);
    }
  }

  void _botgaOt() async {
    final url = Uri.parse('https://t.me/$_botUsername?start=getid');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 40),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(text: 'Del', style: TextStyle(color: AppColors.textPrimary)),
                  TextSpan(text: 'ta', style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text("O'quv platformasi",
                style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            const SizedBox(height: 36),

            // Toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                _toggleBtn('Kirish', !_royhattan,
                    () => setState(() => _royhattan = false)),
                _toggleBtn("Ro'yxatdan", _royhattan,
                    () => setState(() => _royhattan = true)),
              ]),
            ),
            const SizedBox(height: 20),

            if (_royhattan) ...[
              _input(_ismCtrl, 'Ism', Icons.person_outline),
              const SizedBox(height: 12),
              _input(_familyaCtrl, 'Familya', Icons.person_outline),
              const SizedBox(height: 12),

              // Telegram ID
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _telegramCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))
                        ],
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Telegram ID',
                          prefixIcon: Icon(Icons.telegram, color: Colors.blue),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _botgaOt,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('ID olish', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                      '@$_botUsername ga o\'ting → /start → ID ni ko\'chiring',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            _input(_emailCtrl, 'Email', Icons.email_outlined,
                type: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _parolField(),

            if (_xato != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_xato!,
                    style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _yuklanmoqda
                    ? null
                    : (_royhattan ? _royhattanOtish : _kirish),
                child: _yuklanmoqda
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.primaryLight, strokeWidth: 2))
                    : Text(
                        _royhattan ? "Ro'yxatdan o'tish" : 'Kirish',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
            color: active ? AppColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? AppColors.primaryLight : AppColors.textHint,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: AppColors.textHint),
      ),
    );
  }

  Widget _parolField() {
    return TextField(
      controller: _parolCtrl,
      obscureText: !_parolKor,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Parol',
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
        suffixIcon: IconButton(
          icon: Icon(_parolKor ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textHint),
          onPressed: () => setState(() => _parolKor = !_parolKor),
        ),
      ),
    );
  }
}
