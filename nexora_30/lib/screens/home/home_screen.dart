import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../../services/room_service.dart';
import '../profile/profile_screen.dart';
import '../guruh/guruh_ichida_screen.dart';
import 'create_room_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _roomService = RoomService();
  final _kodCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0 ? _buildHome() : ProfileScreen(user: widget.user),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: _currentIndex == 0 && (widget.user.isDomla || widget.user.isCeo)
          ? FloatingActionButton(
              onPressed: _guruhYaratish,
              backgroundColor: AppColors.primaryDark,
              child: const Icon(Icons.add, color: AppColors.primaryLight),
            )
          : null,
    );
  }

  Widget _buildHome() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          Expanded(
            child: StreamBuilder<List<RoomModel>>(
              stream: _roomService.getUserRooms(widget.user.uid),
              builder: (context, snap) {
                final rooms = snap.data ?? [];
                return Column(
                  children: [
                    if (widget.user.isTalaba) _buildKodKirish(),
                    Expanded(
                      child: rooms.isEmpty
                          ? _buildBosh()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: rooms.length,
                              itemBuilder: (_, i) => _buildRoomCard(rooms[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              children: [
                TextSpan(text: 'Del', style: TextStyle(color: AppColors.textPrimary)),
                TextSpan(text: 'ta', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                widget.user.isDomla ? '👨‍🏫' : widget.user.isCeo ? '👑' : '👨‍🎓',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryDark,
                child: Text(
                  widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'D',
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKodKirish() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.key_outlined, color: AppColors.textHint, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _kodCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Kirish kodi...',
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                filled: false,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => _kodBilanKirish(_kodCtrl.text.trim()),
            child: const Text('Kirish'),
          ),
        ]),
      ),
    );
  }

  Widget _buildBosh() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.groups_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('Guruhlar yo\'q', style: TextStyle(color: AppColors.textHint, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          widget.user.isTalaba ? 'Kod yozib guruhga kiring' : '+ tugmasini bosib guruh yarating',
          style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6), fontSize: 13),
        ),
      ]),
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final menUstoz = room.domlaId == widget.user.uid;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => GuruhIchidaScreen(
                  room: room, user: widget.user, menUstoz: menUstoz))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                '${room.azolar.length} a\'zo · ${menUstoz ? 'Ustoz' : 'Talaba'}',
                style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.4), fontSize: 12),
              ),
            ]),
          ),
          if (room.streamFaol)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: AppColors.red, size: 8),
                SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: AppColors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(width: 8),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: room.isActive ? AppColors.green : AppColors.border,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: const TextStyle(fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Guruhlar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  Future<void> _kodBilanKirish(String kod) async {
    if (kod.isEmpty) return;
    final natija = await _roomService.joinRoomByCode(
        code: kod, userId: widget.user.uid);
    if (!mounted) return;
    _kodCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(natija == 'ok' ? 'Guruhga qo\'shildingiz!' : natija),
      backgroundColor: natija == 'ok' ? AppColors.green : AppColors.red,
    ));
  }

  void _guruhYaratish() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateRoomScreen(user: widget.user)));
  }
}
