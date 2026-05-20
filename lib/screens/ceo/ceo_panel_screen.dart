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
    _tabController = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Arizalar'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Foydalanuvchilar'),
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Ustozlar'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Statistika'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ArizalarTab(),
          _FoydalanuvchilarTab(),
          _UstozlarTab(),
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
          return _bosh(Icons.assignment_outlined, "Arizalar yo'q");
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
    Color hRangi = Colors.orange;
    String hText = 'Kutilmoqda';
    if (holat == 'tasdiqlangan') { hRangi = AppColors.green; hText = 'Tasdiqlangan'; }
    if (holat == 'rad') { hRangi = AppColors.red; hText = 'Rad'; }

    return _karta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar((data['ism'] as String? ?? 'U')[0]),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${data['ism'] ?? ''} ${data['familya'] ?? ''}',
                style: const TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(data['telefon'] ?? '',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12)),
          ])),
          _holatChip(hText, hRangi),
        ]),
        const SizedBox(height: 8),
        _infoRow(Icons.school_outlined, 'Fan', data['fan'] ?? '-'),
        _infoRow(Icons.work_outline, 'Mutaxassislik', data['mutaxassislik'] ?? '-'),
        if (holat == 'kutilmoqda') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => _holat(doc.id, 'rad', uid, context),
              child: const Text('Rad'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => _holat(doc.id, 'tasdiqlangan', uid, context),
              child: const Text('Tasdiqlash'),
            )),
          ]),
        ],
      ]),
    );
  }

  Future<void> _holat(String id, String holat, String uid, BuildContext ctx) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('ustoz_arizalar').doc(id),
        {'holat': holat});
    if (holat == 'tasdiqlangan' && uid.isNotEmpty) {
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid),
          {'role': 'domla', 'rol': 'domla'});
    }
    await batch.commit();
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(holat == 'tasdiqlangan' ? 'Ustoz tayinlandi' : 'Rad etildi'),
        backgroundColor: holat == 'tasdiqlangan' ? AppColors.green : AppColors.red));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: Foydalanuvchilar — rol berish
// ─────────────────────────────────────────────────────────────────────────────
class _FoydalanuvchilarTab extends StatelessWidget {
  const _FoydalanuvchilarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bosh(Icons.people_outline, "Foydalanuvchilar yo'q");
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            final rol = data['role'] as String? ?? 'talaba';
            return _karta(
              child: Row(children: [
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
                // Rol tugmasi
                GestureDetector(
                  onTap: () => _rolDialog(context, uid, rol, ism),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _rolRangi(rol).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _rolRangi(rol).withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_rolNomi(rol),
                          style: TextStyle(color: _rolRangi(rol),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: _rolRangi(rol), size: 16),
                    ]),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Color _rolRangi(String rol) {
    if (rol == 'domla') return AppColors.primary;
    if (rol == 'ceo') return Colors.orange;
    return AppColors.textHint;
  }

  String _rolNomi(String rol) {
    if (rol == 'domla') return 'Ustoz';
    if (rol == 'ceo') return 'CEO';
    return 'Talaba';
  }

  Future<void> _rolDialog(BuildContext ctx, String uid, String joriyRol, String ism) async {
    final yangiRol = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('$ism — rol berish'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _rolOption(ctx, 'talaba', 'Talaba', joriyRol),
          _rolOption(ctx, 'domla', 'Ustoz', joriyRol),
          _rolOption(ctx, 'ceo', 'CEO', joriyRol),
        ]),
      ),
    );
    if (yangiRol == null || yangiRol == joriyRol) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': yangiRol, 'rol': yangiRol,
    });
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Rol o\'zgartirildi: $yangiRol'),
        backgroundColor: AppColors.green));
  }

  Widget _rolOption(BuildContext ctx, String value, String label, String joriy) {
    return ListTile(
      leading: Icon(
        joriy == value ? Icons.radio_button_checked : Icons.radio_button_off,
        color: joriy == value ? AppColors.primary : AppColors.textHint,
      ),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: Ustozlar — tarif qo'shish
// ─────────────────────────────────────────────────────────────────────────────
class _UstozlarTab extends StatelessWidget {
  const _UstozlarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'domla')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bosh(Icons.school_outlined, "Ustozlar yo'q");
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            final daqiqa = data['tarifDaqiqa'] as String?;
            final qolgan = data['minutesLeft'] as int? ?? 0;
            final tt = data['tarifTugash'] as int?;
            final tugash = tt != null ? DateTime.fromMillisecondsSinceEpoch(tt) : null;
            final faol = tugash != null && tugash.isAfter(DateTime.now());
            final qolganKun = tugash != null
                ? tugash.difference(DateTime.now()).inDays
                : 0;

            return GestureDetector(
              onTap: () => _tarifDialog(context, uid, ism),
              child: _karta(
                child: Row(children: [
                  _avatar(ism.isNotEmpty ? ism[0] : 'U'),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ism.isEmpty ? 'Ustoz' : ism,
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(daqiqa != null ? '$daqiqa min · $qolgan qoldi' : 'Tarifsiz',
                        style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                            fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (faol)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('TarifSiz',
                            style: TextStyle(color: AppColors.red, fontSize: 11)),
                      ),
                    const SizedBox(height: 4),
                    const Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 18),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _tarifDialog(BuildContext ctx, String uid, String ism) async {
    String tanlangan = '1500';
    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('$ism — tarif qo\'shish'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // 3 ta tarif
            ...['1500', '3000', '6000'].map((d) {
              final narx = UserModel.tarifNarxi(d, 60);
              final active = tanlangan == d;
              return GestureDetector(
                onTap: () => setS(() => tanlangan = d),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.border,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: active ? AppColors.primary : AppColors.textHint,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('$d daqiqa · 60 kishi',
                        style: TextStyle(
                            color: active ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: FontWeight.w500))),
                    Text('${narx ~/ 1000}K so\'m',
                        style: TextStyle(
                            color: active ? AppColors.primary : AppColors.textHint,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text('30 kun faol bo\'ladi',
                    style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2),
                child: const Text('Bekor')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx2);
                await _tarifQosh(ctx, uid, tanlangan);
              },
              child: const Text('Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tarifQosh(BuildContext ctx, String uid, String daqiqa) async {
    final limit = int.tryParse(daqiqa) ?? 0;
    final tugash = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'tarifDaqiqa': daqiqa,
      'tarifIshtirokchi': 60,
      'minutesLeft': limit,
      'tarifTugash': tugash.millisecondsSinceEpoch,
    });
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Tarif qo\'shildi — 30 kun faol'),
        backgroundColor: AppColors.green));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: Statistika
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
          _menuTugma(1, Icons.videocam_outlined, 'Stream'),
          _menuTugma(2, Icons.people_outline, 'Ustozlar'),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: _buildSahifa()),
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
            Text(label, style: TextStyle(fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? Colors.white : AppColors.textHint)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSahifa() {
    switch (_menuIndex) {
      case 0: return const _DaromadSahifa();
      case 1: return const _StreamSahifa();
      case 2: return const _UstozStatSahifa();
      default: return const SizedBox();
    }
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
            _bigCard("Tariflar soni", "${docs.length} ta",
                Colors.orange, Icons.receipt_outlined),
            if (oyliklar.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft,
                child: Text("Bu oygi to'lovlar",
                    style: TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(height: 8),
              ...oyliklar.map((d) => _karta(child: Row(children: [
                Expanded(child: Text(d['ustozName'] ?? 'Ustoz',
                    style: const TextStyle(color: AppColors.textPrimary))),
                Text("${_fmt(d['_narx'] as int)} so'm",
                    style: const TextStyle(color: AppColors.green,
                        fontWeight: FontWeight.w600)),
              ]))),
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

class _StreamSahifa extends StatelessWidget {
  const _StreamSahifa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').where('role', isEqualTo: 'domla').snapshots(),
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
          child: Column(children: [
            _karta(child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Jami stream',
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 11)),
                Text('$jamiIshlatilgan daqiqa',
                    style: const TextStyle(color: AppColors.primary,
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ])),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
              final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
              final qolgan = data['minutesLeft'] as int? ?? 0;
              final ishlatilgan = (limit - qolgan).clamp(0, limit);
              final foiz = limit > 0 ? (ishlatilgan / limit).clamp(0.0, 1.0) : 0.0;
              return _karta(child: Column(children: [
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
              ]));
            }),
          ]),
        );
      },
    );
  }
}

class _UstozStatSahifa extends StatelessWidget {
  const _UstozStatSahifa();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').where('role', isEqualTo: 'domla').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bosh(Icons.people_outline, "Ustozlar yo'q");
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final ism = '${data['name'] ?? ''} ${data['familya'] ?? ''}'.trim();
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _UstozDetailScreen(
                      uid: uid, ism: ism.isEmpty ? 'Ustoz' : ism, data: data))),
              child: _karta(child: Row(children: [
                _avatar(ism.isNotEmpty ? ism[0] : 'U'),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ism.isEmpty ? 'Ustoz' : ism,
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(data['email'] ?? '',
                      style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                          fontSize: 12)),
                ])),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ])),
            );
          },
        );
      },
    );
  }
}

class _UstozDetailScreen extends StatelessWidget {
  final String uid;
  final String ism;
  final Map<String, dynamic> data;
  const _UstozDetailScreen({required this.uid, required this.ism, required this.data});

  @override
  Widget build(BuildContext context) {
    final limit = int.tryParse(data['tarifDaqiqa'] ?? '0') ?? 0;
    final qolgan = data['minutesLeft'] as int? ?? 0;
    final extra = data['extraMinutes'] as int? ?? 0;
    final ishlatilgan = (limit - qolgan).clamp(0, limit);
    final foiz = limit > 0 ? (ishlatilgan / limit).clamp(0.0, 1.0) : 0.0;
    final tt = data['tarifTugash'] as int?;
    final tugash = tt != null ? DateTime.fromMillisecondsSinceEpoch(tt) : null;
    final qolganKun = tugash != null
        ? tugash.difference(DateTime.now()).inDays
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(ism, style: const TextStyle(color: AppColors.textPrimary,
            fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _karta(child: Column(children: [
            _infoRow(Icons.phone_outlined, 'Telefon', data['phone'] ?? '-'),
            _infoRow(Icons.email_outlined, 'Email', data['email'] ?? '-'),
            _infoRow(Icons.timer_outlined, 'Tarif',
                limit > 0 ? '$limit daqiqa' : 'Tarifsiz'),
            if (tugash != null)
              _infoRow(Icons.calendar_today_outlined, 'Tugash',
                  '$qolganKun kun qoldi'),
          ])),
          const SizedBox(height: 16),
          _karta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Stream statistika',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statMini('Ishlatilgan', '$ishlatilgan min', AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statMini('Qolgan', '$qolgan min', AppColors.green)),
              const SizedBox(width: 8),
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
          ])),
          const SizedBox(height: 16),
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
                return _karta(child: const Center(
                    child: Text("Guruhlar yo'q",
                        style: TextStyle(color: AppColors.textHint))));
              }
              return Column(children: guruhlar.map((doc) {
                final g = doc.data() as Map<String, dynamic>;
                final azolar = (g['azolar'] as List? ?? []).length;
                final live = g['streamFaol'] as bool? ?? false;
                return _karta(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g['nom'] ?? g['name'] ?? 'Guruh',
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    Text("$azolar a'zo",
                        style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5),
                            fontSize: 12)),
                  ])),
                  if (live)
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
                ]));
              }).toList());
            },
          ),
        ]),
      ),
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

Widget _holatChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(color: color,
        fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 15, color: AppColors.textHint),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 12)),
      Flexible(child: Text(value,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
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
          fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: 0.5), fontSize: 10)),
    ]),
  );
}
