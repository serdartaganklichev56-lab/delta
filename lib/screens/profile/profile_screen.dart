import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _telegramChatId;
  DateTime? _tarifTugash;
  bool _yuklanmoqda = true;
  bool _tgSaqlanmoqda = false;

  @override
  void initState() {
    super.initState();
    _malumotOqish();
  }

  Future<void> _malumotOqish() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      if (mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _telegramChatId = data['telegramChatId'] as String?;
          final tt = data['tarifTugash'] as int?;
          _tarifTugash = tt != null
              ? DateTime.fromMillisecondsSinceEpoch(tt)
              : null;
          _yuklanmoqda = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yuklanmoqda = false);
    }
  }

  Future<void> _telegramBoglash() async {
    final ctrl = TextEditingController(text: _telegramChatId ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telegram bog\'lash'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '1. @DeltaEduBot ga o\'ting → /start bosing\n'
                '2. Bot ID raqamingizni yuboradi\n'
                '3. Shu raqamni kiriting',
                style: TextStyle(color: Colors.blue.shade800,
                    fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://t.me/DeltaEduBot?start=getid');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.telegram, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('@DeltaEduBot ga o\'tish',
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))
            ],
            decoration: InputDecoration(
              labelText: 'Telegram Chat ID',
              hintText: '123456789',
              prefixIcon: const Icon(Icons.telegram),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Saqlash')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _tgSaqlanmoqda = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'telegramChatId': result});
      if (mounted) {
        setState(() {
          _telegramChatId = result;
          _tgSaqlanmoqda = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Telegram bog\'landi'),
            backgroundColor: AppColors.green));
      }
    } catch (e) {
      if (mounted) setState(() => _tgSaqlanmoqda = false);
    }
  }

  String _qolganKunlar() {
    if (_tarifTugash == null) return '';
    final diff = _tarifTugash!.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Muddati tugagan';
    return '$diff kun qoldi';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryDark,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'D',
              style: const TextStyle(color: AppColors.primaryLight,
                  fontSize: 30, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Text(user.fullName,
              style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isCeo ? 'CEO' : user.isDomla ? 'Ustoz' : 'Talaba',
              style: const TextStyle(
                  color: AppColors.primaryLight, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          // Ma'lumotlar
          _blok(children: [
            if (user.email.isNotEmpty)
              _infoRow(Icons.email_outlined, 'Email', user.email),
            if (user.phone.isNotEmpty)
              _infoRow(Icons.phone_outlined, 'Telefon', user.phone),
            _infoRow(Icons.person_outline, 'Rol',
                user.isCeo ? 'CEO' : user.isDomla ? 'Ustoz' : 'Talaba'),
          ]),

          // Tarif bloki (faqat ustoz)
          if (user.isDomla) ...[
            const SizedBox(height: 16),
            _buildTarifBlok(),
          ],

          // Telegram bloki (faqat ustoz)
          if (user.isDomla) ...[
            const SizedBox(height: 16),
            _buildTelegramBlok(),
          ],

          const SizedBox(height: 24),
          _chiqishTugma(context),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Tarif bloki ─────────────────────────────────────────────────────────────
  Widget _buildTarifBlok() {
    final user = widget.user;
    final faol = _tarifTugash != null &&
        _tarifTugash!.isAfter(DateTime.now());

    return _blok(children: [
      Row(children: [
        const Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        const Text('Tarif',
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: AppColors.textPrimary)),
        const Spacer(),
        if (_yuklanmoqda)
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (faol)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_qolganKunlar(),
                style: const TextStyle(color: AppColors.green,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          )
        else if (user.hasTarif)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Muddati tugagan',
                style: TextStyle(color: AppColors.red, fontSize: 11)),
          ),
      ]),
      const SizedBox(height: 14),

      if (!user.hasTarif) ...[
        // Tariflar ro'yxati — faqat ko'rish
        const Text('Tariflar',
            style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: ['1500', '3000', '6000'].map((d) {
          final narx = UserModel.tarifNarxi(d, 60);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                Text(d,
                    style: const TextStyle(color: AppColors.primary,
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('min',
                    style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                const SizedBox(height: 4),
                Text('${narx ~/ 1000}K so\'m',
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontSize: 11)),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Tarif olish uchun admin bilan bog\'laning',
            style: TextStyle(color: AppColors.textHint,
                fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ] else ...[
        // Aktiv tarif
        Row(children: [
          Expanded(child: _statMini('Tarif',
              '${user.tarifDaqiqa} min', AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: _statMini("Qolgan",
              '${user.minutesLeft} min', AppColors.green)),
          const SizedBox(width: 8),
          Expanded(child: _statMini("Qo'shimcha",
              '${user.extraMinutes} min', Colors.orange)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: user.tarifLimit > 0
                ? (user.minutesLeft / user.tarifLimit).clamp(0.0, 1.0)
                : 0,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 5,
          ),
        ),
      ],
    ]);
  }

  // ── Telegram bloki ──────────────────────────────────────────────────────────
  Widget _buildTelegramBlok() {
    final boglangan = _telegramChatId != null && _telegramChatId!.isNotEmpty;
    return _blok(children: [
      Row(children: [
        Icon(Icons.telegram,
            size: 18,
            color: boglangan ? Colors.blue : AppColors.textHint),
        const SizedBox(width: 6),
        const Text('Telegram',
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: AppColors.textPrimary)),
        const Spacer(),
        if (boglangan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 12, color: Colors.blue),
              SizedBox(width: 4),
              Text("Bog'langan",
                  style: TextStyle(color: Colors.blue, fontSize: 11)),
            ]),
          ),
      ]),
      const SizedBox(height: 12),
      if (boglangan) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Icon(Icons.tag, size: 14, color: Colors.blue.shade400),
            const SizedBox(width: 6),
            Text('Chat ID: $_telegramChatId',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text("O'zgartirish"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _tgSaqlanmoqda ? null : _telegramBoglash,
        ),
      ] else ...[
        Text(
          "Dars yozuvlari Telegram ga yuborilishi uchun bog'lang",
          style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.telegram, size: 18),
            label: _tgSaqlanmoqda
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("Telegram bog'lash"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _tgSaqlanmoqda ? null : _telegramBoglash,
          ),
        ),
      ],
    ]);
  }

  Widget _blok({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _statMini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.5),
            fontSize: 10)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.4),
                fontSize: 13)),
        const Spacer(),
        Flexible(child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13))),
      ]),
    );
  }

  Widget _chiqishTugma(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await AuthService().signOut();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (_) => false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.red.withValues(alpha: 0.2)),
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: AppColors.red, size: 18),
              SizedBox(width: 8),
              Text('Chiqish',
                  style: TextStyle(color: AppColors.red,
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
      ),
    );
  }
}
