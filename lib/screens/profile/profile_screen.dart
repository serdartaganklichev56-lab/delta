import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import 'tarif_screen.dart';
import 'qoshimcha_daqiqa_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _telegramChatId;
  bool _tgYuklanmoqda = true;
  bool _tgSaqlanmoqda = false;

  @override
  void initState() {
    super.initState();
    if (widget.user.isDomla) _tgIdOqish();
  }

  // Firestore dan mavjud telegramChatId ni o'qiymiz
  Future<void> _tgIdOqish() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      if (mounted) {
        setState(() {
          _telegramChatId = doc.data()?['telegramChatId'] as String?;
          _tgYuklanmoqda = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tgYuklanmoqda = false);
    }
  }

  // Telegram bog'lash dialog
  Future<void> _telegramBoglash() async {
    final controller = TextEditingController(text: _telegramChatId ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telegram bog\'lash'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Qo'llanma
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text('Qanday olish kerak?',
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(
                '1. Telegramda @userinfobot ga /start yuboring\n'
                '2. Bot sizning ID raqamingizni ko\'rsatadi\n'
                '3. Shu raqamni quyiga kiriting',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 12, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
            ],
            decoration: InputDecoration(
              labelText: 'Telegram Chat ID',
              hintText: 'Masalan: 123456789',
              prefixIcon: const Icon(Icons.telegram),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Bekor")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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
            content: Text('✅ Telegram muvaffaqiyatli bog\'landi'),
            backgroundColor: AppColors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _tgSaqlanmoqda = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Xato: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  // Telegram ajratish
  Future<void> _telegramAjratish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Telegramni ajratish'),
        content: const Text('Telegram hisobingiz ajratiladi. Davom etasizmi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajrat',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _tgSaqlanmoqda = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'telegramChatId': FieldValue.delete()});
      if (mounted) {
        setState(() {
          _telegramChatId = null;
          _tgSaqlanmoqda = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Telegram ajratildi'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) setState(() => _tgSaqlanmoqda = false);
    }
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
          Text(user.fullName, style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600)),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              if (user.email.isNotEmpty)
                _infoRow(Icons.email_outlined, 'Email', user.email),
              if (user.phone.isNotEmpty)
                _infoRow(Icons.phone_outlined, 'Telefon', user.phone),
              _infoRow(Icons.person_outline, 'Rol',
                  user.isCeo ? 'CEO' : user.isDomla ? 'Ustoz' : 'Talaba'),
            ]),
          ),

          // Tarif bloki (faqat ustoz uchun)
          if (user.isDomla) ...[
            const SizedBox(height: 16),
            _buildTarifBlok(context),
          ],

          // Telegram bloki (faqat ustoz uchun)
          if (user.isDomla) ...[
            const SizedBox(height: 16),
            _buildTelegramBlok(),
          ],

          const SizedBox(height: 24),

          // Chiqish
          GestureDetector(
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthScreen()),
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
                        style: TextStyle(
                            color: AppColors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ]),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Telegram bloki ──────────────────────────────────────────────────────────
  Widget _buildTelegramBlok() {
    final boglangan = _telegramChatId != null && _telegramChatId!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: boglangan
              ? Colors.blue.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.telegram,
              size: 18,
              color: boglangan ? Colors.blue : AppColors.textHint),
          const SizedBox(width: 6),
          const Text('Telegram',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
          const Spacer(),
          if (_tgYuklanmoqda)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
          else if (boglangan)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, size: 12, color: Colors.blue),
                SizedBox(width: 4),
                Text('Bog\'langan',
                    style: TextStyle(color: Colors.blue, fontSize: 11)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),

        if (_tgYuklanmoqda)
          const SizedBox(height: 8)
        else if (boglangan) ...[
          // ID ko'rsatish
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
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontFamily: 'monospace')),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('O\'zgartirish', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _tgSaqlanmoqda ? null : _telegramBoglash,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link_off, size: 15),
                label: const Text('Ajratish', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _tgSaqlanmoqda ? null : _telegramAjratish,
              ),
            ),
          ]),
        ] else ...[
          // Bog'lanmagan holat
          Text(
            'Dars yozuvlari Telegram ga yuborilishi uchun hisobingizni bog\'lang.',
            style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.telegram, size: 18),
              label: _tgSaqlanmoqda
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Telegram bog\'lash'),
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
      ]),
    );
  }

  Widget _buildTarifBlok(BuildContext context) {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('Tarif',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
          const Spacer(),
          if (user.hasTarif)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  '${user.tarifDaqiqa} min · ${user.tarifIshtirokchi} kishi',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 14),
        if (!user.hasTarif) ...[
          const Text('Tarif tanlanmagan',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => TarifScreen(user: user))),
              child: const Text('Tarif tanlash'),
            ),
          ),
        ] else ...[
          Text('Asosiy daqiqalar',
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 11)),
          const SizedBox(height: 4),
          Text('${user.minutesLeft} / ${user.tarifLimit} daqiqa',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: user.tarifLimit > 0
                  ? (user.minutesLeft / user.tarifLimit).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Text("Qoshimcha daqiqalar",
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 11)),
          const SizedBox(height: 4),
          Text('${user.extraMinutes} / 2000 daqiqa',
              style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (user.extraMinutes / 2000).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.green),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(
                      color: AppColors.green.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: user.maxExtraBuyable > 0
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                QoshimchaDaqiqaScreen(user: user)))
                    : null,
                child: const Text("Daqiqa qoshish",
                    style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => TarifScreen(user: user))),
                child: const Text('Tarif yangilash',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ],
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
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13))),
      ]),
    );
  }
}
