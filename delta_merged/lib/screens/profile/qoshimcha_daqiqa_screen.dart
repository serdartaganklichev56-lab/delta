import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';

class QoshimchaDaqiqaScreen extends StatefulWidget {
  final UserModel user;
  const QoshimchaDaqiqaScreen({super.key, required this.user});

  @override
  State<QoshimchaDaqiqaScreen> createState() => _QoshimchaDaqiqaScreenState();
}

class _QoshimchaDaqiqaScreenState extends State<QoshimchaDaqiqaScreen> {
  int _miqdor = 100;
  bool _yuklanmoqda = false;
  static const int narxPerMin = 200;

  int get narx => _miqdor * narxPerMin;
  int get maxMiqdor => widget.user.maxExtraBuyable.clamp(50, 2000);

  String _formatNarx(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)},000';
    return n.toString();
  }

  Future<void> _sorovYuborish() async {
    if (_miqdor <= 0) return;
    setState(() => _yuklanmoqda = true);
    try {
      await FirebaseFirestore.instance.collection('sorovlar').add({
        'uid': widget.user.uid,
        'ism': widget.user.fullName,
        'email': widget.user.email,
        'tur': 'qoshimcha_daqiqa',
        'daqiqa': _miqdor,
        'narx': narx,
        'holat': 'kutilmoqda',
        'vaqt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorov yuborildi! Tez orada boglanamiz.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _yuklanmoqda = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Qoshimcha daqiqa")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: AppColors.green, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Qoshimcha daqiqa',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                  Text('${widget.user.extraMinutes} / 2000 daqiqa',
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                ]),
                const Spacer(),
                Text('Max: $maxMiqdor min',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              ]),
            ),

            const SizedBox(height: 24),

            const Text('Necha daqiqa?', style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 16),

            Slider(
              value: _miqdor.toDouble(),
              min: 50,
              max: maxMiqdor.toDouble(),
              divisions: ((maxMiqdor - 50) / 50).round().clamp(1, 39),
              activeColor: AppColors.green,
              onChanged: (v) => setState(() => _miqdor = v.round()),
            ),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_miqdor daqiqa', style: const TextStyle(
                  color: AppColors.green, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              children: [100, 250, 500, 1000].where((m) => m <= maxMiqdor).map((m) {
                return GestureDetector(
                  onTap: () => setState(() => _miqdor = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _miqdor == m
                          ? AppColors.green.withValues(alpha: 0.2)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _miqdor == m ? AppColors.green : AppColors.border),
                    ),
                    child: Text('$m min', style: TextStyle(
                        color: _miqdor == m ? AppColors.green : AppColors.textHint,
                        fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Miqdor:', style: TextStyle(color: AppColors.textHint)),
                  Text('$_miqdor daqiqa',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Narx:', style: TextStyle(color: AppColors.textHint)),
                  Text('${_formatNarx(narx)} som',
                      style: const TextStyle(color: AppColors.green,
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ]),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _yuklanmoqda ? null : _sorovYuborish,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                child: _yuklanmoqda
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sorov yuborish'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '* 1 daqiqa = 200 som. Tolovdan keyin daqiqalar qoshiladi.',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}
