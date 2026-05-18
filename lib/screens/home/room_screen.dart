// lib/screens/home/room_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../services/room_service.dart';

class RoomScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  const RoomScreen({super.key, required this.room, required this.user});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _msgController = TextEditingController();
  final _roomService = RoomService();
  late RoomModel _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  Future<void> _regenerateCode() async {
    await _roomService.regenerateCode(_room.id);
    final updated = await _roomService.findRoom(_room.id);
    if (updated != null && mounted) {
      setState(() => _room = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yangi kod generatsiya qilindi'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _room.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kod nusxalandi'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_room.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Kod kartasi (faqat domla)
                    if (widget.user.isDomla) _buildCodeCard(),

                    const SizedBox(height: 16),

                    // Stream tugmasi
                    _buildStreamButton(),

                    const SizedBox(height: 10),

                    // Whiteboard tugmasi
                    _buildWhiteboardButton(),

                    const SizedBox(height: 20),

                    // Chat sarlavhasi
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'CHAT',
                        style: TextStyle(
                          color: AppColors.textPrimary.withOpacity(0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Chat xabarlari
                    _buildChatMessages(),
                  ],
                ),
              ),
            ),

            // Chat input
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    final isValid = _room.isCodeValid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Guruh ID',
                style: TextStyle(
                  color: AppColors.textPrimary.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                isValid ? 'Faol' : 'Muddati tugagan',
                style: TextStyle(
                  color: isValid ? AppColors.green : AppColors.red,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _room.id.substring(0, 8).toUpperCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kirish kodi',
                      style: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _room.code,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy, color: AppColors.textHint, size: 20),
              ),
              IconButton(
                onPressed: _regenerateCode,
                icon: const Icon(Icons.refresh, color: AppColors.green, size: 20),
              ),
            ],
          ),
          Text(
            isValid
                ? 'Kod 4 soat amal qiladi'
                : 'Yangilash tugmasini bosing',
            style: TextStyle(
              color: AppColors.textPrimary.withOpacity(0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_outlined, color: AppColors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'Stream boshlash',
              style: TextStyle(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteboardButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_outlined,
                color: AppColors.textPrimary.withOpacity(0.6), size: 20),
            const SizedBox(width: 8),
            Text(
              'Whiteboard',
              style: TextStyle(
                color: AppColors.textPrimary.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages() {
    return Column(
      children: [
        _buildMessage('Akbar domla', 'Bugun dars 19:00 da', false),
        _buildMessage('Sardor', 'Keldim!', false),
        _buildMessage('Siz', 'Tayyor', true),
      ],
    );
  }

  Widget _buildMessage(String name, String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                color: isMe
                    ? AppColors.green
                    : AppColors.primary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryDark.withOpacity(0.2)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe
                      ? AppColors.primaryLight
                      : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Xabar yozing...',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline, color: AppColors.textPrimary),
              title: const Text('Talabalar ro\'yxati',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Guruhni o\'chirish',
                  style: TextStyle(color: AppColors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
