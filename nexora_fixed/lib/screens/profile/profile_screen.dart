import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import 'tarif_screen.dart';
import 'qoshimcha_daqiqa_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isCeo ? 'CEO' : user.isDomla ? 'Ustoz' : 'Talaba',
              style: const TextStyle(color: AppColors.primaryLight, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              if (user.email.isNotEmpty) _infoRow(Icons.email_outlined, 'Email', user.email),
              if (user.phone.isNotEmpty) _infoRow(Icons.phone_outlined, 'Telefon', user.phone),
              _infoRow(Icons.person_outline, 'Rol',
                  user.isCeo ? 'CEO' : user.isDomla ? 'Ustoz' : 'Talaba'),
            ]),
          ),

          if (user.isDomla) ...[
            const SizedBox(height: 16),
            _buildTarifBlok(context),
          ],

          const SizedBox(height: 24),

          GestureDetector(
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout, color: AppColors.red, size: 18),
                SizedBox(width: 8),
                Text('Chiqish', style: TextStyle(color: AppColors.red,
                    fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildTarifBlok(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('Tarif', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const Spacer(),
          if (user.hasTarif)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${user.tarifDaqiqa} min · ${user.tarifIshtirokchi} kishi',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 14),

        if (!user.hasTarif) ...[
          const Text('Tarif tanlanmagan',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TarifScreen(user: user))),
              child: const Text('Tarif tanlash'),
            ),
          ),
        ] else ...[
          // Asosiy daqiqalar
          Text('Asosiy daqiqalar',
              style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text('${user.minutesLeft} / ${user.tarifLimit} daqiqa',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: user.tarifLimit > 0
                  ? (user.minutesLeft / user.tarifLimit).clamp(0.0, 1.0) : 0,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),

          // Qoshimcha daqiqalar
          Text("Qoshimcha daqiqalar",
              style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text('${user.extraMinutes} / 2000 daqiqa',
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (user.extraMinutes / 2000).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: user.maxExtraBuyable > 0
                    ? () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => QoshimchaDaqiqaScreen(user: user)))
                    : null,
                child: const Text("Daqiqa qoshish", style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TarifScreen(user: user))),
                child: const Text('Tarif yangilash', style: TextStyle(fontSize: 12)),
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
        Text(label, style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.4), fontSize: 13)),
        const Spacer(),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
      ]),
    );
  }
}
