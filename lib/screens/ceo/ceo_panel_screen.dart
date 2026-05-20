import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';

class CeoPanelScreen extends StatefulWidget {
  const CeoPanelScreen({super.key});

  @override
  State<CeoPanelScreen> createState() => _CeoPanelScreenState();
}

class _CeoPanelScreenState extends State<CeoPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('CEO Panel',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Foydalanuvchilar'),
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Ustozlar'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Statistika'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FoydalanuvchilarTab(),
          _UstozlarTab(),
          _StatistikTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: Foydalanuvchilar — obuna berish
// ─────────────────────────────────────────────────────────────────────────────
class _FoydalanuvchilarTab extends StatelessWidget {
  const _FoydalanuvchilarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .snapshots(),
      builder: (context, snap1) {
        final docs1 = snap1.data?.docs ?? [];
        if (docs1.isEmpty) {
          return StreamBuilder(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snap2) {
              final docs2 = snap2.data?.docs ?? [];
              if (docs2.isEmpty) {
                return _bosh(Icons.people_outline, "Foydalanuvchilar yo'q");
              }
              return _buildList(context, docs2);
            },
          );
        }
        return _buildList(context, docs1);
      },
    );
  }

  Widget _buildList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        final uid  = docs[i].id;
        final ism  = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
        final tt   = data['tarifTugash'] as int?;
        final tugash = tt != null ? DateTime.fromMillisecondsSinceEpoch(tt) : null;
        final faol = tugash != null && tugash.isAfter(DateTime.now());
        final qolganKun = tugash != null
            ? tugash.difference(DateTime.now()).inDays
            : 0;

        return GestureDetector(
          onTap: () => _obunaBerDialog(context, uid, ism.isEmpty ? 'Foydalanuvchi' : ism),
          child: _karta(child: Row(children: [
            _avatar(ism.isNotEmpty ? ism[0] : 'U'),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ism.isEmpty ? 'Foydalanuvchi' : ism,
                  style: const TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(data['email'] ?? '',
                  style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 12)),
            ])),
            if (faol)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$qolganKun kun',
                    style: const TextStyle(color: AppColors.green,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Obunasiz',
                    style: TextStyle(color: AppColors.textHint, fontSize: 11)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
          ])),
        );
      },
    );
  }

  Future<void> _obunaBerDialog(BuildContext ctx, String uid, String ism) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('$ism — obuna berish'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Column(children: [
              Row(children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Text('Cheksiz daqiqa stream',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ]),
              SizedBox(height: 6),
              Row(children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Text('60 kishigacha',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ]),
              SizedBox(height: 6),
              Row(children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Text('Guruh yaratish',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ]),
              SizedBox(height: 6),
              Row(children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Text('Whiteboard',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text('30 kun faol bo\'ladi',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Berish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final tugash = DateTime.now().add(const Duration(days: 30));

    // Daromad yozamiz
    await FirebaseFirestore.instance.collection('daromad').add({
      'uid': uid,
      'ism': ism,
      'summa': 200000,
      'vaqt': DateTime.now().millisecondsSinceEpoch,
      'oy': DateTime.now().month,
      'yil': DateTime.now().year,
    });

    // Ikki kolleksiyaga ham yozamiz
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection('foydalanuvchilar').doc(uid),
      {'tarifTugash': tugash.millisecondsSinceEpoch},
      SetOptions(merge: true),
    );
    batch.set(
      FirebaseFirestore.instance.collection('users').doc(uid),
      {'tarifTugash': tugash.millisecondsSinceEpoch},
      SetOptions(merge: true),
    );
    await batch.commit();

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('✅ Obuna berildi — 30 kun faol'),
          backgroundColor: AppColors.green));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: Ustozlar — obunali foydalanuvchilar
// ─────────────────────────────────────────────────────────────────────────────
class _UstozlarTab extends StatelessWidget {
  const _UstozlarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('daromad')
          .snapshots(),
      builder: (context, snap) {
        // Daromad hisoblash
        final daromadDocs = snap.data?.docs ?? [];
        int jami = 0, buoy = 0;
        final now2 = DateTime.now();
        for (final doc in daromadDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final summa = d['summa'] as int? ?? 200000;
          jami += summa;
          final vaqt = d['vaqt'] as int?;
          if (vaqt != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(vaqt);
            if (dt.month == now2.month && dt.year == now2.year) buoy += summa;
          }
        }
        return StreamBuilder(
          stream: FirebaseFirestore.instance.collection('foydalanuvchilar').snapshots(),
          builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];
        final now = DateTime.now();
        final obunalilar = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tt = data['tarifTugash'] as int?;
          if (tt == null) return false;
          return DateTime.fromMillisecondsSinceEpoch(tt).isAfter(now);
        }).toList();

        if (obunalilar.isEmpty) {
          return _bosh(Icons.school_outlined, "Obunali foydalanuvchi yo'q");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: obunalilar.length,
          itemBuilder: (_, i) {
            final data = obunalilar[i].data() as Map<String, dynamic>;
            final uid  = obunalilar[i].id;
            final ism  = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            final tt   = data['tarifTugash'] as int;
            final tugash = DateTime.fromMillisecondsSinceEpoch(tt);
            final qolganKun = tugash.difference(now).inDays;

            return _karta(child: Row(children: [
              _avatar(ism.isNotEmpty ? ism[0] : 'U'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ism.isEmpty ? 'Foydalanuvchi' : ism,
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(data['email'] ?? '',
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: qolganKun <= 5
                        ? AppColors.red.withValues(alpha: 0.15)
                        : AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$qolganKun kun',
                      style: TextStyle(
                          color: qolganKun <= 5 ? AppColors.red : AppColors.green,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                // Uzaytirish tugmasi
                GestureDetector(
                  onTap: () => _uzaytirish(context, uid, ism),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('+30 kun',
                        style: TextStyle(color: AppColors.primary,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ]));
          },
        );
      },
    );
  }

  Future<void> _uzaytirish(BuildContext ctx, String uid, String ism) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('$ism — uzaytirish'),
        content: const Text('30 kun qo\'shiladi. Davom etasizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ha'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Hozirgi tarifTugash ni olib, 30 kun qo'shamiz
    final doc = await FirebaseFirestore.instance
        .collection('foydalanuvchilar').doc(uid).get();
    final data = doc.data() ?? {};
    final tt = data['tarifTugash'] as int?;
    final hozirgiTugash = tt != null
        ? DateTime.fromMillisecondsSinceEpoch(tt)
        : DateTime.now();
    final yangiTugash = hozirgiTugash.isAfter(DateTime.now())
        ? hozirgiTugash.add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 30));

    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance
        .collection('foydalanuvchilar').doc(uid),
        {'tarifTugash': yangiTugash.millisecondsSinceEpoch});
    batch.set(FirebaseFirestore.instance.collection('users').doc(uid),
        {'tarifTugash': yangiTugash.millisecondsSinceEpoch},
        SetOptions(merge: true));
    await batch.commit();

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('✅ 30 kun uzaytirildi'),
          backgroundColor: AppColors.green));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: Statistika
// ─────────────────────────────────────────────────────────────────────────────
class _StatistikTab extends StatefulWidget {
  const _StatistikTab();

  @override
  State<_StatistikTab> createState() => _StatistikTabState();
}

class _StatistikTabState extends State<_StatistikTab> {
  int _menuIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          _menuTugma(0, Icons.monetization_on_outlined, 'Daromad'),
          _menuTugma(1, Icons.people_outline, 'Obunalar'),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: _menuIndex == 0
          ? const _DaromadSahifa()
          : const _ObunaSahifa()),
    ]);
  }

  Widget _menuTugma(int index, IconData icon, String label) {
    final active = _menuIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _menuIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.textHint),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? Colors.white : AppColors.textHint)),
          ]),
        ),
      ),
    );
  }
}

class _DaromadSahifa extends StatelessWidget {
  const _DaromadSahifa();

  String _fmt(int sum) {
    if (sum == 0) return '0';
    final s = sum.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('daromad').get(),
        FirebaseFirestore.instance.collection('foydalanuvchilar').get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final daromadDocs = snap.data![0].docs;
        final foydalanuvchiDocs = snap.data![1].docs;
        
        int jami = 0, buoy = 0, obunaliSoni = 0;
        final now = DateTime.now();
        
        for (final doc in daromadDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final summa = d['summa'] as int? ?? 200000;
          jami += summa;
          final vaqt = d['vaqt'] as int?;
          if (vaqt != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(vaqt);
            if (dt.month == now.month && dt.year == now.year) buoy += summa;
          }
        }
        
        for (final doc in foydalanuvchiDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final tt = data['tarifTugash'] as int?;
          if (tt != null && DateTime.fromMillisecondsSinceEpoch(tt).isAfter(now)) {
            obunaliSoni++;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _bigCard("Jami daromad",
                  "${_fmt(jami)} so'm", AppColors.primary,
                  Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _bigCard("Bu oy",
                  "${_fmt(buoy)} so'm", AppColors.green,
                  Icons.trending_up)),
            ]),
            const SizedBox(height: 10),
            _bigCard("Faol obunalar", "$obunaliSoni ta",
                Colors.orange, Icons.verified_outlined),
          ]),
        );
      },
    );
  }

  Widget _bigCard(String label, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 11)),
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ])),
      ]),
    );
  }
}

class _ObunaSahifa extends StatelessWidget {
  const _ObunaSahifa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('daromad')
          .snapshots(),
      builder: (context, snap) {
        // Daromad hisoblash
        final daromadDocs = snap.data?.docs ?? [];
        int jami = 0, buoy = 0;
        final now2 = DateTime.now();
        for (final doc in daromadDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final summa = d['summa'] as int? ?? 200000;
          jami += summa;
          final vaqt = d['vaqt'] as int?;
          if (vaqt != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(vaqt);
            if (dt.month == now2.month && dt.year == now2.year) buoy += summa;
          }
        }
        return StreamBuilder(
          stream: FirebaseFirestore.instance.collection('foydalanuvchilar').snapshots(),
          builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final now = DateTime.now();
        final obunalilar = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tt = data['tarifTugash'] as int?;
          return tt != null &&
              DateTime.fromMillisecondsSinceEpoch(tt).isAfter(now);
        }).toList();

        if (obunalilar.isEmpty) {
          return _bosh(Icons.verified_outlined, "Faol obuna yo'q");
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: obunalilar.length,
          itemBuilder: (_, i) {
            final data = obunalilar[i].data() as Map<String, dynamic>;
            final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            final tt  = data['tarifTugash'] as int;
            final tugash = DateTime.fromMillisecondsSinceEpoch(tt);
            final qolganKun = tugash.difference(now).inDays;

            return _karta(child: Row(children: [
              _avatar(ism.isNotEmpty ? ism[0] : 'U'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ism.isEmpty ? 'Foydalanuvchi' : ism,
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(data['email'] ?? '',
                    style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 11)),
              ])),
              Text('$qolganKun kun',
                  style: TextStyle(
                      color: qolganKun <= 5 ? AppColors.red : AppColors.green,
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ]));
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yordamchi widgetlar
// ─────────────────────────────────────────────────────────────────────────────
Widget _bosh(IconData icon, String text) {
  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 56, color: AppColors.textHint.withValues(alpha: 0.4)),
    const SizedBox(height: 12),
    Text(text, style: const TextStyle(color: AppColors.textHint, fontSize: 15)),
  ]));
}

Widget _karta({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

Widget _avatar(String harf) {
  return CircleAvatar(
    radius: 20,
    backgroundColor: AppColors.primaryDark,
    child: Text(harf.toUpperCase(),
        style: const TextStyle(color: AppColors.primaryLight,
            fontWeight: FontWeight.bold)),
  );
}
