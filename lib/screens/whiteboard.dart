import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class WhiteboardSahifasi extends StatefulWidget {
  final String guruhId;
  const WhiteboardSahifasi({super.key, required this.guruhId});
  @override
  State<WhiteboardSahifasi> createState() => _WhiteboardSahifasiState();
}

class _WhiteboardSahifasiState extends State<WhiteboardSahifasi> {
  final List<List<Offset?>> _chiziqlar = [];
  List<Offset?> _joriyChiziq = [];
  Color _rang = Colors.black;
  double _qalinlik = 3.0;
  bool _saqlanmoqda = false;
  final GlobalKey _repaintKey = GlobalKey();

  final List<Color> _ranglar = [
    Colors.black, Colors.red, Colors.blue,
    Colors.green, Colors.orange, Colors.purple,
  ];

  void _chizishBoshlash(Offset point) {
    setState(() {
      _joriyChiziq = [point];
      _chiziqlar.add(_joriyChiziq);
    });
    _firestoreYuborish(point, 'boshlash');
  }

  void _chizishDavom(Offset point) {
    setState(() => _joriyChiziq.add(point));
    _firestoreYuborish(point, 'davom');
  }

  void _chizishTugat() {
    setState(() => _joriyChiziq.add(null));
    _firestoreYuborish(Offset.zero, 'tugash');
  }

  Future<void> _firestoreYuborish(Offset point, String tur) async {
    await FirebaseFirestore.instance
        .collection('guruhlar').doc(widget.guruhId)
        .collection('whiteboard')
        .add({
      'x': point.dx, 'y': point.dy,
      'tur': tur,
      'rang': _rang.value,
      'qalinlik': _qalinlik,
      'vaqt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saqlash() async {
    setState(() => _saqlanmoqda = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saqlandi: ${file.path}'),
              backgroundColor: Colors.green,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xato: $e')));
      }
    } finally {
      setState(() => _saqlanmoqda = false);
    }
  }

  void _tozalash() {
    setState(() => _chiziqlar.clear());
    FirebaseFirestore.instance
        .collection('guruhlar').doc(widget.guruhId)
        .collection('whiteboard')
        .get().then((snap) {
      for (final doc in snap.docs) doc.reference.delete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f172a),
        title: const Text('Whiteboard', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _tozalash,
            tooltip: 'Tozalash',
          ),
          IconButton(
            icon: _saqlanmoqda
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saqlanmoqda ? null : _saqlash,
            tooltip: 'Saqlash',
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)
            ],
          ),
          child: Row(children: [
            ..._ranglar.map((r) => GestureDetector(
              onTap: () => setState(() => _rang = r),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: r,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _rang == r ? Colors.grey.shade600 : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _rang = Colors.white),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: const Icon(Icons.auto_fix_normal,
                    size: 14, color: Colors.grey),
              ),
            ),
            Expanded(
              child: Slider(
                value: _qalinlik,
                min: 1, max: 10,
                activeColor: const Color(0xFF0f172a),
                onChanged: (v) => setState(() => _qalinlik = v),
              ),
            ),
          ]),
        ),
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: GestureDetector(
              onPanStart: (d) => _chizishBoshlash(d.localPosition),
              onPanUpdate: (d) => _chizishDavom(d.localPosition),
              onPanEnd: (_) => _chizishTugat(),
              child: CustomPaint(
                painter: _WhiteboardPainter(_chiziqlar),
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<List<Offset?>> chiziqlar;
  _WhiteboardPainter(this.chiziqlar);

  @override
  void paint(Canvas canvas, Size size) {
    for (final chiziq in chiziqlar) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..color = Colors.black;
      for (int i = 0; i < chiziq.length - 1; i++) {
        if (chiziq[i] != null && chiziq[i + 1] != null) {
          canvas.drawLine(chiziq[i]!, chiziq[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}
