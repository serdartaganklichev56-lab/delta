import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../guruh/whiteboard_screen.dart';

class StreamScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel user;
  const StreamScreen({super.key, required this.room, required this.user});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  static const String tokenServer = 'http://178.105.129.234:3000';

  Room? _room;
  LocalParticipant? _localParticipant;
  bool _menUstoz = false;
  bool _yuklanmoqda = true;
  bool _ulangan = false;
  bool _micOchiq = true;
  bool _videoOchiq = true;
  bool _ekranUlashish = false;
  bool _yozilmoqda = false;
  bool _oldKamera = true; // true=old, false=orqa
  VideoTrack? _remoteVideoTrack;
  final List<RemoteParticipant> _remoteParticipants = [];

  @override
  void initState() {
    super.initState();
    _boshlash();
  }

  @override
  void dispose() {
    _streamniTugat();
    super.dispose();
  }

  Future<void> _boshlash() async {
    setState(() {
      _menUstoz = widget.room.domlaId == widget.user.uid;
      _yuklanmoqda = false;
    });
    await _livekitGaUlan();
  }

  Future<void> _livekitGaUlan() async {
    try {
      final response = await http.post(
        Uri.parse('$tokenServer/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.room.id,
          'participantName': widget.user.fullName.isEmpty
              ? widget.user.uid
              : widget.user.fullName,
          'isPublisher': _menUstoz,
        }),
      );
      if (response.statusCode != 200) throw Exception('Token xatosi');
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final url = data['url'] as String;
      _room = Room();
      _room!.addListener(_roomListener);
      await _room!.connect(url, token,
          roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      _localParticipant = _room!.localParticipant;
      if (_menUstoz) {
        await _localParticipant!.setCameraEnabled(false);
        await _localParticipant!.setMicrophoneEnabled(false);
        setState(() => _videoOchiq = false);
        setState(() => _micOchiq = false);
        await FirebaseFirestore.instance
            .collection('guruhlar').doc(widget.room.id)
            .update({'streamFaol': true});
      } else {
        await _localParticipant!.setMicrophoneEnabled(false);
        setState(() => _micOchiq = false);
      }
      setState(() => _ulangan = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ulanishda xato: $e'),
              backgroundColor: AppColors.red));
    }
  }

  void _roomListener() {
    if (_room == null) return;
    setState(() {
      _remoteParticipants.clear();
      _remoteParticipants.addAll(_room!.remoteParticipants.values);
      _remoteVideoTrack = null;
      for (final p in _room!.remoteParticipants.values) {
        for (final pub in p.videoTrackPublications) {
          if (pub.track != null) {
            _remoteVideoTrack = pub.track as VideoTrack?;
            break;
          }
        }
        if (_remoteVideoTrack != null) break;
      }
    });
  }

  // Kamera almashtirish (old/orqa)
  Future<void> _kameraAlmashtirish() async {
    if (_localParticipant == null || _ekranUlashish) return;
    try {
      final cameraTracks = _localParticipant!.videoTrackPublications
          .where((p) => p.track != null)
          .toList();
      if (cameraTracks.isNotEmpty) {
        final track = cameraTracks.first.track as LocalVideoTrack;
        await track.setCameraPosition(
          _oldKamera ? CameraPosition.back : CameraPosition.front,
        );
        setState(() => _oldKamera = !_oldKamera);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera xatosi: $e'),
              backgroundColor: AppColors.red));
    }
  }

  // Ekran ulashish
  Future<void> _ekranUlashishToggle() async {
    if (_localParticipant == null) return;
    try {
      if (_ekranUlashish) {
        await _localParticipant!.setScreenShareEnabled(false);
        await _localParticipant!.setCameraEnabled(true);
        setState(() { _ekranUlashish = false; _videoOchiq = true; });
      } else {
        await _localParticipant!.setCameraEnabled(false);
        await _localParticipant!.setScreenShareEnabled(true);
        setState(() { _ekranUlashish = true; _videoOchiq = false; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekran ulashishda xato: $e'),
              backgroundColor: AppColors.red));
    }
  }

  Future<void> _ekranYozishToggle() async {
    setState(() => _yozilmoqda = !_yozilmoqda);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_yozilmoqda ? 'Yozish boshlandi!' : 'Yozish tugadi'),
        backgroundColor: _yozilmoqda ? Colors.red : Colors.green));
  }

  Future<void> _streamniTugat() async {
    if (_menUstoz) {
      if (_ekranUlashish) await _localParticipant?.setScreenShareEnabled(false);
      await FirebaseFirestore.instance
          .collection('guruhlar').doc(widget.room.id)
          .update({'streamFaol': false});
    }
    _room?.removeListener(_roomListener);
    await _room?.disconnect();
    _room = null;
  }

  Future<void> _chiqish() async {
    await _streamniTugat();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_yuklanmoqda) {
      return const Scaffold(
        backgroundColor: Color(0xFF0d0d1a),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      body: SafeArea(
        child: Stack(children: [
          _buildVideoArea(),
          _buildHeader(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildControls()),
          if (_yozilmoqda)
            Positioned(
              top: 60, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                  SizedBox(width: 4),
                  Text('REC', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          // Kamera almashtirish tugmasi
          if (_menUstoz && _videoOchiq && !_ekranUlashish)
            Positioned(
              top: 60, left: 16,
              child: GestureDetector(
                onTap: _kameraAlmashtirish,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(
                    _oldKamera ? Icons.camera_front : Icons.camera_rear,
                    color: Colors.white, size: 22),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_menUstoz) {
      final videoTrack = _localParticipant
          ?.videoTrackPublications
          .where((p) => p.track != null)
          .firstOrNull?.track as VideoTrack?;
      if (videoTrack != null) return SizedBox.expand(child: VideoTrackRenderer(videoTrack));
    } else {
      if (_remoteVideoTrack != null) return SizedBox.expand(child: VideoTrackRenderer(_remoteVideoTrack!));
    }
    return Container(
      color: const Color(0xFF0d0d1a),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_ekranUlashish ? Icons.screen_share : _menUstoz ? Icons.videocam_off : Icons.person_outline,
              size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            _ekranUlashish ? 'Ekran ulashilmoqda...' : _menUstoz ? "Kamera o'chiq" : 'Ustoz hali stream bermayapti',
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
          if (_menUstoz && _remoteParticipants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${_remoteParticipants.length} talaba ulangan',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xDD000000), Colors.transparent])),
        child: Row(children: [
          GestureDetector(onTap: _chiqish, child: const Icon(Icons.arrow_back, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.room.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(_menUstoz ? '${_remoteParticipants.length} talaba ulangan' : 'Jonli dars',
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
          if (_ulangan)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 4),
                Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Color(0xDD000000), Colors.transparent])),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        if (!_menUstoz) ...[
          _kontrolTugma(
            icon: _micOchiq ? Icons.mic : Icons.mic_off,
            rang: _micOchiq ? Colors.white24 : Colors.red,
            onTap: () async {
              await _localParticipant?.setMicrophoneEnabled(!_micOchiq);
              setState(() => _micOchiq = !_micOchiq);
            },
            label: 'Mic',
          ),
        ],
        if (_menUstoz) ...[
          _kontrolTugma(
            icon: _micOchiq ? Icons.mic : Icons.mic_off,
            rang: _micOchiq ? Colors.white24 : Colors.red,
            onTap: () async {
              await _localParticipant?.setMicrophoneEnabled(!_micOchiq);
              setState(() => _micOchiq = !_micOchiq);
            },
            label: 'Mic',
          ),
          _kontrolTugma(
            icon: _videoOchiq ? Icons.videocam : Icons.videocam_off,
            rang: _videoOchiq ? Colors.white24 : Colors.red,
            onTap: () async {
              if (!_ekranUlashish) {
                await _localParticipant?.setCameraEnabled(!_videoOchiq);
                setState(() => _videoOchiq = !_videoOchiq);
              }
            },
            label: 'Video',
          ),
          _kontrolTugma(
            icon: _ekranUlashish ? Icons.stop_screen_share : Icons.screen_share,
            rang: _ekranUlashish ? Colors.green : Colors.white24,
            onTap: _ekranUlashishToggle,
            label: _ekranUlashish ? "To'xtat" : 'Ekran',
          ),
          _kontrolTugma(
            icon: _yozilmoqda ? Icons.stop_circle : Icons.fiber_manual_record,
            rang: _yozilmoqda ? Colors.red : Colors.white24,
            onTap: _ekranYozishToggle,
            label: _yozilmoqda ? "To'xtat" : 'Yozish',
          ),
          _kontrolTugma(
            icon: Icons.draw_outlined,
            rang: Colors.blue.withValues(alpha: 0.5),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => WhiteboardScreen(room: widget.room, user: widget.user))),
            label: 'Tahta',
          ),
        ],
        _kontrolTugma(icon: Icons.call_end, rang: Colors.red, onTap: _chiqish, label: 'Chiqish'),
      ]),
    );
  }

  Widget _kontrolTugma({required IconData icon, required Color rang, required VoidCallback onTap, required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(color: rang, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
      ]),
    );
  }
}
