import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';

class TarifScreen extends StatefulWidget {
  final UserModel user;
  const TarifScreen({super.key, required this.user});

  @override
  State<TarifScreen> createState() => _TarifScreenState();
}

class _TarifScreenState extends State<TarifScreen> {
  String _tanlanganDaqiqa = '1500';
  int _tanlanganIshtirokchi = 50;
  bool _yuklanmoqda = false;

  final List<String> daqiqalar = ['1500', '3000', '6000'];
  final List<int> ishtirokchilar = [50, 100, 150];

  int get narx => UserModel.tarifNarxi(_tanlanganDaqiqa, _tanlanganIshtirokchi);

  String _formatNarx(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)},000';
    return n.toString();
  }

  Future<void> _sorovYuborish() async {
    setState(() => _yuklanmoqda = true);
    try {
      await FirebaseFirestore.instance.collection('sorovlar').add({
        'uid': widget.user.uid,
        'ism': widget.user.fullName,
        'email': widget.user.email,
        'tur': 'tarif',
        'tarifDaqiqa': _tanlanganDaqiqa,
        'tarifIshtirokchi': _tanlanganIshtirokchi,
        'narx': narx,
        'holat': 'kutilmoqda',
        'vaqt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorov yuborildi! Tez orada siz bilan boglanamiz.'),
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
      appBar: AppBar(title: const Text('Tarif tanlash')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Oylik daqiqa', style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: daqiqalar.map((d) {
              final active = _tanlanganDaqiqa == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tanlanganDaqiqa = d),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primaryDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Text(d, style: TextStyle(
                          color: active ? AppColors.primaryLight : AppColors.textPrimary,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('min', style: TextStyle(
                          color: active ? AppColors.primaryLight.withValues(alpha: 0.7) : AppColors.textHint,
                          fontSize: 11)),
                    ]),
                  ),
                ),
              );
            }).toList()),

            const SizedBox(height: 20),

            const Text('Ishtirokchilar', style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: ishtirokchilar.map((i) {
              final active = _tanlanganIshtirokchi == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tanlanganIshtirokchi = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primaryDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Text('$i', style: TextStyle(
                          color: active ? AppColors.primaryLight : AppColors.textPrimary,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('kishi', style: TextStyle(
                          color: active ? AppColors.primaryLight.withValues(alpha: 0.7) : AppColors.textHint,
                          fontSize: 11)),
                    ]),
                  ),
                ),
              );
            }).toList()),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                const Text('Oylik narx', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                const SizedBox(height: 6),
                Text('${_formatNarx(narx)} som', style: const TextStyle(
                    color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_tanlanganDaqiqa daqiqa · $_tanlanganIshtirokchi ishtirokchi',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              ]),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _yuklanmoqda ? null : _sorovYuborish,
                child: _yuklanmoqda
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
                    : const Text("Sorov yuborish"),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              '* Sorov yuborilgandan keyin admin siz bilan boglanadi va tolov malumotlarini yuboradi.',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}
