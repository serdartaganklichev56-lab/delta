import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';

class CeoPanelScreen extends StatefulWidget {
  final UserModel user;
  const CeoPanelScreen({super.key, required this.user});

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
            Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Arizalar'),
            Tab(icon: Icon(Icons.credit_card_outlined, size: 18), text: 'Tarif'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Statistika'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ArizalarTab(),
          _TarifTab(),
          _StatistikTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: Arizalar
// ─────────────────────────────────────────────────────────────────────────────
class _ArizalarTab extends StatelessWidget {
  const _ArizalarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ustoz_arizalar')
          .orderBy('vaqt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.assignment_outlined, size: 56,
                color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text("Arizalar yo'q",
                style: TextStyle(color: AppColors.textHint, fontSize: 15)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ArizaCard(doc: docs[i]),
        );
      },
    );
  }
}

class _ArizaCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _ArizaCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final holat = data['holat'] as String? ?? 'kutilmoqda';
    final uid = data['uid'] as String? ?? '';

    Color holatRangi = Colors.orange;
    String holatText = 'Kutilmoqda';
    if (holat == 'tasdiqlangan') { holatRangi = AppColors.green; holatText = 'Tasdiqlangan'; }
    if (holat == 'rad') { holatRangi = AppColors.red; holatText = 'Rad etilgan'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryDark,
            child: Text((data['ism'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${data['ism'] ?? ''} ${data['familya'] ?? ''}',
                style: const TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(data['telefon'] ?? '',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: holatRangi.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(holatText, style: TextStyle(color: holatRangi,
                fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        _infoRow(Icons.school_outlined, 'Fan', data['fan'] ?? '-'),
        _infoRow(Icons.work_outline, 'Mutaxassislik', data['mutaxassislik'] ?? '-'),
        if (holat == 'kutilmoqda') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Rad', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _holat(doc.id, 'rad', uid, context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Tasdiqlash', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _holat(doc.id, 'tasdiqlangan', uid, context),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 12)),
        Flexible(child: Text(value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
      ]),
    );
  }

  Future<void> _holat(String arizaId, String holat,
      String uid, BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance
        .collection('ustoz_arizalar').doc(arizaId), {'holat': holat});
    if (holat == 'tasdiqlangan' && uid.isNotEmpty) {
      batch.update(FirebaseFirestore.instance
          .collection('users').doc(uid), {'role': 'domla', 'rol': 'domla'});
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(holat == 'tasdiqlangan'
            ? 'Tasdiqlandi — ustoz tayinlandi' : 'Rad etildi'),
        backgroundColor: holat == 'tasdiqlangan' ? AppColors.green : AppColors.red,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: Tarif
// ─────────────────────────────────────────────────────────────────────────────
class _TarifTab extends StatelessWidget {
  const _TarifTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tarif_sorovlar')
          .orderBy('vaqt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.credit_card_outlined, size: 56,
                color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text("Tarif so'rovlari yo'q",
                style: TextStyle(color: AppColors.textHint, fontSize: 15)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _TarifCard(doc: docs[i]),
        );
      },
    );
  }
}

class _TarifCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _TarifCard({required this.doc});

  String _narx(String? d, int? i) {
    final n = UserModel.tarifNarxi(d ?? '', i ?? 0);
    return n == 0 ? '-' : "${(n / 1000).toStringAsFixed(0)} 000 so'm";
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final holat = data['holat'] as String? ?? 'kutilmoqda';
    final uid = data['uid'] as String? ?? '';
    final daqiqa = data['tarifDaqiqa'] as String?;
    final ishtirokchi = data['tarifIshtirokchi'] as int?;

    Color holatRangi = Colors.orange;
    String holatText = 'Kutilmoqda';
    if (holat == 'tasdiqlangan') { holatRangi = AppColors.green; holatText = 'Tasdiqlangan'; }
    if (holat == 'rad') { holatRangi = AppColors.red; holatText = 'Rad etilgan'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['ustozName'] ?? 'Ustoz',
                style: const TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(data['phone'] ?? '',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: holatRangi.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(holatText, style: TextStyle(color: holatRangi,
                fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const Divider(height: 16),
        Wrap(spacing: 8, children: [
          _chip(Icons.timer_outlined, '$daqiqa min'),
          _chip(Icons.people_outline, '$ishtirokchi kishi'),
          _chip(Icons.attach_money, _narx(daqiqa, ishtirokchi)),
        ]),
        if (holat == 'kutilmoqda') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _tasdiqlash(doc.id, 'rad', uid, null, null, context),
                child: const Text('Rad'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _tasdiqlash(
                    doc.id, 'tasdiqlangan', uid, daqiqa, ishtirokchi, context),
                child: const Text('Tasdiqlash'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.primary,
            fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _tasdiqlash(String sorovId, String holat, String uid,
      String? daqiqa, int? ishtirokchi, BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance
        .collection('tarif_sorovlar').doc(sorovId), {'holat': holat});
    if (holat == 'tasdiqlangan' && uid.isNotEmpty) {
      final limit = int.tryParse(daqiqa ?? '0') ?? 0;
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'tarifDaqiqa': daqiqa,
        'tarifIshtirokchi': ishtirokchi,
        'minutesLeft': limit,
      });
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(holat == 'tasdiqlangan'
            ? 'Tarif aktivlashtirildi' : 'Rad etildi'),
        backgroundColor: holat == 'tasdiqlangan' ? AppColors.green : AppColors.red,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: Statistika — ichki 3 ta menyu
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
      // Ichki menyu
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          _menuTugma(0, Icons.monetization_on_outlined, 'Daromad'),
          _menuTugma(1, Icons.videocam_outlined, 'Stream'),
          _menuTugma(2, Icons.people_outline, 'Ustozlar'),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: _buildMenyuSahifa()),
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
            Icon(icon, size: 16,
                color: active ? Colors.white : AppColors.textHint),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? Colors.white : AppColors.textHint)),
          ]),
        ),
      ),
    );
  }

  Widget _buildMenyuSahifa() {
    switch (_menuIndex) {
      case 0: return const _DaromadSahifa();
      case 1: return const _StreamSahifa();
      case 2: return const _UstozlarSahifa();
      default: return const SizedBox();
    }
  }
}

// ── Daromad ──────────────────────────────────────────────────────────────────
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tarif_sorovlar')
          .where('holat', isEqualTo: 'tasdiqlangan')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int jami = 0, buoy = 0;
        final now = DateTime.now();
        final oyliklar = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final narx = UserModel.tarifNarxi(
              data['tarifDaqiqa'] as String? ?? '',
              data['tarifIshtirokchi'] as int? ?? 0);
          jami += narx;
          final vaqt = data['vaqt'] as int?;
          if (vaqt != null) {
            final d = DateTime.fromMillisecondsSinceEpoch(vaqt);
            if (d.month == now.month && d.year == now.year) {
              buoy += narx;
              oyliklar.add({...data, '_narx': narx});
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Katta raqamlar
            Row(children: [
              Expanded(child: _bigCard("Jami daromad",
                  "${_fmt(jami)} so'm", AppColors.primary, Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _bigCard("Bu oy",
                  "${_fmt(buoy)} so'm", AppColors.green, Icons.trending_up)),
            ]),
            const SizedBox(height: 16),
            _bigCard("Tasdiqlangan tariflar",
                "${docs.length} ta to'lov", Colors.orange, Icons.receipt_outlined),
            const SizedBox(height: 20),
            // Bu oygi to'lovlar ro'yxati
            if (oyliklar.isNotEmpty) ...[
              const Text("Bu oygi to'lovlar",
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              ...oyliklar.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(child: Text(d['ustozName'] ?? 'Ustoz',
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontSize: 13))),
                  Text("${_fmt(d['_narx'] as int)} so'm",
                      style: const TextStyle(color: AppColors.green,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              )),
            ],
          ]),
        );
      },
    );
  }

  Widget _bigCard(String label, String value, Color color, IconData icon) {
    return Container(
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
              color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ])),
      ]),
    );
  }
}

// ── Stream statistika ─────────────────────────────────────────────────────────
class _StreamSahifa extends StatelessWidget {
  const _StreamSahifa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'domla')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int jamiIshlatilgan = 0;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
          final qolgan = data['minutesLeft'] as int? ?? 0;
          jamiIshlatilgan += (limit - qolgan).clamp(0, limit);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam_outlined,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Jami stream daqiqalari',
                      style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                          fontSize: 11)),
                  Text('$jamiIshlatilgan daqiqa',
                      style: const TextStyle(color: AppColors.primary,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Ustozlar bo\'yicha',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
              final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
              final qolgan = data['minutesLeft'] as int? ?? 0;
              final ishlatilgan = (limit - qolgan).clamp(0, limit);
              final foiz = limit > 0 ? (ishlatilgan / limit).clamp(0.0, 1.0) : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ism.isEmpty ? 'Ustoz' : ism,
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontSize: 13, fontWeight: FontWeight.w500))),
                    Text('$ishlatilgan / $limit min',
                        style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                            fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: foiz,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                          foiz > 0.8 ? AppColors.red : AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

// ── Ustozlar ro'yxati — bossa detail ─────────────────────────────────────────
class _UstozlarSahifa extends StatelessWidget {
  const _UstozlarSahifa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'domla')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline, size: 56,
                color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text("Ustozlar yo'q",
                style: TextStyle(color: AppColors.textHint, fontSize: 15)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
            final qolgan = data['minutesLeft'] as int? ?? 0;
            final ishlatilgan = (limit - qolgan).clamp(0, limit);

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _UstozDetailScreen(
                      uid: uid, ism: ism.isEmpty ? 'Ustoz' : ism,
                      data: data))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryDark,
                    child: Text(
                      (ism.isNotEmpty ? ism[0] : 'U').toUpperCase(),
                      style: const TextStyle(color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ism.isEmpty ? 'Ustoz' : ism,
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('$ishlatilgan / $limit min ishlatilgan',
                        style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                            fontSize: 12)),
                  ])),
                  const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Ustoz detail sahifasi ─────────────────────────────────────────────────────
class _UstozDetailScreen extends StatelessWidget {
  final String uid;
  final String ism;
  final Map<String, dynamic> data;
  const _UstozDetailScreen(
      {required this.uid, required this.ism, required this.data});

  @override
  Widget build(BuildContext context) {
    final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
    final qolgan = data['minutesLeft'] as int? ?? 0;
    final extra = data['extraMinutes'] as int? ?? 0;
    final ishlatilgan = (limit - qolgan).clamp(0, limit);
    final foiz = limit > 0 ? (ishlatilgan / limit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(ism, style: const TextStyle(color: AppColors.textPrimary,
            fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ustoz ma'lumotlari
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _infoRow(Icons.phone_outlined, 'Telefon', data['phone'] ?? '-'),
              _infoRow(Icons.email_outlined, 'Email', data['email'] ?? '-'),
              _infoRow(Icons.timer_outlined, 'Tarif',
                  limit > 0 ? '$limit daqiqa / ${data['tarifIshtirokchi']} kishi' : 'TarifSiz'),
            ]),
          ),
          const SizedBox(height: 16),

          // Stream statistika
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Stream statistika',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _statMini('Ishlatilgan', '$ishlatilgan min', AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _statMini("Qolgan", '$qolgan min', AppColors.green)),
                const SizedBox(width: 10),
                Expanded(child: _statMini("Qo'shimcha", '$extra min', Colors.orange)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: foiz,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(
                      foiz > 0.8 ? AppColors.red : AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text('${(foiz * 100).toStringAsFixed(0)}% ishlatilgan',
                  style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 16),

          // Guruhlar
          const Text("Guruhlar",
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guruhlar')
                .where('ustozId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snap) {
              final guruhlar = snap.data?.docs ?? [];
              if (guruhlar.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text("Guruhlar yo'q",
                        style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: guruhlar.map((doc) {
                  final g = doc.data() as Map<String, dynamic>;
                  final azolar = (g['azolar'] as List? ?? []).length;
                  final streamFaol = g['streamFaol'] as bool? ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g['nom'] ?? g['name'] ?? 'Guruh',
                            style: const TextStyle(color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500, fontSize: 13)),
                        Text("$azolar a'zo",
                            style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                                fontSize: 11)),
                      ])),
                      if (streamFaol)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, color: AppColors.red, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(color: AppColors.red,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 13)),
        Flexible(child: Text(value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
      ]),
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
            fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 10)),
      ]),
    );
  }
}
