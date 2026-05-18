import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'whiteboard.dart';

class StreamScreen extends StatefulWidget {
  final String guruhId;
  final String guruhNom;
  const StreamScreen({super.key, required this.guruhId, required this.guruhNom});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  static const Color dark = Color(0xFF0f172a);
  static const String TOKEN_SERVER = 'http://178.105.129.234:3000';

  final uid = FirebaseAuth.instance.currentUser?.uid;

  Room? _room;
  LocalParticipant? _localParticipant;

  bool _menUstoz = false;
  bool _yuklanmoqda = true;
  bool _ulanmoqda = false;
  bool _ulangan = false;
  bool _micOchiq = true;
  bool _videoOchiq = true;

  // Talabalar uchun remote track
  final List<RemoteParticipant> _remoteParticipants = [];
  VideoTrack? _remoteVideoTrack;

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
    final snap = await FirebaseFirestore.instance
        .collection('guruhlar')
        .doc(widget.guruhId)
        .get();
    final ustozId = snap.data()?['ustozId'] as String?;
    setState(() {
      _menUstoz = ustozId == uid;
      _yuklanmoqda = false;
    });
    await _livekitGaUlan();
  }

  Future<void> _livekitGaUlan() async {
    setState(() => _ulanmoqda = true);
    try {
      // Foydalanuvchi ismini olish
      final userSnap = await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .doc(uid)
          .get();
      final d = userSnap.data() ?? {};
      final ism = '${d['ism'] ?? ''} ${d['familya'] ?? ''}'.trim();

      // Token olish
      final response = await http.post(
        Uri.parse('$TOKEN_SERVER/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomName': widget.guruhId,
          'participantName': ism.isEmpty ? uid : ism,
          'isPublisher': _menUstoz,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Token olishda xato: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final url = data['url'] as String;

      // LiveKit room yaratish
      _room = Room();
      _room!.addListener(_roomListener);

      // Ulash
      await _room!.connect(url, token,
          roomOptions: const RoomOptions(
            adaptiveStream: true,
            dynacast: true,
          ));

      _localParticipant = _room!.localParticipant;

      if (_menUstoz) {
        // Kamera va mikrofon yoqish
        await _localParticipant!.setCameraEnabled(true);
        await _localParticipant!.setMicrophoneEnabled(true);

        // Firestore da stream faol deb belgilash
        await FirebaseFirestore.instance
            .collection('guruhlar')
            .doc(widget.guruhId)
            .update({'streamFaol': true});
      }

      setState(() {
        _ulangan = true;
        _ulanmoqda = false;
      });
    } catch (e) {
      setState(() => _ulanmoqda = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ulanishda xato: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _roomListener() {
    if (_room == null) return;
    setState(() {
      _remoteParticipants.clear();
      _remoteParticipants.addAll(_room!.remoteParticipants.values);

      // Birinchi remote video trackni olish (talaba uchun ustoz video)
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

  Future<void> _micToggle() async {
    if (_localParticipant == null) return;
    final yangi = !_micOchiq;
    await _localParticipant!.setMicrophoneEnabled(yangi);
    setState(() => _micOchiq = yangi);
  }

  Future<void> _videoToggle() async {
    if (_localParticipant == null) return;
    final yangi = !_videoOchiq;
    await _localParticipant!.setCameraEnabled(yangi);
    setState(() => _videoOchiq = yangi);
  }

  Future<void> _streamniTugat() async {
    if (_menUstoz) {
      await FirebaseFirestore.instance
          .collection('guruhlar')
          .doc(widget.guruhId)
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
    if (_yuklanmoqda || _ulanmoqda) {
      return Scaffold(
        backgroundColor: const Color(0xFF0d0d1a),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _ulanmoqda ? 'LiveKit ga ulanmoqda...' : 'Yuklanmoqda...',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      body: SafeArea(
        child: Stack(
          children: [
            // Video area
            _buildVideoArea(),

            // Header
            _buildHeader(),

            // Boshqaruv tugmalari
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_menUstoz) {
      // Ustoz: o'z kamerasini ko'radi
      final videoTrack = _localParticipant
          ?.videoTrackPublications
          .where((p) => p.track != null)
          .firstOrNull
          ?.track as VideoTrack?;

      if (videoTrack != null) {
        return SizedBox.expand(
          child: VideoTrackRenderer(videoTrack),
        );
      }
    } else {
      // Talaba: ustoz videosini ko'radi
      if (_remoteVideoTrack != null) {
        return SizedBox.expand(
          child: VideoTrackRenderer(_remoteVideoTrack!),
        );
      }
    }

    // Video yo'q bo'lsa placeholder
    return Container(
      color: const Color(0xFF0d0d1a),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _menUstoz ? Icons.videocam_off : Icons.person_outline,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              _menUstoz
                  ? 'Kamera o\'chiq'
                  : _ulangan
                      ? 'Ustoz hali video bermayapti'
                      : 'Ulanilmoqda...',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            // Talabalar soni
            if (_menUstoz && _remoteParticipants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_remoteParticipants.length} talaba ulangan',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xDD000000), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _chiqish,
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.guruhNom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _menUstoz
                        ? '${_remoteParticipants.length} talaba ulangan'
                        : 'Jonli dars',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_ulangan)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_menUstoz) ...[
            _kontrolTugma(
              icon: _micOchiq ? Icons.mic : Icons.mic_off,
              rang: _micOchiq ? Colors.white24 : Colors.red,
              onTap: _micToggle,
              label: 'Mic',
            ),
            _kontrolTugma(
              icon: _videoOchiq ? Icons.videocam : Icons.videocam_off,
              rang: _videoOchiq ? Colors.white24 : Colors.red,
              onTap: _videoToggle,
              label: 'Video',
            ),
            _kontrolTugma(
              icon: Icons.draw_outlined,
              rang: Colors.blue.withAlpha(120),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          WhiteboardSahifasi(guruhId: widget.guruhId))),
              label: 'Whiteboard',
            ),
          ],
          _kontrolTugma(
            icon: Icons.call_end,
            rang: Colors.red,
            onTap: _chiqish,
            label: 'Chiqish',
          ),
        ],
      ),
    );
  }

  Widget _kontrolTugma({
    required IconData icon,
    required Color rang,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: rang, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}
