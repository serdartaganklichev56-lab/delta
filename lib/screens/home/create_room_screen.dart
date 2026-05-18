import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/room_service.dart';

class CreateRoomScreen extends StatefulWidget {
  final UserModel user;
  const CreateRoomScreen({super.key, required this.user});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameCtrl = TextEditingController();
  final _roomService = RoomService();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guruh nomini kiriting'),
              backgroundColor: AppColors.red));
      return;
    }
    setState(() => _loading = true);
    try {
      await _roomService.createRoom(
        name: _nameCtrl.text.trim(),
        domlaId: widget.user.uid,
        domlaName: widget.user.fullName,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yangi guruh'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Guruh nomi (masalan: Matematika 11-sinf)',
                prefixIcon: Icon(Icons.group_outlined, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.primaryLight, strokeWidth: 2))
                  : const Text('Guruh yaratish'),
            ),
          ]),
        ),
      ),
    );
  }
}
